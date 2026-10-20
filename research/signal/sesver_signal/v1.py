"""SignalSpec v1 adayları (ADR-0004) — F0-3b araştırma kodu. v0 modüllerine dokunmaz.

Adaylar (hepsi B1 bandı, 1,2–3,0 kHz; alıcı bandı 0,9–3,3 kHz):
    v1-E1   : 10 sembol × 64 ms, P1 yükü (24 bit) + RS(10,6) GF(16) eşliği, CRC yok
    v1-E3   : 8 sembol × 96 ms, P1 yükü + CRC-8/AUTOSAR (v0 ile aynı CRC)
    v1-E1E3 : 10 sembol × 96 ms, RS(10,6)
    v1-E1s  : v1-E1, giriş/senk chirp'leri 100 ms (ADR-0004 görev döngüsü telafisi)

P1 yük düzeni (24 bit, MSB önce):
    id 23…12 (12) · people 11…9 (3: 0 belirtilmedi, 1–6, 7 = 7+) · injured 8 (1)
    lifeAge 7…4 (4, v0 §4.1) · battery 3…2 (2: min(3, floor(%/25))) · mode 1…0 (2)

Alıcı: `V1Receiver`, v0 `StreamingReceiver` tespit hattını aynen kullanır, yalnız
`_decode` adımını değiştirir: her sembol için 16 kaydırmanın tutarlı (E0) ve
enerji (v0 §6.1) metriklerini döndürür. Karar ve kod çözme metriklerden sonra
(`hard_shifts`, `decode_*`) yapılır; böylece aynı tespit üzerinde E0/E4/RS
çeşitleri karşılaştırılabilir.
"""

from __future__ import annotations

from dataclasses import dataclass, replace

import numpy as np
from scipy import signal as sps

from . import rs16
from .constants import V0, V0L, SignalParams
from .payload import RESERVED_IDS, crc8_autosar, gray, gray_inv, nibbles_to_word, unpack
from .receiver import ReceiverConfig, StreamingReceiver, sym_fft_size
from .waveform import analytic_base_symbol, analytic_symbol_templates, frame_from_shifts

V1_E1 = replace(V0L, name="v1-E1", n_symbols=10)
V1_E3 = replace(V0L, name="v1-E3", n_sym=4_608)
V1_E1E3 = replace(V0L, name="v1-E1E3", n_sym=4_608, n_symbols=10)
V1_E1S = replace(V0L, name="v1-E1s", n_pre=4_800, n_symbols=10)

V1_VARIANTS = {p.name: p for p in (V1_E1, V1_E3, V1_E1E3, V1_E1S)}
CODING = {"v0": "crc_v0", "v0-L": "crc_v0", "v1-E1": "rs", "v1-E3": "crc_p1", "v1-E1E3": "rs", "v1-E1s": "rs"}


# ------------------------------------------------------------------ P1 yükü
@dataclass(frozen=True)
class FieldsP1:
    id: int
    people: int = 0
    injured: int = 0
    life_age: int = 15
    battery: int = 0
    mode: int = 0

    def validate(self) -> None:
        if not 0 <= self.id <= 0xFFF or self.id in RESERVED_IDS:
            raise ValueError("id 12 bit, 0x000/0xFFF ayrılmış")
        for name, bits in (("people", 3), ("injured", 1), ("life_age", 4), ("battery", 2), ("mode", 2)):
            if not 0 <= getattr(self, name) < (1 << bits):
                raise ValueError(f"{name} {bits} bite sığmalı")


