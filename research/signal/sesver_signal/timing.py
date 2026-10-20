"""Verici zamanlaması (sözleşme §5) ve görev döngüsü hesabı."""

from __future__ import annotations

import numpy as np

from .constants import SignalParams, V0

JITTER = (0.86, 1.15)  # signal-v0 r2 §5


def nominal_interval_s(hours_since_activation: float, battery_percent: float | None = None) -> float:
    h = hours_since_activation
    if h < 0:
        raise ValueError("süre negatif olamaz")
    if h < 6:
        i = 10.0
    elif h < 24:
        i = 20.0
    elif h < 72:
        i = 45.0
    else:
        i = 90.0
    if battery_percent is not None and battery_percent < 20.0:
        i *= 2.0
    return i


def draw_interval_s(nominal_s: float, rng: np.random.Generator) -> float:
    """Gerçek aralık I * U(0,85; 1,15), her çerçevede bağımsız."""
    return nominal_s * rng.uniform(*JITTER)


def duty_cycle(interval_s: float, p: SignalParams = V0) -> float:
    """Ton / I (bilgi notu, §5)."""
    return (p.on_len / p.fs) / interval_s


def frame_on_mask(p: SignalParams = V0) -> np.ndarray:
    """Çerçeve içinde akustik açık örnekleri (1) ve boşlukları (0) verir."""
    m = np.zeros(p.frame_len, dtype=bool)
    for st in p.up_starts:
        m[st : st + p.n_pre] = True
    m[p.down_start : p.frame_len] = True
    return m


def schedule(n_frames: int, nominal_s: float, rng: np.random.Generator, t0: float = 0.0) -> np.ndarray:
    """Çerçeve başlangıç zamanları (s)."""
    starts = [t0]
    for _ in range(n_frames - 1):
        starts.append(starts[-1] + draw_interval_s(nominal_s, rng))
    return np.asarray(starts)


def max_window_duty(starts_s: np.ndarray, window_s: float = 60.0, p: SignalParams = V0,
                    resolution_s: float = 0.001) -> float:
    """Verilen çerçeve başlangıçları için herhangi bir `window_s` penceresindeki
    en yüksek ortalama görev döngüsü (açık süre / pencere).

    Açık süre `resolution_s` çözünürlükle ızgarada hesaplanır.
    """
    mask = frame_on_mask(p)
    # Çerçeve maskesini çözünürlüğe indir (her hücrede açık oranı).
    step = int(round(resolution_s * p.fs))
    n_cells = int(np.ceil(p.frame_len / step))
    padded = np.zeros(n_cells * step)
    padded[: p.frame_len] = mask
    cell = padded.reshape(n_cells, step).mean(axis=1) * resolution_s
    total_s = float(starts_s[-1] - starts_s[0]) + p.frame_len / p.fs + window_s
    grid = np.zeros(int(np.ceil(total_s / resolution_s)) + n_cells + 1)
    for st in starts_s - starts_s[0]:
        k = int(round(st / resolution_s))
        grid[k : k + n_cells] += cell
    win = int(round(window_s / resolution_s))
    cs = np.concatenate([[0.0], np.cumsum(grid)])
    sums = cs[win:] - cs[:-win]
    return float(sums.max() / window_s)
