"""F0-3 simülasyonu ortak parçalar: kanal modelleri, gürültü üreticileri, SNR tanımı.

SNR tanımı (rapor §2):
    SNR_ib = P_s,ib / P_n,ib
    P_s,ib : alıcıya ulaşan (kanal sonrası, gürültü öncesi) işaretin alıcı bandındaki
             enerjisi / Ton (47 616 örnek). Çok yollu kanalda yankı enerjisi dahildir.
    P_n,ib : gürültünün aynı banttaki gücü. Beyaz gürültüde σ² · W / (fs/2).
    Alıcı bandı: v0 1,5-4,5 kHz (W = 3 kHz), v0-L 0,9-3,3 kHz (W = 2,4 kHz).
Türevler:
    SNR_wb  = SNR_ib + 10 log10(W / 24 000)       (0-24 kHz geniş bant)
    E/N0    = SNR_ib + 10 log10(W · Ton)          (bant tanımından bağımsız; varyantlar arası adil eksen)
Moloz kanalında ızgara "kaynak" SNR'ı (SNR_src, moloz öncesi) üzerinde kurulur;
alıcıdaki SNR_ib = SNR_src − L_ib (L_ib: moloz filtresinin bant içi enerji kaybı).
"""

from __future__ import annotations

import os
import sys
from dataclasses import dataclass, field
from pathlib import Path

os.environ.setdefault("OMP_NUM_THREADS", "1")
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
os.environ.setdefault("VECLIB_MAXIMUM_THREADS", "1")

import numpy as np  # noqa: E402
from scipy import signal as sps  # noqa: E402

SIM_DIR = Path(__file__).resolve().parent
RESEARCH = SIM_DIR.parent
sys.path.insert(0, str(RESEARCH / "signal"))

from sesver_signal import VARIANTS, Fields, ReceiverConfig, frame_from_word, pack  # noqa: E402
from sesver_signal.constants import SignalParams  # noqa: E402

RESULTS = SIM_DIR / "results"
FIGS = SIM_DIR / "reports" / "figs"
FS = 48_000


# ------------------------------------------------------------------ kanallar
@dataclass(frozen=True)
class Channel:
    name: str
    label: str
    rt60: float | None = None  # s
    drr_db: float | None = None  # doğrudan / yankı enerji oranı
    rubble_l1k_db: float | None = None  # 1 kHz'de toplam moloz kaybı (dB)
    rubble_beta: float | None = None  # L(f) = L1k (f / 1 kHz)^beta

    @property
    def is_rubble(self) -> bool:
        return self.rubble_l1k_db is not None


CHANNELS = {
    "awgn": Channel("awgn", "AWGN"),
    "mp03": Channel("mp03", "Çok yollu RT60 0,3 s, DRR 0 dB", rt60=0.3, drr_db=0.0),
    "mp08": Channel("mp08", "Çok yollu RT60 0,8 s, DRR 0 dB", rt60=0.8, drr_db=0.0),
    "mp08h": Channel("mp08h", "Çok yollu RT60 0,8 s, DRR −6 dB", rt60=0.8, drr_db=-6.0),
    "rub1": Channel("rub1", "Moloz R1 (4 dB@1k, f^1) + RT60 0,3", rt60=0.3, drr_db=0.0, rubble_l1k_db=4.0, rubble_beta=1.0),
    "rub2": Channel("rub2", "Moloz R2 (8 dB@1k, f^1) + RT60 0,3", rt60=0.3, drr_db=0.0, rubble_l1k_db=8.0, rubble_beta=1.0),
    "rub3": Channel("rub3", "Moloz R3 (6 dB@1k, f^1,5) + RT60 0,3", rt60=0.3, drr_db=0.0, rubble_l1k_db=6.0, rubble_beta=1.5),
}


def stochastic_rir(rt60: float, drr_db: float, rng: np.random.Generator, fs: int = FS,
                   onset_s: float = 0.001) -> np.ndarray:
    """Üstel sönümlü stokastik RIR: h[0] = 1 (doğrudan yol) + Gauss kuyruk.

    Kuyruk 60 dB'lik sönüm süresi rt60, başlangıcı onset_s; kuyruk enerjisi
    10^(−DRR/10) olacak şekilde ölçeklenir. Uzunluk rt60 (−60 dB).
    """
    n = int(rt60 * fs)
    h = np.zeros(n)
    h[0] = 1.0
    k = np.arange(int(onset_s * fs), n)
    tail = rng.standard_normal(k.size) * np.exp(-6.907755 * k / (rt60 * fs))
    tail *= np.sqrt(10 ** (-drr_db / 10) / np.sum(tail**2))
    h[k] = tail
    return h


