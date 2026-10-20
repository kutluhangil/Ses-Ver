"""F0-3b sürüm ayrımı (ADR-0004 V-a): v0 alıcısı v1 çerçevelerinde CRC'yi geçen sahte çözüm üretiyor mu?

    research/.venv/bin/python research/sim/run_f03b_crossver.py [--frames 1000]
Çıktı: research/sim/results/f03b_crossver.json

Her durumda `frames` adet rastgele yüklü çerçeve, 3 sn'lik yuvalara yerleştirilir, beyaz gürültü
eklenir (SNR_ib vericinin kendi alıcı bandında, Ton üzerinden) ve tek akış olarak işlenir.
  * v0 alıcısı (değiştirilmemiş StreamingReceiver; enerji ve tutarlı karar) <- v1-E1, v1-E3, v1-E1E3, v1-E1s
  * ters yön: B1 alıcısı (V1Receiver, RS t=2 / CRC-P1) <- v0 çerçeveleri
Sayılar: CRC öncesi aday, CRC (veya RS) geçen çerçeve, bunların türü.
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

from common import RESULTS, inband_energy, poisson_ci
from run_f03b_pdfer import WAVES, make_frame
from sesver_signal import V0, ReceiverConfig, StreamingReceiver
from sesver_signal.v1 import V1_E1, V1_E1E3, V1_E3, V1Receiver, decode_metrics

SEED = 81_007
SLOT = 3 * 48_000
SNRS = (20.0, 0.0, -10.0)
BLOCK = 4800


def stream(wave: str, n: int, snr: float, rng) -> np.ndarray:
    p = WAVES[wave]
    y = np.zeros(n * SLOT + SLOT)
    e = []
    for k in range(n):
        x, _ = make_frame(wave, rng)
        st = k * SLOT + 24_000 + int(rng.integers(0, 4800))
        y[st : st + x.size] = x
        e.append(inband_energy(np.concatenate([np.zeros(2400), x, np.zeros(2400)]), p.rx_band) / p.on_len)
    sigma = np.sqrt(np.mean(e) / (10 ** (snr / 10) * p.rx_bandwidth / (p.fs / 2)))
    return y + sigma * rng.standard_normal(y.size)


def _task(args):
    direction, wave, snr, mode, n = args
    rng = np.random.default_rng([SEED, list(WAVES).index(wave), int(snr) + 100])
    y = stream(wave, n, snr, rng)
    kinds: dict[str, int] = {}
    if direction == "v0rx":
        rx = StreamingReceiver(ReceiverConfig(params=V0, eta_c=22.25, css_mode=mode))
        ev = []
        for i in range(0, y.size, BLOCK):
            ev += rx.process(y[i : i + BLOCK])
        ev += rx.flush()
        for e in ev:
            kinds[e.kind] = kinds.get(e.kind, 0) + 1
        ids = [e.fields.id for e in ev if e.valid]
    else:
        rx = V1Receiver(ReceiverConfig(params=V1_E1E3, eta_c=22.3), [V1_E1, V1_E3, V1_E1E3])
        ev = []
        for i in range(0, y.size, BLOCK):
            ev += rx.process(y[i : i + BLOCK])
        ev += rx.flush()
        kinds["pre"] = len(ev)
        ids = []
        for ln, cod, t in (("v1-E1", "rs", 2), ("v1-E1", "rs", 1), ("v1-E3", "crc_p1", 0), ("v1-E1E3", "rs", 2)):
            ok = [decode_metrics(e.e_coh[ln], cod, t) for e in ev]
            kinds[f"{ln}|{cod}|t{t}"] = sum(d.ok for d in ok)
    n_pre = sum(v for k, v in kinds.items() if k in ("crc_fail", "beacon", "response", "reserved_id", "pre"))
    return {"direction": direction, "wave": wave, "snr_ib_db": snr, "css_mode": mode, "frames": n,
            "kinds": kinds, "pre": n_pre, "valid": sum(kinds.get(k, 0) for k in ("beacon", "response")),
            "valid_ids": ids}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--frames", type=int, default=1000)
    a = ap.parse_args()
    tasks = [("v0rx", w, s, m, a.frames) for w in ("v1-E1", "v1-E3", "v1-E1E3", "v1-E1s") for s in SNRS
             for m in ("energy", "coherent")]
    tasks += [("b1rx", "v0", s, "coherent", a.frames) for s in SNRS]
    t0 = time.time()
    with Pool() as pool:
        res = pool.map(_task, tasks, chunksize=1)
    for r in res:
        r["valid_per_frame_ci95"] = [x / r["frames"] for x in poisson_ci(r["valid"], 1.0)]
        print(r["direction"], r["wave"], r["snr_ib_db"], r["css_mode"], r["kinds"])
    out = {"seed": SEED, "wall_s": round(time.time() - t0, 1), "results": res}
    (RESULTS / "f03b_crossver.json").write_text(json.dumps(out, indent=1) + "\n")
    print(f"süre {out['wall_s']} s")




# ---------------------------------------------------------------- tekrar (belirlenimcilik) testi
def repeat_check(wave: str = "v1-E1", n_scan: int = 1500, reps: int = 5, snr: float = 20.0) -> dict:
    """v0 alıcısının (enerji) v1 çerçevesinde ürettiği CRC'li sahte çözüm aynı yük tekrar
    gönderildiğinde (yeni gürültü) yine aynı id ile çıkıyor mu? Çıkıyorsa iki çerçeve kuralı korumaz.

        research/.venv/bin/python research/sim/run_f03b_crossver.py --repeat
    """
    p = WAVES[wave]
    rng = np.random.default_rng([SEED, 99])
    payloads = []
    for _ in range(n_scan):
        x, d = make_frame(wave, rng)
        payloads.append((x, d))
    e_ref = np.mean([inband_energy(x, p.rx_band) / p.on_len for x, _ in payloads[:50]])
    sigma = np.sqrt(e_ref / (10 ** (snr / 10) * p.rx_bandwidth / (p.fs / 2)))

    def run(xs):
        y = np.zeros(len(xs) * SLOT + SLOT)
        for k, x in enumerate(xs):
            y[k * SLOT + 24_000 : k * SLOT + 24_000 + x.size] = x
        y = y + sigma * rng.standard_normal(y.size)
        rx = StreamingReceiver(ReceiverConfig(params=V0, eta_c=22.25))
        ev = []
        for i in range(0, y.size, BLOCK):
            ev += rx.process(y[i : i + BLOCK])
        ev += rx.flush()
        return [(int(e.start // SLOT), e.fields.id) for e in ev if e.valid]

    hits = run([x for x, _ in payloads])
    slots = sorted({k for k, _ in hits})
    again = []
    for k in slots:
        ids0 = {i for kk, i in hits if kk == k}
        res = run([payloads[k][0]] * reps)
        again.append({"slot": k, "ids": sorted(ids0), "repeat_same_id": sum(1 for _, i in res if i in ids0), "reps": reps})
    return {"wave": wave, "snr_ib_db": snr, "n_scan": n_scan, "valid_false": len(hits), "repeat": again}


if __name__ == "__main__":
    import sys

    if "--repeat" in sys.argv:
        with Pool(2) as pool:
            rr = pool.map(repeat_check, ["v1-E1", "v1-E3"])
        for r in rr:
            print(r["wave"], r["valid_false"], [(a["repeat_same_id"], a["reps"]) for a in r["repeat"]])
        (RESULTS / "f03b_crossver_repeat.json").write_text(json.dumps(rr, indent=1) + "\n")
    else:
        main()
