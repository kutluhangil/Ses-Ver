"""Yanlış alarm: yalnız gürültü üzerinde CRC öncesi tespit ve CRC geçen sahte çerçeve oranı.

    research/.venv/bin/python research/sim/run_false_alarm.py [--hours 3]
Çıktı: research/sim/results/false_alarm.json

Her (gürültü türü, varyant) için `hours` saatlik ses, 30 dakikalık bağımsız
parçalar halinde (her parça kendi tohumuyla, kesintisiz akış) işlenir. Kalibrasyon
tohumlarından farklı tohum kullanılır. Güven aralığı: Poisson (Garwood) %95.
"""

from __future__ import annotations

import os

for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_v, "1")

import argparse
import json
import time
from multiprocessing import Pool

import numpy as np

from common import RESULTS, poisson_ci, rx_config
from noise_models import SEG_S, SOURCES
from sesver_signal import StreamingReceiver

SEED = 61_004
PART_S = 1800
BLOCK = 4800


def _part(args):
    noise, variant, idx = args
    rng = np.random.default_rng([SEED, idx, list(SOURCES).index(noise), 0 if variant == "v0" else 1])
    src = SOURCES[noise](rng)
    rx = StreamingReceiver(rx_config(variant))
    kinds: dict[str, int] = {}
    cs = []
    for _ in range(int(PART_S / SEG_S)):
        seg = 0.05 * src.segment()
        for i in range(0, seg.size, BLOCK):
            for e in rx.process(seg[i : i + BLOCK]):
                kinds[e.kind] = kinds.get(e.kind, 0) + 1
                cs.append(e.metric_c)
    for e in rx.flush():
        kinds[e.kind] = kinds.get(e.kind, 0) + 1
        cs.append(e.metric_c)
    return noise, variant, kinds, cs


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--hours", type=float, default=3.0)
    a = ap.parse_args()
    n_parts = int(round(a.hours * 3600 / PART_S))
    tasks = [(nz, v, k) for nz in SOURCES for v in ("v0", "v0-L") for k in range(n_parts)]
    t0 = time.time()
    acc: dict[tuple[str, str], dict] = {}
    with Pool() as pool:
        for nz, v, kinds, cs in pool.imap_unordered(_part, tasks):
            r = acc.setdefault((nz, v), {"kinds": {}, "cs": []})
            for k, c in kinds.items():
                r["kinds"][k] = r["kinds"].get(k, 0) + c
            r["cs"] += cs
    hours = n_parts * PART_S / 3600
    out = {"seed": SEED, "hours_per_case": hours, "results": []}
    for (nz, v), r in sorted(acc.items()):
        pre = sum(r["kinds"].values())
        valid = r["kinds"].get("beacon", 0) + r["kinds"].get("response", 0)
        lo, hi = poisson_ci(pre, hours)
        vlo, vhi = poisson_ci(valid, hours)
        out["results"].append({
            "noise": nz, "variant": v, "hours": hours, "kinds": r["kinds"],
            "pre_crc_per_hour": pre / hours, "pre_crc_ci95": [lo, hi],
            "valid_false_frames": valid, "valid_per_hour": valid / hours, "valid_ci95": [vlo, vhi],
            "expected_valid_per_hour_from_crc": pre / hours / 256.0,
            "max_metric_c": max(r["cs"]) if r["cs"] else None,
        })
        print(nz, v, r["kinds"], f"ön={pre / hours:.2f}/sa [{lo:.2f},{hi:.2f}]", f"geçerli={valid} [{vlo:.3f},{vhi:.3f}]/sa")
    out["wall_s"] = round(time.time() - t0, 1)
    (RESULTS / "false_alarm.json").write_text(json.dumps(out, indent=1) + "\n")
    print(f"süre {out['wall_s']} s")


if __name__ == "__main__":
    main()
