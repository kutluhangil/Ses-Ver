"""Alıcı CPU ölçümü: tek çekirdek, 1 sn ses başına işlem süresi ve gerçek zaman faktörü.

    research/.venv/bin/python research/sim/run_cpu.py
Çıktı: research/sim/results/cpu.json

time.process_time() (yalnız bu süreç, tek iş parçacığı; numpy/scipy FFT tek iş
parçacıklı). Senaryolar: yalnız beyaz gürültü (aday yok) ve her 10 sn'de bir
çerçeve (SNR_ib = −10 dB, her çerçeve çözülür). Blok boyları 1 024 ve 4 800.
"""

from __future__ import annotations

import os

for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_v, "1")

import json
import platform
import subprocess
import time

import numpy as np

from common import RESULTS, VARIANTS, inband_energy, pack, random_fields, rx_config
from sesver_signal import StreamingReceiver, frame_from_word

DUR_S = 120
SEED = 71_005


def make_audio(variant: str, with_frames: bool) -> np.ndarray:
    p = VARIANTS[variant]
    rng = np.random.default_rng(SEED)
    n = DUR_S * p.fs
    y = np.zeros(n)
    if with_frames:
        x = frame_from_word(pack(random_fields(rng)), p)
        e = inband_energy(np.concatenate([np.zeros(4800), x, np.zeros(4800)]), p.rx_band) / p.on_len
        for st in range(p.fs, n - x.size, 10 * p.fs):
            y[st : st + x.size] += x
        sigma = np.sqrt(e / (10 ** (-10 / 10) * p.rx_bandwidth / (p.fs / 2)))
    else:
        sigma = 0.05
    return y + sigma * rng.standard_normal(n)


def main() -> None:
    out = {"machine": platform.machine(), "python": platform.python_version(), "duration_s": DUR_S, "runs": []}
    try:
        out["cpu"] = subprocess.run(["sysctl", "-n", "machdep.cpu.brand_string"], capture_output=True, text=True).stdout.strip()
    except OSError:
        out["cpu"] = "?"
    for v in ("v0", "v0-L"):
        for frames in (False, True):
            audio = make_audio(v, frames)
            for block in (1024, 4800):
                best = None
                for _ in range(3):
                    rx = StreamingReceiver(rx_config(v))
                    n_ev = 0
                    t = time.process_time()
                    for i in range(0, audio.size, block):
                        n_ev += len(rx.process(audio[i : i + block]))
                    dt = time.process_time() - t
                    best = dt if best is None else min(best, dt)
                r = {"variant": v, "frames_every_10s": frames, "block": block, "events": n_ev,
                     "ms_per_audio_s": 1000 * best / DUR_S, "rtf": DUR_S / best}
                out["runs"].append(r)
                print(r)
    (RESULTS / "cpu.json").write_text(json.dumps(out, indent=1) + "\n")


if __name__ == "__main__":
    main()
