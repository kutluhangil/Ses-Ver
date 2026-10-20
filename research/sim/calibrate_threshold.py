"""CFAR birleşik eşiği eta_c kalibrasyonu (beyaz gürültü, yalnız gürültü).

Hedef: beyaz gürültüde CRC ÖNCESİ tespit oranı ≈ TARGET_PER_HOUR. CRC-8 rastgele
sözcüğü ≈ 1/256 olasılıkla geçirir; 10/saat ön tespit ≈ 0,04/saat sahte çerçeve.
Yerel maksimum bastırma eşikten bağımsız olduğu için, düşük eşikle toplanan
adayların C değerleri sıralanarak eşik seçilir.

    research/.venv/bin/python research/sim/calibrate_threshold.py
Çıktı: research/sim/results/thresholds.json
"""

from __future__ import annotations

import os

for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_v, "1")

import json
import time
from dataclasses import replace
from multiprocessing import Pool

import numpy as np

from common import RESULTS, rx_config
from sesver_signal import StreamingReceiver

TARGET_PER_HOUR = 10.0
HOURS = 2.0
CHUNK_S = 600
SEED = 31_001
LOW_ETA = {3: 12.0, 1: 9.0}


def _chunk(args):
    variant, n_up, idx = args
    cfg = replace(rx_config(variant, n_up, thresholds={}), eta_c=LOW_ETA[n_up])
    rng = np.random.default_rng([SEED, n_up, idx, 0 if variant == "v0" else 1])
    rx = StreamingReceiver(cfg)
    cs = []
    blk = 48_000
    for _ in range(CHUNK_S):
        for e in rx.process(0.05 * rng.standard_normal(blk)):
            cs.append(e.metric_c)
    return variant, n_up, cs


def main() -> None:
    t0 = time.time()
    n_chunks = int(HOURS * 3600 / CHUNK_S)
    tasks = [(v, k, i) for v in ("v0", "v0-L") for k in (3, 1) for i in range(n_chunks)]
    res: dict[str, list[float]] = {}
    with Pool() as pool:
        for v, k, cs in pool.imap_unordered(_chunk, tasks):
            res.setdefault(f"{v}/n_up={k}", []).extend(cs)
    out = {}
    for key, cs in sorted(res.items()):
        cs = np.sort(np.asarray(cs))[::-1]
        k = int(round(TARGET_PER_HOUR * HOURS))
        eta = float(cs[k - 1]) if cs.size >= k else float(LOW_ETA[int(key[-1])])
        out[key] = {"eta_c": round(eta, 2), "target_per_hour": TARGET_PER_HOUR, "hours": HOURS,
                    "n_candidates_low": int(cs.size), "low_eta": LOW_ETA[int(key[-1])],
                    "rate_at_low_eta_per_hour": cs.size / HOURS}
        print(key, out[key])
    RESULTS.mkdir(parents=True, exist_ok=True)
    (RESULTS / "thresholds.json").write_text(json.dumps(out, indent=2) + "\n")
    print(f"süre {time.time() - t0:.1f} s")


if __name__ == "__main__":
    main()
