"""Akış (stream) halinde çalışan SignalSpec v0 referans alıcısı.

Hat (sözleşme §6.1, BLUEPRINT §3.4.1):

    giriş (ham, gerçek) ──► [bant geçiren FIR ⊛ analitik yükselen chirp] eşlenik filtre
        (overlap-save FFT korelasyonu, tek çekirdek)  ──► P[n] = |y[n]|²
    ──► CFAR (küçük-olan + ortalama karışımı, yerel)  ──► Pn[n] = P[n] / F[n]
    ──► 3 tepe birleştirme: C[n] = Pn[n] + maxpool(Pn)[n+9600] + maxpool(Pn)[n+19200]
    ──► eşik (C ≥ eta_c ve her tepe ≥ eta_min) + yerel maksimum bastırma (±R)
    ──► çözme: bant geçiren + analitik sinyal (FFT), alçalan senk ile ince zamanlama,
        her sembolde dechirp + FFT, kaydırma = argmax(|Z(sB/M)|² + |Z(sB/M − B)|²),
        Gray, CRC.

Bütün durum `StreamingReceiver` nesnesindedir. Her tampon "mutlak örnek
indeksi" ile tutulur (`_AbsBuf`). Swift tarafı aynı yapıyı sabit boyutlu halka
tamponlarla kurabilir: hiçbir aşama, `max_history_samples()` değerinden daha
eski örneğe ihtiyaç duymaz.

Python sürümü numpy dizilerini birleştirir ve kırpar; bu yalnız referans
içindir (gerçek zamanlı iş parçacığı kuralları Swift tarafında uygulanır).
"""

from __future__ import annotations

from dataclasses import dataclass, field, replace

import numpy as np
from scipy import signal as sps
from scipy.ndimage import maximum_filter1d

from .constants import SignalParams, V0
from .payload import RESERVED_IDS, Fields, crc_ok, nibbles_to_word, shifts_to_nibbles, unpack
from .waveform import (
    analytic_base_symbol,
    analytic_down_template,
    analytic_symbol_templates,
    analytic_up_template,
)


@dataclass(frozen=True)
class ReceiverConfig:
    params: SignalParams = V0
    bp_taps: int = 511
    bp_kaiser_beta: float = 8.0
    nfft: int = 16_384  # overlap-save blok boyu
    cfar_guard: int = 64
    cfar_window: int = 2_048
    cfar_ca_weight: float = 0.25  # F = max(SO, w * CA, eps)
    floor_eps: float = 1e-12  # mutlak taban (tam sessizlik için)
    pool_radius: int = 3  # tepe aralığı toleransı (±100 ppm => ≤ 2 örnek)
    n_up: int = 3  # birleştirilen giriş chirp sayısı (deney için 1 olabilir)
    eta_c: float = 22.3  # C eşiği; beyaz gürültüde ≈10 ön tespit/saat (research/sim/calibrate_threshold.py)
    eta_min: float = 2.0  # her tepe için alt sınır
    nms_radius: int = 12_000
    # Kabul edilmiş bir adaydan sonraki bir çerçeve süresi içinde, ondan
    # self_suppress katından zayıf aday reddedilir (kendi veri bölümünün
    # şablonla çapraz korelasyonu sahte aday üretir).
    self_suppress: float = 0.1
    down_search: int = 32  # alçalan senk arama yarıçapı (örnek)
    decode_pad: int = 512
    css_mode: str = "energy"  # "energy" (sözleşme §6.1) veya "coherent" (karşılaştırma)


@dataclass
class FrameEvent:
    start: float  # çerçeve başlangıcı, girişin mutlak örnek indeksi
    kind: str  # "beacon" | "response" | "crc_fail" | "reserved_id"
    word: int
    crc_ok: bool
    fields: Fields | None
    shifts: list[int]
    nibbles: list[int]
    metric_c: float
    peaks: list[float]  # normalize tepe güçleri (Pn)
    snr_out_db: float  # eşlenik filtre çıkış SNR kestirimi (tepe başına ortalama)
    sym_margin_db: float  # en kötü sembolde 1. / 2. aday enerji oranı
    updown_offset: float  # alçalan - yükselen zamanlama farkı (örnek)
    used_down: bool

    @property
    def valid(self) -> bool:
        """Sözleşme §6: yalnız CRC doğru ve id ayrılmış değilse raporlanır."""
        return self.kind in ("beacon", "response")