def battery_code_p1(percent: float) -> int:
    return min(3, int(percent // 25))


def pack_p1(f: FieldsP1) -> int:
    f.validate()
    return (f.id << 12) | (f.people << 9) | (f.injured << 8) | (f.life_age << 4) | (f.battery << 2) | f.mode


def unpack_p1(d: int) -> FieldsP1:
    return FieldsP1(id=(d >> 12) & 0xFFF, people=(d >> 9) & 7, injured=(d >> 8) & 1,
                    life_age=(d >> 4) & 0xF, battery=(d >> 2) & 3, mode=d & 3)


def data_nibbles(d: int) -> list[int]:
    return [(d >> (20 - 4 * i)) & 0xF for i in range(6)]


def nibbles_data(n: list[int]) -> int:
    v = 0
    for x in n[:6]:
        v = (v << 4) | x
    return v


def codeword(data24: int, coding: str) -> list[int]:
    """24 bit veri -> nibble dizisi (gönderim sırası)."""
    if coding == "rs":
        return rs16.encode(data_nibbles(data24))
    crc = crc8_autosar(data24.to_bytes(3, "big"))
    w = (data24 << 8) | crc
    return [(w >> (28 - 4 * i)) & 0xF for i in range(8)]


def frame_v1(data24: int, p: SignalParams) -> np.ndarray:
    nib = codeword(data24, CODING[p.name])
    return frame_from_shifts([gray_inv(n) for n in nib], p)


# ------------------------------------------------------------------ alıcı
@dataclass
class SoftEvent:
    start: float
    metric_c: float
    used_down: bool
    e_coh: dict  # katman adı -> (n_symbols × 16) tutarlı metrik |<şablon_s, z>|²
    e_en: dict  # katman adı -> (n_symbols × 16) enerji metriği (v0 §6.1)


class V1Receiver(StreamingReceiver):
    """v0 tespit hattı + yumuşak metrik çıkaran çözme.

    `layouts`: aynı giriş/senk bölümünü paylaşan veri düzenleri. cfg.params en
    uzun çerçeveli düzen olmalı (tampon ve çözme penceresi ona göre).
    """

    def __init__(self, cfg: ReceiverConfig, layouts: list[SignalParams] | None = None) -> None:
        super().__init__(cfg)
        layouts = layouts or [cfg.params]
        p0 = cfg.params
        self.lay = []
        for p in layouts:
            if (p.f_low, p.f_high, p.n_pre, p.n_gap) != (p0.f_low, p0.f_high, p0.n_pre, p0.n_gap):
                raise ValueError("düzenler aynı giriş bölümünü paylaşmalı")
            if p.frame_len > p0.frame_len:
                raise ValueError("cfg.params en uzun düzen olmalı")
            nf = sym_fft_size(p)
            bin_hz = p.fs / nf
            step = int(round(p.bandwidth / p.alphabet / bin_hz))
            bb = int(round(p.bandwidth / bin_hz))
            s = np.arange(p.alphabet)
            self.lay.append((p, np.conj(analytic_symbol_templates(p)), np.conj(analytic_base_symbol(p)),
                             nf, s * step, (s * step - bb) % nf))

    def _decode(self, cand: dict, a: int, b: int) -> SoftEvent:  # type: ignore[override]
        p, c = self.p, self.cfg
        an = self._analytic(a, b)
        start_up = cand["start_up"]
        S = c.down_search
        d0 = int(round(start_up)) + p.down_start - a
        seg = an[d0 - S : d0 + S + p.n_pre]
        corr = np.abs(sps.fftconvolve(seg, np.conj(self.down_t[::-1]), mode="valid")) ** 2
        i = int(np.argmax(corr))
        frac = 0.0
        if 0 < i < corr.size - 1:
            den = corr[i - 1] - 2 * corr[i] + corr[i + 1]
            if den < 0:
                frac = float(np.clip(0.5 * (corr[i - 1] - corr[i + 1]) / den, -0.5, 0.5))
        start_dn = a + d0 - S + i + frac - p.down_start
        used_down = abs(start_dn - start_up) <= S / 2 and 0 < i < corr.size - 1
        start = 0.5 * (start_up + start_dn) if used_down else start_up
        e_coh, e_en = {}, {}
        for lp, tconj, bconj, nf, k1, k2 in self.lay:
            Z = np.stack([an[int(round(start + lp.symbol_start(k))) - a:][: lp.n_sym] for k in range(lp.n_symbols)])
            e_coh[lp.name] = np.abs(Z @ tconj.T) ** 2
            F = np.fft.fft(Z * bconj, nf, axis=1)
            pw = F.real**2 + F.imag**2
            e_en[lp.name] = pw[:, k1] + pw[:, k2]
        return SoftEvent(float(start), cand["C"], bool(used_down), e_coh, e_en)


# ------------------------------------------------------------------ karar ve kod çözme
@dataclass(frozen=True)
class Decoded:
    ok: bool  # kabul edildi (CRC/RS geçti ve id ayrılmış değil)
    data: int  # v0: 32 bit W; v1: 24 bit veri
    fields: object | None
    n_corr: int = 0


def hard_nibbles(E: np.ndarray) -> list[int]:
    return [gray(int(s)) for s in np.argmax(E, axis=1)]


def decode_metrics(E: np.ndarray, coding: str, t_max: int = 2, soft_rank: int | None = None) -> Decoded:
    """Metrik matrisinden (n_symbols × 16) çerçeve kararı.

    coding: "crc_v0" (v0 yükü + CRC-8), "crc_p1" (P1 + CRC-8), "rs" (P1 + RS(10,6)).
    soft_rank: RS düzeltmesinde her düzeltilen sembolün yeni değeri, o sembolün
    metrik sıralamasında ilk `soft_rank` aday içinde olmalı (yumuşak doğrulama).
    """
    nib = hard_nibbles(E)
    if coding == "rs":
        ok, cw, pat = rs16.decode(nib, t_max)
        if ok and soft_rank is not None and pat:
            order = np.argsort(-E, axis=1)
            for i, v in pat:
                s_new = gray_inv(cw[i])
                if s_new not in order[i, :soft_rank]:
                    ok = False
                    break
        d = nibbles_data(cw)
        f = unpack_p1(d)
        ok = ok and f.id not in RESERVED_IDS
        return Decoded(ok, d, f if ok else None, len(pat))
    w = nibbles_to_word(nib)
    d = w >> 8
    ok = crc8_autosar(d.to_bytes(3, "big")) == (w & 0xFF)
    f = unpack(w) if coding == "crc_v0" else unpack_p1(d)
    ok = ok and f.id not in RESERVED_IDS
    return Decoded(ok, w if coding == "crc_v0" else d, f if ok else None)


__all__ = [
    "V1_E1", "V1_E3", "V1_E1E3", "V1_E1S", "V1_VARIANTS", "CODING", "FieldsP1", "battery_code_p1", "pack_p1",
    "unpack_p1", "codeword", "frame_v1", "SoftEvent", "V1Receiver", "Decoded", "hard_nibbles", "decode_metrics",
    "V0",
]
