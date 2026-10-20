"""F0-3b yanlış kabul: sentetik şantiye gürültüsünde aday başına sahte çerçeve oranı.

    research/.venv/bin/python research/sim/run_f03b_false_alarm.py [--hours 6]
Çıktı: research/sim/results/f03b_false_alarm.json

Gürültü üreticisi, tohum ve akış düzeni F0-3 `run_false_alarm.py` ile aynı (tohum 61004,
30 dk parçalar, blok 4 800, ölçek 0,05); ilk 3 saat F0-3'teki gürültünün aynısıdır.
İki alıcı geçişi:
  B0: v0 tespit hattı, düzen v0 (karar: enerji, tutarlı E0)
  B1: v0-L tespit hattı (B1 giriş bölümü), düzenler v1-E1, v1-E3, v1-E1E3 aynı adaylardan çözülür
Her aday için her karar kuralının sonucu kaydedilir; ardından:
  * kuralsız: kabul edilen sahte çerçeve/saat
  * iki çerçeve kuralı (signal-v0 §6): aynı id, Δt ∈ [8,6 s; 207 s], people ve injured aynı,
    lifeAge geri gitmiyor -> doğrulanmış sahte işaret/saat
  * E4: tek başına reddedilen iki aday, Δt ∈ [8,6 s; 11,5 s] ise metrikleri toplanıp yeniden çözülür.
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

from common import poisson_ci
from noise_models import SEG_S, SOURCES
from run_f03b_pdfer import decoders
from common import RESULTS
from sesver_signal import V0, ReceiverConfig
from sesver_signal.v1 import CODING, V1_E1, V1_E1E3, V1_E3, V1Receiver, decode_metrics

SEED = 61_004
PART_S = 1800
BLOCK = 4800
FS = 48_000
PAIR_E4 = (8.6, 11.5)
PAIR_RULE = (8.6, 207.0)
PASSES = {
    "B0": (ReceiverConfig(params=V0, eta_c=22.25), [V0]),
    "B1": (ReceiverConfig(params=V1_E1E3, eta_c=22.3), [V1_E1, V1_E3, V1_E1E3]),
}


def _part(args):
    bandk, idx = args
    noise = "construction"
    # F0-3 ile aynı tohum dizisi (v0 -> 0, v0-L -> 1)
    rng = np.random.default_rng([SEED, idx, list(SOURCES).index(noise), 0 if bandk == "B0" else 1])
    src = SOURCES[noise](rng)
    cfg, lays = PASSES[bandk]
    rx = V1Receiver(cfg, lays)
    evs = []
    for _ in range(int(PART_S / SEG_S)):
        seg = 0.05 * src.segment()
        for i in range(0, seg.size, BLOCK):
            evs += rx.process(seg[i : i + BLOCK])
    evs += rx.flush()
    out = {"n_pre": len(evs), "lay": {}}
    for lp in lays:
        decs = decoders(lp.name)
        r = {}
        for k, (mt, cod, t, sr) in decs.items():
            mets = [(e.e_coh if mt == "coh" else e.e_en)[lp.name] for e in evs]
            ds = [decode_metrics(E, cod, t, sr) for E in mets]
            ts = [e.start / FS for e in evs]
            single = [(ts[i], d.fields) for i, d in enumerate(ds) if d.ok]
            e4, n_pairs = [], 0
            for i in range(len(evs)):
                if ds[i].ok:
                    continue
                for j in range(i + 1, len(evs)):
                    dt = ts[j] - ts[i]
                    if dt > PAIR_E4[1]:
                        break
                    if dt >= PAIR_E4[0] and not ds[j].ok:
                        n_pairs += 1
                        d = decode_metrics(mets[i] + mets[j], cod, t, sr)
                        if d.ok:
                            e4.append((ts[j], d.fields))
            r[k] = {"single": len(single), "single_verified": verified(single),
                    "e4_pairs": n_pairs, "e4_extra": len(e4), "e4_verified": verified(sorted(single + e4, key=lambda x: x[0])),
                    "ids": [f.id for _, f in single]}
        out["lay"][lp.name] = r
    return bandk, idx, out


def verified(frames) -> int:
    """İki çerçeve kuralını geçen sahte işaret sayısı (her ikinci çerçeve en çok bir kez)."""
    n = 0
    for j, (tj, fj) in enumerate(frames):
        for ti, fi in frames[:j]:
            if (PAIR_RULE[0] <= tj - ti <= PAIR_RULE[1] and fi.id == fj.id and fi.people == fj.people
                    and fi.injured == fj.injured and fj.life_age >= fi.life_age):
                n += 1
                break
    return n


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--hours", type=float, default=6.0)
    a = ap.parse_args()
    n_parts = int(round(a.hours * 3600 / PART_S))
    tasks = [(b, k) for b in PASSES for k in range(n_parts)]
    t0 = time.time()
    agg: dict = {}
    with Pool() as pool:
        for b, k, o in pool.imap_unordered(_part, tasks):
            A = agg.setdefault(b, {"n_pre": 0, "lay": {}})
            A["n_pre"] += o["n_pre"]
            for ln, r in o["lay"].items():
                for dk, v in r.items():
                    D = A["lay"].setdefault(ln, {}).setdefault(dk, {})
                    for m, x in v.items():
                        D[m] = D.get(m, 0 if m != "ids" else []) + x
    hours = n_parts * PART_S / 3600
    res = []
    for b, A in agg.items():
        for ln, r in A["lay"].items():
            for dk, D in r.items():
                row = {"pass": b, "layout": ln, "decoder": dk, "hours": hours, "pre_crc": A["n_pre"],
                       "pre_per_h": A["n_pre"] / hours, **{m: D[m] for m in D if m != "ids"},
                       "dup_ids": int(len(D["ids"]) - len(set(D["ids"])))}
                for m in ("single", "single_verified", "e4_verified"):
                    row[f"{m}_per_h"] = D[m] / hours
                    row[f"{m}_ci95"] = list(poisson_ci(D[m], hours))
                row["single_plus_e4_per_h"] = (D["single"] + D["e4_extra"]) / hours
                row["single_plus_e4_ci95"] = list(poisson_ci(D["single"] + D["e4_extra"], hours))
                res.append(row)
                print(b, ln, dk, D["single"], D["e4_extra"], D["single_verified"], D["e4_verified"])
    out = {"seed": SEED, "hours_per_pass": hours, "wall_s": round(time.time() - t0, 1), "results": res}
    (RESULTS / "f03b_false_alarm.json").write_text(json.dumps(out, indent=1) + "\n")
    print(f"süre {out['wall_s']} s")


if __name__ == "__main__":
    main()
