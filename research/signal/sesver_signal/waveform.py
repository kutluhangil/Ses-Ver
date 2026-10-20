"""Dalga biçimi üretici (sözleşme §2, §3) ve alıcı şablonları.

Faz float64'te hesaplanır, çıktı float64 döner; test vektörleri float32'ye
dönüştürülerek yazılır.
"""

from __future__ import annotations

import numpy as np

from .constants import SignalParams, V0
from .payload import Fields, pack, word_to_shifts


def half_hann_window(n: int, ramp: int) -> np.ndarray:
    """Başta ve sonda `ramp` örnek yarım-Hann rampa (§3.4).

    Giriş: w[i] = 0.5(1 - cos(pi i / R)), i = 0..R-1. Çıkış: w[n-1-i] = w[i].
    """
    w = np.ones(n)
    i = np.arange(ramp)
    r = 0.5 * (1.0 - np.cos(np.pi * i / ramp))
    w[:ramp] = r
    w[n - ramp :] = r[::-1]
    return w


def phase_up(p: SignalParams) -> np.ndarray:
    t = np.arange(p.n_pre) / p.fs
    return 2.0 * np.pi * (p.f_low * t + (p.bandwidth / (2.0 * p.tp)) * t * t)


def phase_down(p: SignalParams) -> np.ndarray:
    t = np.arange(p.n_pre) / p.fs
    return 2.0 * np.pi * (p.f_high * t - (p.bandwidth / (2.0 * p.tp)) * t * t)


def phase_symbol(p: SignalParams, s: int) -> np.ndarray:
    """Döngüsel kaydırmalı yükselen chirp fazı (§3.3).

    Sarma anı tw = Ts(1 - s/M); örnek cinsinden nw = n_sym - s * n_sym / M
    (tam sayı: 3072 - 192 s). Koşul t < tw, n < nw ile birebir aynıdır.
    """
    if not 0 <= s < p.alphabet:
        raise ValueError("kaydırma 0..M-1")
    n = np.arange(p.n_sym)
    t = n / p.fs
    k = p.chirp_rate_sym
    nw = p.n_sym - s * p.shift_step_samples
    tw = nw / p.fs
    f0 = p.f_low + s * p.bandwidth / p.alphabet
    phi = 2.0 * np.pi * (f0 * t + 0.5 * k * t * t)
    if s > 0:
        phi_tw = 2.0 * np.pi * (f0 * tw + 0.5 * k * tw * tw)
        u = t[nw:] - tw
        phi[nw:] = phi_tw + 2.0 * np.pi * (p.f_low * u + 0.5 * k * u * u)
    return phi


def up_chirp(p: SignalParams = V0) -> np.ndarray:
    return p.amplitude * half_hann_window(p.n_pre, p.ramp_chirp) * np.sin(phase_up(p))


def down_chirp(p: SignalParams = V0) -> np.ndarray:
    return p.amplitude * half_hann_window(p.n_pre, p.ramp_chirp) * np.sin(phase_down(p))


def symbol(p: SignalParams, s: int) -> np.ndarray:
    return p.amplitude * half_hann_window(p.n_sym, p.ramp_symbol) * np.sin(phase_symbol(p, s))


def frame_from_shifts(shifts: list[int], p: SignalParams = V0) -> np.ndarray:
    if len(shifts) != p.n_symbols:
        raise ValueError("8 sembol gerekli")
    x = np.zeros(p.frame_len)
    u = up_chirp(p)
    for st in p.up_starts:
        x[st : st + p.n_pre] = u
    x[p.down_start : p.down_start + p.n_pre] = down_chirp(p)
    for i, s in enumerate(shifts):
        st = p.symbol_start(i)
        x[st : st + p.n_sym] = symbol(p, s)
    return x


def frame_from_word(w: int, p: SignalParams = V0) -> np.ndarray:
    return frame_from_shifts(word_to_shifts(w), p)


def frame(fields: Fields, p: SignalParams = V0) -> np.ndarray:
    return frame_from_word(pack(fields), p)


# --- Alıcı şablonları (analitik, karmaşık) ---

def analytic_up_template(p: SignalParams) -> np.ndarray:
    return half_hann_window(p.n_pre, p.ramp_chirp) * np.exp(1j * phase_up(p))


def analytic_down_template(p: SignalParams) -> np.ndarray:
    return half_hann_window(p.n_pre, p.ramp_chirp) * np.exp(1j * phase_down(p))


def analytic_base_symbol(p: SignalParams) -> np.ndarray:
    """Dechirp için taban (s = 0) chirp, pencere yok."""
    return np.exp(1j * phase_symbol(p, 0))


def analytic_symbol_templates(p: SignalParams) -> np.ndarray:
    """Tutarlı (coherent) karşılaştırma modu için 16 sembol şablonu (M x n_sym)."""
    w = half_hann_window(p.n_sym, p.ramp_symbol)
    return np.stack([w * np.exp(1j * phase_symbol(p, s)) for s in range(p.alphabet)])
