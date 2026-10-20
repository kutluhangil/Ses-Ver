"""F0-6 görüşmeleri için aday ritim WAV'ları.

    research/.venv/bin/python research/signal/rhythms/make_rhythms.py

Çıktı (48 kHz, 16 bit PCM, mono, ~30 sn):
    ritim_A_v0.wav       SignalSpec v0 (1,8-4,2 kHz), 3 yükselen + alçalan + veri
    ritim_B_v0L.wav      v0-L (1,2-3,0 kHz), aynı ritim
    ritim_C_alt2uzun.wav Alternatif: 2 uzun (180 ms) yükselen ıslık + alçalan + veri (v0 bandı)

Aralıklar sözleşme §5'teki gerçek kurala göre: nominal 10 sn × U(0,85; 1,15),
sabit tohum. Genlik A = −1 dBFS, outputGain = 1.
Ritim C bir ÖNERİDİR, sözleşmede yoktur; v0 alıcısı onu çözmez (farklı senk).
Açık süresi (Ton) v0 ile aynı tutuldu (992 ms) → görev döngüsü aynı.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from scipy.io import wavfile

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

from sesver_signal import V0, V0L, Fields, pack  # noqa: E402
from sesver_signal.payload import word_to_shifts  # noqa: E402
from sesver_signal.timing import duty_cycle, max_window_duty  # noqa: E402
from sesver_signal.waveform import down_chirp, frame_from_word, half_hann_window, symbol  # noqa: E402

SEED = 6_006
DURATION_S = 30.0
NOMINAL_S = 10.0
FIELDS = Fields(id=0x7F2, people=1, injured=1, life_age=2, battery=6, mode=0)


def alt_frame(w: int) -> tuple[np.ndarray, int]:
    """Ritim C: 2 × 180 ms yükselen (1,8→4,2 kHz), 120 ms boşluk, 80 ms boşluk, D, 8 sembol."""
    p = V0
    n_long = 8_640  # 180 ms
    t = np.arange(n_long) / p.fs
    tl = n_long / p.fs
    up_long = p.amplitude * half_hann_window(n_long, p.ramp_chirp) * np.sin(
        2 * np.pi * (p.f_low * t + p.bandwidth / (2 * tl) * t * t))
    gap1, gap2 = 5_760, 3_840
    parts = [up_long, np.zeros(gap1), up_long, np.zeros(gap2), down_chirp(p)]
    parts += [symbol(p, s) for s in word_to_shifts(w)]
    x = np.concatenate(parts)
    on = 2 * n_long + p.n_pre + p.n_symbols * p.n_sym
    return x, on


def render(frame_x: np.ndarray, rng: np.random.Generator, fs: int) -> tuple[np.ndarray, list[float]]:
    n = int(DURATION_S * fs)
    y = np.zeros(n)
    t = 1.0
    starts = []
    while True:
        k = int(round(t * fs))
        if k + frame_x.size > n:
            break
        y[k : k + frame_x.size] += frame_x
        starts.append(round(t, 3))
        t += NOMINAL_S * rng.uniform(0.85, 1.15)
    return y, starts


def write(name: str, y: np.ndarray, fs: int) -> None:
    pcm = np.clip(np.round(y * 32767.0), -32768, 32767).astype(np.int16)
    wavfile.write(HERE / name, fs, pcm)


def main() -> None:
    w = pack(FIELDS)
    rng = np.random.default_rng(SEED)
    meta = {"seed": SEED, "fields": FIELDS.to_dict(), "W_hex": f"0x{w:08X}", "nominal_interval_s": NOMINAL_S,
            "format": "48 kHz, 16 bit PCM, mono, A = -1 dBFS", "files": {}}
    for name, x, on, p in (
        ("ritim_A_v0.wav", frame_from_word(w, V0), V0.on_len, V0),
        ("ritim_B_v0L.wav", frame_from_word(w, V0L), V0L.on_len, V0L),
        ("ritim_C_alt2uzun.wav", *alt_frame(w), V0),
    ):
        y, starts = render(x, rng, p.fs)
        write(name, y, p.fs)
        meta["files"][name] = {
            "frame_ms": round(1000 * x.size / p.fs, 1), "on_ms": round(1000 * on / p.fs, 1),
            "starts_s": starts, "duty_nominal": round((on / p.fs) / NOMINAL_S, 4),
            "duty_worst_8_5s": round((on / p.fs) / 8.5, 4),
        }
        print(name, meta["files"][name])
    (HERE / "rhythms.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n")
    assert abs(duty_cycle(10.0) - 0.0992) < 1e-3
    _ = max_window_duty  # yalnız rapor için


if __name__ == "__main__":
    main()
