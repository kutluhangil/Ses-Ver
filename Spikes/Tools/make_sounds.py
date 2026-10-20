#!/usr/bin/env python3
"""Spike'lar için paketlenen bildirim/alarm sesini üretir: Shared/Sounds/sv_chirp_25s.wav

Shared/ChirpWaveform.swift ile aynı yaklaşık çerçeve (U1 G1 U2 G2 U3 G3 D S0..S7, signal-v0 düzeni).
NORMATİF DEĞİL; referans üretici research/signal (dsp-acoustics) altındadır.
Yalnızca standart kütüphane. Kullanım: python3 -I Spikes/Tools/make_sounds.py
"""
import math
import struct
import sys
import wave
from pathlib import Path

FL, FH = 1800.0, 4200.0
B = FH - FL
TP, TG, TS = 0.120, 0.080, 0.064
AMP = 0.891
SHIFTS = [7, 15, 2, 0, 9, 4, 12, 1]


def window(i, n, r):
    if r <= 0:
        return 1.0
    if i < r:
        return 0.5 * (1 - math.cos(math.pi * i / r))
    j = n - 1 - i
    if j < r:
        return 0.5 * (1 - math.cos(math.pi * j / r))
    return 1.0


def chirp(fs, rising):
    n = round(TP * fs)
    k = B / (2 * TP)
    r = int(0.005 * fs)
    out = []
    for i in range(n):
        t = i / fs
        phi = 2 * math.pi * ((FL * t + k * t * t) if rising else (FH * t - k * t * t))
        out.append(AMP * window(i, n, r) * math.sin(phi))
    return out


def css(fs, s):
    n = round(TS * fs)
    k = B / TS
    tw = TS * (1 - s / 16)
    f0 = FL + s * B / 16
    phi_tw = 2 * math.pi * (f0 * tw + 0.5 * k * tw * tw)
    r = int(0.002 * fs)
    out = []
    for i in range(n):
        t = i / fs
        if t < tw:
            phi = 2 * math.pi * (f0 * t + 0.5 * k * t * t)
        else:
            u = t - tw
            phi = phi_tw + 2 * math.pi * (FL * u + 0.5 * k * u * u)
        out.append(AMP * window(i, n, r) * math.sin(phi))
    return out


def frame(fs):
    gap = [0.0] * round(TG * fs)
    out = []
    for _ in range(3):
        out += chirp(fs, True) + gap
    out += chirp(fs, False)
    for s in SHIFTS:
        out += css(fs, s)
    return out


def main():
    fs = 22050
    total_s, interval_s = 25.0, 10.0   # 3 çerçeve; 60 s penceresinde görev döngüsü ≈ %5
    total = int(total_s * fs)
    pcm = [0.0] * total
    f = frame(fs)
    start = 0
    while start < total:
        for i, v in enumerate(f):
            if start + i < total:
                pcm[start + i] = v
        start += int(interval_s * fs)
    out = Path(__file__).resolve().parent.parent / "Shared" / "Sounds" / "sv_chirp_25s.wav"
    out.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(out), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(fs)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in pcm))
    print(f"wrote {out} ({total / fs:.1f} s, {fs} Hz)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