def rubble_gain(freqs: np.ndarray, l1k_db: float, beta: float) -> np.ndarray:
    """Frekansa bağlı moloz kaybı (genlik). L(f) = L1k · (f/1 kHz)^β dB. [Tahmin]"""
    L = l1k_db * (np.abs(freqs) / 1000.0) ** beta
    return 10 ** (-L / 20)


def apply_rubble(x: np.ndarray, l1k_db: float, beta: float, fs: int = FS) -> np.ndarray:
    n = x.size
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / fs)
    return np.fft.irfft(X * rubble_gain(f, l1k_db, beta), n)


def inband_energy(x: np.ndarray, band: tuple[float, float], fs: int = FS) -> float:
    """Bant içi enerji (Parseval, örnek² cinsinden)."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(x.size, 1 / fs)
    m = (f >= band[0]) & (f <= band[1])
    w = np.where((f == 0) | (f == fs / 2), 1.0, 2.0)
    return float(np.sum(w[m] * np.abs(X[m]) ** 2) / x.size)


def snr_conversions(snr_ib_db: float, p: SignalParams) -> dict:
    W = p.rx_bandwidth
    ton = p.on_len / p.fs
    return {
        "snr_ib_db": snr_ib_db,
        "snr_wb_db": snr_ib_db + 10 * np.log10(W / (p.fs / 2)),
        "e_n0_db": snr_ib_db + 10 * np.log10(W * ton),
    }


# ------------------------------------------------------------------ gürültü
PINK_B = np.array([0.049922035, -0.095993537, 0.050612699, -0.004408786])
PINK_A = np.array([1.0, -2.494956002, 2.017265875, -0.522189400])


class PinkNoise:
    """Durumlu pembe gürültü (Kellet IIR, ~−3 dB/oktav), akış halinde."""

    def __init__(self, rng: np.random.Generator) -> None:
        self.rng = rng
        self.zi = np.zeros(3)

    def __call__(self, n: int) -> np.ndarray:
        y, self.zi = sps.lfilter(PINK_B, PINK_A, self.rng.standard_normal(n), zi=self.zi)
        return y


def random_fields(rng: np.random.Generator) -> Fields:
    while True:
        fid = int(rng.integers(0, 4096))
        if fid not in (0, 0xFFF):
            break
    return Fields(id=fid, people=int(rng.integers(0, 4)), injured=int(rng.integers(0, 2)),
                  life_age=int(rng.integers(0, 16)), battery=int(rng.integers(0, 8)), mode=int(rng.integers(0, 4)))


def wilson(k: int, n: int, z: float = 1.96) -> tuple[float, float]:
    if n == 0:
        return (0.0, 1.0)
    ph = k / n
    d = 1 + z * z / n
    c = (ph + z * z / (2 * n)) / d
    h = z * np.sqrt(ph * (1 - ph) / n + z * z / (4 * n * n)) / d
    return (max(0.0, c - h), min(1.0, c + h))


def poisson_ci(k: int, t: float) -> tuple[float, float]:
    """Olay oranı için %95 kesin (Garwood) güven aralığı (olay / birim zaman)."""
    from scipy.stats import chi2

    lo = 0.0 if k == 0 else chi2.ppf(0.025, 2 * k) / 2
    hi = chi2.ppf(0.975, 2 * k + 2) / 2
    return (lo / t, hi / t)


def load_thresholds() -> dict:
    import json

    f = RESULTS / "thresholds.json"
    return json.loads(f.read_text()) if f.exists() else {}


def rx_config(variant: str, n_up: int = 3, css_mode: str = "energy", thresholds: dict | None = None) -> ReceiverConfig:
    th = thresholds if thresholds is not None else load_thresholds()
    cfg = ReceiverConfig(params=VARIANTS[variant], n_up=n_up, css_mode=css_mode)
    key = f"{variant}/n_up={n_up}"
    if key in th:
        from dataclasses import replace

        cfg = replace(cfg, eta_c=th[key]["eta_c"])
    return cfg


__all__ = [
    "CHANNELS", "Channel", "FIGS", "FS", "PinkNoise", "RESULTS", "VARIANTS", "apply_rubble", "frame_from_word",
    "inband_energy", "load_thresholds", "pack", "poisson_ci", "random_fields", "rubble_gain", "rx_config",
    "snr_conversions", "stochastic_rir", "wilson",
]
