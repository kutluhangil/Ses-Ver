"""Monte Carlo: SNR'a karşı tespit olasılığı (Pd) ve çerçeve hata oranı (FER).

    research/.venv/bin/python research/sim/run_pd_fer.py [--trials 240] [--quick]
Çıktı: research/sim/results/pdfer.json

Deneme düzeni: [0,30-0,40 s gürültü][çerçeve (+ RIR kuyruğu)][0,5 s gürültü], ardından
alıcı akışı sıfırlarla boşaltılır (flush). Her denemede yük, ofset, RIR ve birim
gürültü bir kez çekilir; aynı gerçekleşme tüm SNR noktalarında ölçeklenerek
kullanılır (ortak rastgele sayılar: eğriler düzgün, her nokta yine bağımsız
denemelerden oluşur).

Tespit (Pd): başlangıcı gerçek çerçeve başlangıcının ±100 örneğinde olan herhangi
bir aday (CRC öncesi). Doğru çözüm: CRC geçen ve W'si gönderilenle aynı olan olay.
FER = 1 − P(doğru çözüm) (kaçırılan tespitler dahil). "Yanlış kabul": CRC geçen ama
W'si farklı olay.
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
from scipy import signal as sps

from common import (CHANNELS, RESULTS, VARIANTS, apply_rubble, frame_from_word, inband_energy, pack,
                    random_fields, rx_config, stochastic_rir)
from sesver_signal import decode_buffer

SEED = 41_002
CHUNK = 20
RX_RANGE = {  # alıcıdaki SNR_ib aralığı (dB); moloz kanallarında kaynak ızgarası buna L_ib eklenerek kurulur
    "awgn": (-22, -6), "mp03": (-22, -2), "mp08": (-22, 2), "mp08h": (-20, 6),
    "rub1": (-20, 2), "rub2": (-20, 2), "rub3": (-20, 2),
}


def curves() -> list[dict]:
    cs = []
    for v in ("v0", "v0-L"):
        for ch in CHANNELS:
            cs.append({"variant": v, "channel": ch, "n_up": 3, "css_mode": "energy"})
    # Tek chirp (n_up=1) karşılaştırması run_gain.py'de, tepe düzeyinde yapılır.
    for ch in ("awgn", "mp08"):
        cs.append({"variant": "v0", "channel": ch, "n_up": 3, "css_mode": "coherent"})
    return cs


def curve_id(c: dict) -> str:
    return f"{c['variant']}|{c['channel']}|n_up={c['n_up']}|{c['css_mode']}"


def rubble_loss_estimate(variant: str, ch_name: str) -> float:
    ch = CHANNELS[ch_name]
    if not ch.is_rubble:
        return 0.0
    p = VARIANTS[variant]
    x = np.concatenate([np.zeros(4800), frame_from_word(0x7F2674D7, p), np.zeros(4800)])
    e0 = inband_energy(x, p.rx_band)
    e1 = inband_energy(apply_rubble(x, ch.rubble_l1k_db, ch.rubble_beta), p.rx_band)
    return 10 * np.log10(e0 / e1)


def grid(c: dict) -> np.ndarray:
    lo, hi = RX_RANGE[c["channel"]]
    L = round(rubble_loss_estimate(c["variant"], c["channel"]))
    return np.arange(lo + L, hi + L + 1, 1.0)


def _task(args):
    ci, c, chunk, snr_grid = args
    p = VARIANTS[c["variant"]]
    ch = CHANNELS[c["channel"]]
    cfg = rx_config(c["variant"], c["n_up"], c["css_mode"])
    ss = np.random.SeedSequence([SEED, ci, chunk])
    rng = np.random.default_rng(ss)
    G = len(snr_grid)
    det = np.zeros(G, int)
    cor = np.zeros(G, int)
    wrong = np.zeros(G, int)
    lib = []
    terr = []
    W = p.rx_bandwidth
    for _ in range(CHUNK):
        f = random_fields(rng)
        w = pack(f)
        x = frame_from_word(w, p)
        if ch.rt60 is not None:
            x = sps.fftconvolve(x, stochastic_rir(ch.rt60, ch.drr_db, rng))
        lead = int(rng.integers(14_400, 19_200))
        s = np.zeros(lead + x.size + 24_000)
        s[lead : lead + x.size] = x
        e_src = inband_energy(s, p.rx_band) / p.on_len
        if ch.is_rubble:
            s = apply_rubble(s, ch.rubble_l1k_db, ch.rubble_beta)
        e_rx = inband_energy(s, p.rx_band) / p.on_len
        lib.append(10 * np.log10(e_src / e_rx))
        nz = rng.standard_normal(s.size)
        for gi, snr in enumerate(snr_grid):
            sigma = np.sqrt(e_src / (10 ** (snr / 10) * W / (p.fs / 2)))
            ev = decode_buffer(s + sigma * nz, cfg)
            near = [e for e in ev if abs(e.start - lead) <= 100]
            if near:
                det[gi] += 1
                terr.append((gi, min(abs(e.start - lead) for e in near)))
            if any(e.crc_ok and e.word == w for e in ev):
                cor[gi] += 1
            wrong[gi] += sum(1 for e in ev if e.crc_ok and e.word != w)
    return ci, det, cor, wrong, lib, terr


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--trials", type=int, default=200)
    ap.add_argument("--quick", action="store_true", help="hızlı duman testi (40 deneme)")
    a = ap.parse_args()
    trials = 40 if a.quick else a.trials
    n_chunks = trials // CHUNK
    cs = curves()
    grids = [grid(c) for c in cs]
    tasks = [(ci, c, k, grids[ci]) for ci, c in enumerate(cs) for k in range(n_chunks)]
    t0 = time.time()
    acc = {ci: {"det": 0, "cor": 0, "wrong": 0, "lib": [], "terr": []} for ci in range(len(cs))}
    with Pool() as pool:
        for ci, det, cor, wrong, lib, terr in pool.imap_unordered(_task, tasks, chunksize=1):
            r = acc[ci]
            r["det"] = r["det"] + det
            r["cor"] = r["cor"] + cor
            r["wrong"] = r["wrong"] + wrong
            r["lib"] += lib
            r["terr"] += terr
    out = {"seed": SEED, "trials_per_point": n_chunks * CHUNK, "wall_s": round(time.time() - t0, 1), "curves": []}
    for ci, c in enumerate(cs):
        r = acc[ci]
        L = float(np.mean(r["lib"]))
        g = grids[ci]
        te = np.zeros(len(g))
        for gi in range(len(g)):
            v = [e for k, e in r["terr"] if k == gi]
            te[gi] = float(np.sqrt(np.mean(np.square(v)))) if v else float("nan")
        out["curves"].append({
            **c, "id": curve_id(c), "n": n_chunks * CHUNK,
            "snr_ref_db": g.tolist(), "snr_ref_kind": "src" if CHANNELS[c["channel"]].is_rubble else "rx",
            "rubble_loss_ib_db": L, "snr_rx_db": (g - L).tolist(),
            "det": r["det"].tolist(), "cor": r["cor"].tolist(), "wrong": r["wrong"].tolist(),
            "timing_rms_samples": te.tolist(),
        })
    RESULTS.mkdir(parents=True, exist_ok=True)
    name = "pdfer_quick.json" if a.quick else "pdfer.json"
    (RESULTS / name).write_text(json.dumps(out, indent=1) + "\n")
    print(f"{len(tasks)} görev, {time.time() - t0:.1f} s -> {RESULTS / name}")


if __name__ == "__main__":
    main()
