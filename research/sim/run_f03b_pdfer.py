"""F0-3b Monte Carlo: ADR-0004 adaylarının Pd / FER eğrileri (F0-3 ile aynı kanal ve SNR tanımı).

    research/.venv/bin/python research/sim/run_f03b_pdfer.py [--trials 100] [--only awgn,mp03]
Çıktı: research/sim/results/f03b_pdfer.json

F0-3 `run_pd_fer.py` düzeni aynen: [0,30-0,40 s gürültü][çerçeve (+RIR)][0,5 s gürültü], ortak
rastgele sayılar, tespit = ±100 örnekte aday, SNR_ib = bant içi işaret enerjisi / Ton.
Farklar:
  * Alıcı `V1Receiver`: v0 tespit hattı aynı; çözme yumuşak metrik döndürür, böylece aynı
    tespit üzerinde birden çok karar kuralı (enerji / tutarlı E0 / RS t=0,1,2 / E4) ölçülür.
  * Akış sonunda flush yok (gerçek çerçevenin tespiti ve çözümü flush'sız tamamlanır; yalnız
    kuyruktaki sahte adaylar sayılmaz).
  * E4 için her denemede aynı kanal gerçekleşmesine ikinci bağımsız gürültü eklenir (aynı
    işaretin ikinci çerçevesi). E4 = kare1 doğru VEYA kare2 doğru VEYA metrik toplamı doğru.
    "sel" = kare1 VEYA kare2 (birleştirmesiz, yalnız beklemek).
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

from common import CHANNELS, RESULTS, apply_rubble, inband_energy, pack, random_fields, stochastic_rir
from sesver_signal import V0, V0L, ReceiverConfig, frame_from_word
from sesver_signal.v1 import CODING, V1_E1, V1_E1E3, V1_E1S, V1_E3, FieldsP1, V1Receiver, decode_metrics, frame_v1, pack_p1

SEED = 41_102
CHUNK = 10
WAVES = {p.name: p for p in (V0, V0L, V1_E1, V1_E3, V1_E1E3, V1_E1S)}
ETA = {"v0": 22.25}  # results/thresholds.json (F0-3); B1 bandı: 22,3 (v0-L)
# alıcıdaki SNR_ib aralığı (dB), F0-3 eşiklerinin −2…+2 dB çevresi
RX_RANGE = {
    "B0": {"awgn": (-18, -9), "mp03": (-15, -5), "mp08h": (-11, 0), "rub1": (-14, -5), "rub2": (-14, -4), "rub3": (-12, -2)},
    "B1": {"awgn": (-17, -8), "mp03": (-14, -4), "mp08h": (-10, 1), "rub1": (-14, -4), "rub2": (-13, -3), "rub3": (-12, -2)},
}
MAIN_CH = ("awgn", "mp03", "mp08h", "rub1", "rub2", "rub3")


def curves(only=None) -> list[dict]:
    cs = []
    for w in ("v0", "v1-E1", "v1-E3"):
        for ch in MAIN_CH:
            cs.append({"wave": w, "channel": ch, "two": True})
    for w, chs in (("v0-L", ("awgn", "mp03")), ("v1-E1E3", ("awgn",)), ("v1-E1s", ("awgn", "mp03"))):
        for ch in chs:
            cs.append({"wave": w, "channel": ch, "two": False})
    return [c for c in cs if only is None or c["channel"] in only]


def decoders(wave: str) -> dict:
    """ad -> (metrik türü, kodlama, t_max, soft_rank)"""
    cod = CODING[wave]
    if cod == "rs":
        return {"rs_t0": ("coh", cod, 0, None), "rs_t1": ("coh", cod, 1, None),
                "rs_t2": ("coh", cod, 2, None), "rs_t2s": ("coh", cod, 2, 2)}
    if wave in ("v0", "v0-L"):
        return {"en": ("en", cod, 0, None), "coh": ("coh", cod, 0, None)}
    return {"coh": ("coh", cod, 0, None)}


def band(p) -> str:
    return "B0" if p.f_low == 1_800.0 else "B1"


def make_frame(wave: str, rng):
    p = WAVES[wave]
    if CODING[wave] == "crc_v0":
        w = pack(random_fields(rng))
        return frame_from_word(w, p), w
    while True:
        fid = int(rng.integers(1, 0xFFF))
        break
    d = pack_p1(FieldsP1(id=fid, people=int(rng.integers(0, 8)), injured=int(rng.integers(0, 2)),
                         life_age=int(rng.integers(0, 16)), battery=int(rng.integers(0, 4)), mode=int(rng.integers(0, 4))))
    return frame_v1(d, p), d


def rubble_loss_estimate(wave: str, ch_name: str) -> float:
    ch = CHANNELS[ch_name]
    if not ch.is_rubble:
        return 0.0
    p = WAVES[wave]
    x, _ = make_frame(wave, np.random.default_rng(0))
    x = np.concatenate([np.zeros(4800), x, np.zeros(4800)])
    return 10 * np.log10(inband_energy(x, p.rx_band) / inband_energy(apply_rubble(x, ch.rubble_l1k_db, ch.rubble_beta), p.rx_band))


def grid(c: dict) -> np.ndarray:
    p = WAVES[c["wave"]]
    lo, hi = RX_RANGE[band(p)][c["channel"]]
    L = round(rubble_loss_estimate(c["wave"], c["channel"]))
    return np.arange(lo + L, hi + L + 1, 1.0)


def _run(rx_cfg, p, sig):
    rx = V1Receiver(rx_cfg)
    return rx.process(sig)


def _task(args):
    ci, c, chunk, snr_grid = args
    wave = c["wave"]
    p = WAVES[wave]
    ch = CHANNELS[c["channel"]]
    cfg = ReceiverConfig(params=p, eta_c=ETA.get(wave, 22.3))
    decs = decoders(wave)
    rng = np.random.default_rng(np.random.SeedSequence([SEED, ci, chunk]))
    G = len(snr_grid)
    names = list(decs)
    z = lambda: np.zeros(G, int)  # noqa: E731
    acc = {"det": z(), "det2": z(), "lib": []}
    for k in names:
        for m in ("cor", "wrong", "sel", "e4", "wrong_e4"):
            acc[f"{k}|{m}"] = z()
    W = p.rx_bandwidth
    for _ in range(CHUNK):
        x, truth = make_frame(wave, rng)
        if ch.rt60 is not None:
            x = sps.fftconvolve(x, stochastic_rir(ch.rt60, ch.drr_db, rng))
        lead = int(rng.integers(14_400, 19_200))
        s = np.zeros(lead + x.size + 24_000)
        s[lead : lead + x.size] = x
        e_src = inband_energy(s, p.rx_band) / p.on_len
        if ch.is_rubble:
            s = apply_rubble(s, ch.rubble_l1k_db, ch.rubble_beta)
        acc["lib"].append(10 * np.log10(e_src / (inband_energy(s, p.rx_band) / p.on_len)))
        nzs = [rng.standard_normal(s.size) for _ in range(2 if c["two"] else 1)]
        for gi, snr in enumerate(snr_grid):
            sigma = np.sqrt(e_src / (10 ** (snr / 10) * W / (p.fs / 2)))
            evs = [_run(cfg, p, s + sigma * nz) for nz in nzs]
            nears = []
            for ev in evs:
                nr = [e for e in ev if abs(e.start - lead) <= 100]
                nears.append(max(nr, key=lambda e: e.metric_c) if nr else None)
            acc["det"][gi] += nears[0] is not None
            if c["two"]:
                acc["det2"][gi] += nears[1] is not None
            for k, (mt, cod, t, sr) in decs.items():
                def dec(E):
                    return decode_metrics(E, cod, t, sr)

                def met(e):
                    return (e.e_coh if mt == "coh" else e.e_en)[p.name]

                res = []  # (doğru mu, yanlış kabul sayısı) her kare için
                for ev in evs:
                    good, wrong = False, 0
                    for e in ev:
                        d = dec(met(e))
                        if d.ok:
                            if d.data == truth:
                                good = True
                            else:
                                wrong += 1
                    res.append((good, wrong))
                acc[f"{k}|cor"][gi] += res[0][0]
                acc[f"{k}|wrong"][gi] += res[0][1]
                if c["two"]:
                    sel = res[0][0] or res[1][0]
                    wr = res[0][1] + res[1][1]
                    comb = False
                    if nears[0] is not None and nears[1] is not None:
                        d = dec(met(nears[0]) + met(nears[1]))
                        if d.ok:
                            comb = d.data == truth
                            wr += d.data != truth
                    acc[f"{k}|sel"][gi] += sel
                    acc[f"{k}|e4"][gi] += sel or comb
                    acc[f"{k}|wrong_e4"][gi] += wr
    return ci, acc


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--trials", type=int, default=100)
    ap.add_argument("--only", default=None, help="kanal listesi, virgülle")
    ap.add_argument("--out", default="f03b_pdfer.json")
    a = ap.parse_args()
    cs = curves(a.only.split(",") if a.only else None)
    n_chunks = a.trials // CHUNK
    grids = [grid(c) for c in cs]
    # pahalı (iki kareli, uzun ızgaralı) görevler önce
    tasks = [(ci, c, k, grids[ci]) for ci, c in enumerate(cs) for k in range(n_chunks)]
    tasks.sort(key=lambda t: -(len(t[3]) * (2 if t[1]["two"] else 1)))
    t0 = time.time()
    acc: dict[int, dict] = {}
    with Pool() as pool:
        for ci, r in pool.imap_unordered(_task, tasks, chunksize=1):
            if ci not in acc:
                acc[ci] = r
            else:
                for k, v in r.items():
                    acc[ci][k] = acc[ci][k] + v
    out = {"seed": SEED, "trials_per_point": n_chunks * CHUNK, "wall_s": round(time.time() - t0, 1), "curves": []}
    for ci, c in enumerate(cs):
        r = acc[ci]
        L = float(np.mean(r.pop("lib")))
        g = grids[ci]
        out["curves"].append({**c, "n": n_chunks * CHUNK, "snr_ref_db": g.tolist(),
                              "snr_ref_kind": "src" if CHANNELS[c["channel"]].is_rubble else "rx",
                              "rubble_loss_ib_db": L, "snr_rx_db": (g - L).tolist(),
                              "ton_s": WAVES[c["wave"]].on_len / 48_000, "rx_bw_hz": WAVES[c["wave"]].rx_bandwidth,
                              **{k: v.tolist() for k, v in r.items()}})
    RESULTS.mkdir(parents=True, exist_ok=True)
    (RESULTS / a.out).write_text(json.dumps(out) + "\n")
    print(f"{len(tasks)} görev, {time.time() - t0:.1f} s -> {RESULTS / a.out}")


if __name__ == "__main__":
    main()