class _AbsBuf:
    """Mutlak indeksli büyüyen/kırpılan tampon."""

    def __init__(self, dtype) -> None:
        self.data = np.zeros(0, dtype=dtype)
        self.start = 0

    @property
    def end(self) -> int:
        return self.start + self.data.size

    def append(self, arr: np.ndarray) -> None:
        self.data = np.concatenate([self.data, arr.astype(self.data.dtype, copy=False)])

    def get(self, a: int, b: int) -> np.ndarray:
        if a < self.start or b > self.end:
            raise IndexError(f"[{a},{b}) tampon dışında [{self.start},{self.end})")
        return self.data[a - self.start : b - self.start]

    def trim_before(self, keep_from: int) -> None:
        k = keep_from - self.start
        if k > 0:
            self.data = self.data[k:].copy()
            self.start = keep_from


def design_bandpass(cfg: ReceiverConfig) -> np.ndarray:
    p = cfg.params
    return sps.firwin(cfg.bp_taps, list(p.rx_band), pass_zero=False, fs=p.fs,
                      window=("kaiser", cfg.bp_kaiser_beta))


def sym_fft_size(p: SignalParams) -> int:
    """B/M ve B tam sayı bin olacak şekilde en küçük N ≥ n_sym."""
    step = p.bandwidth / p.alphabet
    n = p.n_sym
    while True:
        a = step * n / p.fs
        if abs(a - round(a)) < 1e-9:
            return n
        n += 1


