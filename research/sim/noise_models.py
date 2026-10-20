"""Yalnız-gürültü üreticileri: beyaz, pembe ve sentetik "şantiye benzeri" gürültü.

Şantiye modeli tamamen SENTETİKTİR [Tahmin]. Gerçek kayıt yerine geçmez; amaç
alıcıyı chirp detektörünü zorlayabilecek yapılara (periyodik darbe, ton, tarama)
maruz bırakmaktır. Bileşen düzeyleri arka plan pembe gürültünün RMS'ine göre dB.

| Bileşen | Olasılık (10 sn dilim başına) | Düzey | Neden |
|---|---|---|---|
| Pembe arka plan | her zaman | 0 dB | geniş bant taban |
| Kırıcı (jackhammer) | 0,4 | darbe başına tepe +20…+30 dB, 18–30 Hz | periyodik darbe, 9 600 örnek aralığına denk gelebilir |
| Çekiç darbesi | Poisson 0,3/s | tepe +15…+30 dB | sönümlü rezonans (1–5 kHz) |
| Motor / jeneratör | 0,7 | RMS 0 dB, f0 25–45 Hz | harmonik ses, FM |
| Taşlama | 0,3 | RMS +6 dB, 2,5–4,5 kHz | bant içi ton |
| Geri vites uyarısı | 0,3 | RMS +6 dB, 1,0–1,2 kHz, 0,5 s aç/kapa | bant içi/yakın ton |
| Siren (yelp) | 0,15 | RMS +6 dB, 650→1 600 Hz / 0,25 s | yavaş tarama |
| Gıcırtı/sürtünme taraması | Poisson 0,5/s | +0…+15 dB, 50–300 ms, 0,8–5 kHz rastgele doğrusal tarama | chirp benzeri saldırgan girişim |
"""

from __future__ import annotations

import numpy as np
from scipy import signal as sps

from common import FS, PinkNoise

SEG_S = 10.0


class WhiteSource:
    def __init__(self, rng: np.random.Generator) -> None:
        self.rng = rng

    def segment(self) -> np.ndarray:
        return self.rng.standard_normal(int(SEG_S * FS))


class PinkSource:
    def __init__(self, rng: np.random.Generator) -> None:
        self.pn = PinkNoise(rng)
        self.pn(48_000)  # geçici rejimi at
        ref = self.pn(480_000)
        self.scale = 1.0 / np.std(ref)

    def segment(self) -> np.ndarray:
        return self.scale * self.pn(int(SEG_S * FS))


def _db(x: float) -> float:
    return 10 ** (x / 20)


class ConstructionSource:
    def __init__(self, rng: np.random.Generator) -> None:
        self.rng = rng
        self.bg = PinkSource(rng)
        # motor süzgeci (darbe katarından harmonik ses)
        self.eng_b, self.eng_a = sps.butter(2, 1500, fs=FS)

    def segment(self) -> np.ndarray:
        rng = self.rng
        n = int(SEG_S * FS)
        t = np.arange(n) / FS
        y = self.bg.segment()
        # kırıcı
        if rng.random() < 0.4:
            rate = rng.uniform(18, 30)
            on0, on1 = sorted(rng.uniform(0, SEG_S, 2))
            k = np.arange(int(0.006 * FS))
            base = np.arange(on0, on1, 1 / rate)
            imp_t = base + rng.normal(0, 0.02 / rate, base.size)
            fr = rng.uniform(800, 3000)
            for ti in imp_t:
                i = int(ti * FS)
                if i + k.size >= n:
                    break
                burst = rng.standard_normal(k.size) * np.exp(-k / (0.004 * FS / 4.6))
                burst += 2 * np.sin(2 * np.pi * fr * k / FS) * np.exp(-k / (0.010 * FS / 4.6))
                y[i : i + k.size] += _db(rng.uniform(20, 30)) / 3 * burst
        # çekiç
        for ti in rng.uniform(0, SEG_S, rng.poisson(0.3 * SEG_S)):
            i = int(ti * FS)
            L = int(0.2 * FS)
            if i + L >= n:
                continue
            kk = np.arange(L) / FS
            b = np.zeros(L)
            for _ in range(3):
                b += np.sin(2 * np.pi * rng.uniform(1000, 5000) * kk + rng.uniform(0, 6.28)) * np.exp(-4.6 * kk / rng.uniform(0.03, 0.15))
            b[:48] += rng.standard_normal(48) * 3
            y[i : i + L] += _db(rng.uniform(15, 30)) / 3 * b
        # motor
        if rng.random() < 0.7:
            f0 = rng.uniform(25, 45) * (1 + 0.015 * np.sin(2 * np.pi * 0.5 * t + rng.uniform(0, 6.28)))
            ph = np.cumsum(f0) / FS
            pulses = (np.diff(np.floor(ph), prepend=0) > 0).astype(float)
            e = sps.lfilter(self.eng_b, self.eng_a, pulses)
            y += e / (np.std(e) + 1e-12)
        # taşlama
        if rng.random() < 0.3:
            f = rng.uniform(2500, 4500) * (1 + 0.03 * np.sin(2 * np.pi * rng.uniform(0.1, 0.5) * t))
            ph = 2 * np.pi * np.cumsum(f) / FS
            g = np.sin(ph) + 0.3 * np.sin(2 * ph)
            a, b2 = sorted(rng.uniform(0, SEG_S, 2))
            m = (t >= a) & (t < max(b2, a + 3))
            y += m * g * _db(6) * np.sqrt(2) / 1.04
        # geri vites uyarısı
        if rng.random() < 0.3:
            f = rng.uniform(1000, 1200)
            gate = (np.floor(t / 0.5) % 2 == 0).astype(float)
            y += gate * np.sin(2 * np.pi * f * t) * _db(6) * np.sqrt(2)
        # siren (yelp)
        if rng.random() < 0.15:
            tau = np.mod(t, 0.25) / 0.25
            f = 650 + 950 * tau
            y += np.sin(2 * np.pi * np.cumsum(f) / FS) * _db(6) * np.sqrt(2)
        # gıcırtı taramaları
        for ti in rng.uniform(0, SEG_S, rng.poisson(0.5 * SEG_S)):
            d = rng.uniform(0.05, 0.3)
            L = int(d * FS)
            i = int(ti * FS)
            if i + L >= n:
                continue
            f_a, f_b = rng.uniform(800, 5000, 2)
            kk = np.arange(L) / FS
            ph = 2 * np.pi * (f_a * kk + (f_b - f_a) / (2 * d) * kk * kk)
            w = np.hanning(L)
            y[i : i + L] += w * np.sin(ph) * _db(rng.uniform(0, 15)) * np.sqrt(2)
        return y


SOURCES = {"white": WhiteSource, "pink": PinkSource, "construction": ConstructionSource}