class StreamingReceiver:
    def __init__(self, cfg: ReceiverConfig | None = None) -> None:
        self.cfg = cfg or ReceiverConfig()
        p = self.cfg.params
        self.p = p
        self.h_bp = design_bandpass(self.cfg)
        self.hl = (self.cfg.bp_taps - 1) // 2
        # Eşlenik filtre çekirdeği: bant geçiren ⊛ analitik yükselen chirp.
        self.up_t = analytic_up_template(p)
        self.down_t = analytic_down_template(p)
        g = np.convolve(self.up_t, self.h_bp)
        self.lk = g.size
        self.kernel_offset = self.hl  # tepe indeksi + hl = çerçeve başlangıcı
        h = np.conj(g[::-1])
        self.H = np.fft.fft(h, self.cfg.nfft)
        self.hop = self.cfg.nfft - self.lk + 1
        if self.hop <= 0:
            raise ValueError("nfft çok küçük")
        self.noise_ref = float(np.sum(np.abs(g) ** 2))  # birim varyanslı gürültüde E[P]
        # Sembol çözme sabitleri
        self.base_conj = np.conj(analytic_base_symbol(p))
        self.nfft_sym = sym_fft_size(p)
        bin_hz = p.fs / self.nfft_sym
        self.bin_step = int(round(p.bandwidth / p.alphabet / bin_hz))
        self.b_bins = int(round(p.bandwidth / bin_hz))
        s = np.arange(p.alphabet)
        self.k1 = s * self.bin_step
        self.k2 = (s * self.bin_step - self.b_bins) % self.nfft_sym
        self.sym_templates_conj = np.conj(analytic_symbol_templates(p))
        self.reset()

    # ------------------------------------------------------------------ durum
    def reset(self) -> None:
        c = self.cfg
        self.x = _AbsBuf(np.float64)  # ham giriş
        self.P = _AbsBuf(np.float64)  # |y|²
        self.Pn = _AbsBuf(np.float64)  # normalize
        self.mp = _AbsBuf(np.float64)  # maxpool(Pn)
        self.C = _AbsBuf(np.float64)
        self.minpk = _AbsBuf(np.float64)
        self.y_next = 0
        self.f_next = c.cfar_guard + c.cfar_window
        self.Pn.start = self.f_next
        self.mp_next = self.f_next + c.pool_radius
        self.mp.start = self.mp_next
        self.c_next = self.mp_next
        self.C.start = self.c_next
        self.minpk.start = self.c_next
        self.nms_next = self.c_next
        self.last_accept = -(10**12)
        self.recent: list[tuple[int, float]] = []
        self.pending: list[dict] = []
        self.n_candidates = 0

    def max_history_samples(self) -> int:
        """Ham giriş için gereken en büyük tampon (Swift halka tamponu boyu)."""
        c, p = self.cfg, self.p
        lag = c.nms_radius + (c.n_up - 1) * p.up_spacing + c.pool_radius + c.cfar_guard + c.cfar_window + 1
        return lag + p.frame_len + c.decode_pad + self.hl + self.lk + c.nfft

    # ------------------------------------------------------------------ giriş
    def process(self, block: np.ndarray) -> list[FrameEvent]:
        """Rastgele uzunlukta ses bloğu besle; tamamlanan çerçeve olaylarını döndür."""
        block = np.asarray(block, dtype=np.float64).ravel()
        if block.size:
            self.x.append(block)
        self._correlate()
        self._cfar()
        self._pool()
        self._combine()
        self._detect()
        events = self._decode_ready()
        self._trim()
        return events

    def flush(self) -> list[FrameEvent]:
        """Akış sonu: bekleyen her şeyi tamamlamak için sıfır besler."""
        need = self.max_history_samples()
        return self.process(np.zeros(need))

    # ------------------------------------------------------------ aşamalar
    def _correlate(self) -> None:
        nfft, hop = self.cfg.nfft, self.hop
        while self.x.end >= self.y_next + nfft:
            blk = self.x.get(self.y_next, self.y_next + nfft)
            y = np.fft.ifft(np.fft.fft(blk) * self.H)[self.lk - 1 :]
            self.P.append(y.real**2 + y.imag**2)
            self.y_next += hop

    def _cfar(self) -> None:
        c = self.cfg
        g, w = c.cfar_guard, c.cfar_window
        a = self.f_next
        b = self.P.end - g - w  # n + g + w < P.end
        if b <= a:
            return
        s0 = a - g - w
        seg = self.P.get(s0, b + g + w)
        cs = np.concatenate([[0.0], np.cumsum(seg)])
        n = np.arange(a, b) - s0
        lead = (cs[n - g] - cs[n - g - w]) / w
        lag = (cs[n + g + 1 + w] - cs[n + g + 1]) / w
        so = np.minimum(lead, lag)
        ca = 0.5 * (lead + lag)
        floor = np.maximum(np.maximum(so, c.cfar_ca_weight * ca), c.floor_eps * self.noise_ref)
        self.Pn.append(self.P.get(a, b) / floor)
        self.f_next = b

    def _pool(self) -> None:
        r = self.cfg.pool_radius
        a = self.mp_next
        b = self.Pn.end - r
        if b <= a:
            return
        seg = self.Pn.get(a - r, b + r)
        m = maximum_filter1d(seg, size=2 * r + 1, mode="nearest")[r:-r]
        self.mp.append(m)
        self.mp_next = b

    def _combine(self) -> None:
        sp = self.p.up_spacing
        k = self.cfg.n_up
        a = self.c_next
        b = min(self.mp.end - (k - 1) * sp, self.Pn.end)
        if b <= a:
            return
        terms = [self.Pn.get(a, b)] + [self.mp.get(a + j * sp, b + j * sp) for j in range(1, k)]
        st = np.stack(terms)
        self.C.append(st.sum(axis=0))
        self.minpk.append(st.min(axis=0))
        self.c_next = b

    def _detect(self) -> None:
        c = self.cfg
        R = c.nms_radius
        a = self.nms_next
        b = self.C.end - R
        if b <= a:
            return
        lo = max(a - R, self.C.start)
        seg = self.C.get(lo, b + R)
        mx = maximum_filter1d(seg, size=2 * R + 1, mode="nearest")
        off = a - lo
        cs = seg[off : off + (b - a)]
        mxs = mx[off : off + (b - a)]
        mp = self.minpk.get(a, b)
        hits = np.nonzero((cs >= c.eta_c) & (mp >= c.eta_min) & (cs >= mxs))[0]
        for h in hits:
            n = a + int(h)
            if n - self.last_accept <= R:
                continue
            cn = float(cs[h])
            if any(n - m < self.p.frame_len and cn < c.self_suppress * cm for m, cm in self.recent):
                continue
            self.last_accept = n
            self.recent = [(m, cm) for m, cm in self.recent if n - m < self.p.frame_len] + [(n, cn)]
            self._add_candidate(n)
        self.nms_next = b

    # ------------------------------------------------------------ çözme
    def _refine_peak(self, center: int) -> tuple[float, float]:
        """±pool_radius içinde P tepesi, P üzerinde parabolik alt-örnek.

        Döndürülen değer: tepe konumu ve o konumdaki normalize güç (Pn).
        """
        r = self.cfg.pool_radius
        i = int(np.argmax(self.P.get(center - r, center + r + 1)))
        n = center - r + i
        pn_val = float(self.Pn.get(n, n + 1)[0])
        y0, y1, y2 = self.P.get(n - 1, n + 2)
        den = y0 - 2 * y1 + y2
        frac = 0.5 * (y0 - y2) / den if den < 0 else 0.0
        return n + float(np.clip(frac, -0.5, 0.5)), pn_val

    def _add_candidate(self, n: int) -> None:
        sp = self.p.up_spacing
        pos, vals = [], []
        for j in range(self.cfg.n_up):
            q, v = self._refine_peak(n + j * sp)
            pos.append(q - j * sp)
            vals.append(v)
        start_up = float(np.mean(pos)) + self.kernel_offset
        self.pending.append({"n": n, "start_up": start_up, "peaks": vals, "C": float(self.C.get(n, n + 1)[0])})
        self.n_candidates += 1

    def _decode_ready(self) -> list[FrameEvent]:
        out = []
        keep = []
        for cand in self.pending:
            a = int(np.floor(cand["start_up"])) - self.cfg.decode_pad
            b = int(np.ceil(cand["start_up"])) + self.p.frame_len + self.cfg.decode_pad
            if self.x.end >= b + self.hl:
                out.append(self._decode(cand, a, b))
            else:
                keep.append(cand)
        self.pending = keep
        return out

    def _analytic(self, a: int, b: int) -> np.ndarray:
        seg = self.x.get(a - self.hl, b + self.hl)
        xbp = sps.fftconvolve(seg, self.h_bp, mode="valid")
        return sps.hilbert(xbp)

    def _decode(self, cand: dict, a: int, b: int) -> FrameEvent:
        p, c = self.p, self.cfg
        an = self._analytic(a, b)
        start_up = cand["start_up"]
        # İnce zamanlama: alçalan senk chirp'i.
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
        offset = start_dn - start_up
        used_down = abs(offset) <= S / 2 and 0 < i < corr.size - 1
        start = 0.5 * (start_up + start_dn) if used_down else start_up
        # Semboller
        shifts, margins = [], []
        for k in range(p.n_symbols):
            s0 = int(round(start + p.symbol_start(k))) - a
            z = an[s0 : s0 + p.n_sym]
            if c.css_mode == "coherent":
                e = np.abs(self.sym_templates_conj @ z) ** 2
            else:
                Z = np.fft.fft(z * self.base_conj, self.nfft_sym)
                pw = Z.real**2 + Z.imag**2
                e = pw[self.k1] + pw[self.k2]
            o = np.argsort(e)
            shifts.append(int(o[-1]))
            margins.append(10 * np.log10(e[o[-1]] / max(e[o[-2]], 1e-300)))
        nibbles = shifts_to_nibbles(shifts)
        w = nibbles_to_word(nibbles)
        ok = crc_ok(w)
        f = unpack(w)
        if not ok:
            kind = "crc_fail"
        elif f.id in RESERVED_IDS:
            kind = "reserved_id"
        elif f.mode == 3:
            kind = "response"
        else:
            kind = "beacon"
        pk = np.asarray(cand["peaks"])
        snr = float(np.mean(np.maximum(pk - 1.0, 1e-6)))
        return FrameEvent(
            start=float(start),
            kind=kind,
            word=w,
            crc_ok=ok,
            fields=f if kind in ("beacon", "response") else None,
            shifts=shifts,
            nibbles=nibbles,
            metric_c=cand["C"],
            peaks=[float(v) for v in pk],
            snr_out_db=10 * np.log10(snr),
            sym_margin_db=float(min(margins)),
            updown_offset=float(offset),
            used_down=bool(used_down),
        )

    # ------------------------------------------------------------ kırpma
    def _trim(self) -> None:
        c = self.cfg
        oldest_cand = min([int(np.floor(cd["start_up"])) for cd in self.pending], default=None)
        x_keep = min(self.y_next, self.nms_next - c.decode_pad - self.hl - 2 * c.pool_radius - 4)
        if oldest_cand is not None:
            x_keep = min(x_keep, oldest_cand - c.decode_pad - self.hl)
        self.x.trim_before(x_keep)
        self.P.trim_before(min(self.f_next - c.cfar_guard - c.cfar_window, self.nms_next - c.pool_radius - 2))
        self.Pn.trim_before(min(self.mp_next - c.pool_radius, self.c_next, self.nms_next - c.pool_radius))
        self.mp.trim_before(self.c_next)
        self.C.trim_before(self.nms_next - c.nms_radius)
        self.minpk.trim_before(self.nms_next)


def decode_buffer(x: np.ndarray, cfg: ReceiverConfig | None = None, block: int | None = None) -> list[FrameEvent]:
    """Kolaylık: tüm kaydı (isteğe bağlı bloklar halinde) çözer."""
    rx = StreamingReceiver(cfg)
    ev: list[FrameEvent] = []
    if block is None:
        ev += rx.process(x)
    else:
        for i in range(0, len(x), block):
            ev += rx.process(x[i : i + block])
    ev += rx.flush()
    return ev


def with_params(cfg: ReceiverConfig, **kw) -> ReceiverConfig:
    return replace(cfg, **kw)
