"""İşleme kazancı: eşlenik filtre kazancı ve 3 chirp birleştirme kazancı (ölçüm + teori).

    research/.venv/bin/python research/sim/run_gain.py
Çıktı: research/sim/results/gain.json

A) Eşlenik filtre kazancı (deterministik + Monte Carlo doğrulama)
   SNR_in,B  = (giriş chirp'inin ortalama gücü, 120 ms üzerinden) / (B bandındaki gürültü gücü)
   SNR_out   = |y_tepe|² / E|y_gürültü|²  (alıcının gerçek çekirdeği: bant geçiren ⊛ analitik chirp)
   Kazanç_B  = SNR_out / SNR_in,B. Teori: B·Tp (v0: 288 → 24,6 dB).
   Not: karmaşık (zarf) eşlenik filtre çıkışı faz bilinmediği için E/(2σ²) verir; teori bu tanımla B·Tp'dir.

B) Üç chirp birleştirme (tepe düzeyinde Pd)
   Alıcı gerçek gürültü + çerçeve üzerinde çalıştırılır; gerçek tepe konumunda
   tek chirp istatistiği Pn(U1) ve birleşik C okunur. Eşikler beyaz gürültüde aynı
   ön tespit oranına (10/saat) kalibre edilmiş eşiklerdir (thresholds.json).
   Ölçülen kazanç = SNR_gerekli(tek, Pd=0,9) − SNR_gerekli(üçlü, Pd=0,9).
   Teori: Pn ~ Exp(1) (H0); H1'de 2·Pn ~ χ'²(2, 2ρ); 2·C ~ χ'²(6, 6ρ).
"""

from __future__ import annotations

import os

for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_v, "1")

import json
import time
from multiprocessing import Pool

import numpy as np
from scipy import optimize, stats

from common import RESULTS, VARIANTS, inband_energy, load_thresholds, pack, random_fields, rx_config
from sesver_signal import StreamingReceiver, frame_from_word
from sesver_signal.waveform import up_chirp

SEED = 51_003
TRIALS = 400
CHUNK = 25
GRID = np.arange(-26.0, -9.0, 1.0)


class _KeepAll(StreamingReceiver):
    def _trim(self) -> None:  # deney için tampon kırpma yok
        pass


def mf_gain(variant: str, mc: int = 3000) -> dict:
    p = VARIANTS[variant]
    rx = StreamingReceiver(rx_config(variant))
    g = np.convolve(rx.up_t, rx.h_bp)
    x = up_chirp(p)
    pad = np.zeros(x.size + 2 * g.size)
    o = g.size
    pad[o : o + x.size] = x
    n_pk = o - rx.hl
    ys = np.vdot(g, pad[n_pk : n_pk + g.size])
    noise_var_unit = float(np.sum(np.abs(g) ** 2))
    p_in = float(np.sum(x**2) / p.n_pre)
    out = {}
    for band_name, bw in (("B", p.bandwidth), ("W_rx", p.rx_bandwidth)):
        snr_in = p_in / (bw / (p.fs / 2))  # σ² = 1
        snr_out = abs(ys) ** 2 / noise_var_unit
        out[f"gain_{band_name}_db"] = 10 * np.log10(snr_out / snr_in)
        out[f"theory_{band_name}_db"] = 10 * np.log10(bw * p.tp)
    # MC doğrulama: boyutsuz çıkış gürültü varyansı
    rng = np.random.default_rng(SEED)
    vals = np.empty(mc)
    for i in range(mc):
        nz = rng.standard_normal(g.size)
        vals[i] = abs(np.vdot(g, nz)) ** 2
    out["mc_noise_var_ratio"] = float(vals.mean() / noise_var_unit)
    out["window_energy_loss_db"] = 10 * np.log10(np.sum(x**2) / (p.amplitude**2 / 2 * p.n_pre))
    # SNR_ib (çerçeve tanımı) -> tepe başına çıkış SNR'ı katsayısı K: rho = K * SNR_ib
    fr = frame_from_word(0x7F2674D7, p)
    e_ib = inband_energy(np.concatenate([np.zeros(4800), fr, np.zeros(4800)]), p.rx_band) / p.on_len
    sigma2_at_0db = e_ib / (p.rx_bandwidth / (p.fs / 2))
    out["K_db"] = 10 * np.log10(abs(ys) ** 2 / (sigma2_at_0db * noise_var_unit))
    return out


def _trial_chunk(args):
    variant, chunk, eta1, eta3, eta_min = args
    p = VARIANTS[variant]
    cfg = rx_config(variant)
    rng = np.random.default_rng([SEED, chunk, 0 if variant == "v0" else 1])
    G = GRID.size
    d1 = np.zeros(G, int)
    d3 = np.zeros(G, int)
    pk = np.zeros(G)
    W = p.rx_bandwidth
    for _ in range(CHUNK):
        x = frame_from_word(pack(random_fields(rng)), p)
        lead = int(rng.integers(14_400, 19_200))
        s = np.zeros(lead + x.size + 30_000)
        s[lead : lead + x.size] = x
        e = inband_energy(s, p.rx_band) / p.on_len
        nz = rng.standard_normal(s.size)
        for gi, snr in enumerate(GRID):
            rx = _KeepAll(cfg)
            rx.process(s + np.sqrt(e / (10 ** (snr / 10) * W / (p.fs / 2))) * nz)
            n0 = lead - rx.hl
            r = cfg.pool_radius
            pn1 = float(np.max(rx.Pn.get(n0 - r, n0 + r + 1)))
            c3 = rx.C.get(n0 - r, n0 + r + 1)
            m3 = rx.minpk.get(n0 - r, n0 + r + 1)
            ok3 = np.any((c3 >= eta3) & (m3 >= eta_min))
            d1[gi] += pn1 >= eta1
            d3[gi] += bool(ok3)
            pk[gi] += pn1
    return variant, d1, d3, pk


def theory_required_rho(eta: float, k: int, pd: float = 0.9) -> float:
    """2·S ~ χ'²(2k, 2kρ) için P(S ≥ eta) = pd veren ρ (doğrusal)."""
    f = lambda lr: stats.ncx2.sf(2 * eta, 2 * k, 2 * k * np.exp(lr)) - pd  # noqa: E731
    return float(np.exp(optimize.brentq(f, np.log(1e-3), np.log(1e4))))


def crossing(x: np.ndarray, y: np.ndarray, level: float) -> float:
    for i in range(1, x.size):
        if (y[i - 1] - level) * (y[i] - level) <= 0 and y[i] != y[i - 1]:
            return float(x[i - 1] + (level - y[i - 1]) * (x[i] - x[i - 1]) / (y[i] - y[i - 1]))
    return float("nan")


def main() -> None:
    t0 = time.time()
    th = load_thresholds()
    out = {"seed": SEED, "trials": TRIALS, "grid_snr_ib_db": GRID.tolist(), "variants": {}}
    tasks = []
    for v in ("v0", "v0-L"):
        eta1 = th[f"{v}/n_up=1"]["eta_c"]
        eta3 = th[f"{v}/n_up=3"]["eta_c"]
        tasks += [(v, k, eta1, eta3, rx_config(v).eta_min) for k in range(TRIALS // CHUNK)]
    acc = {v: [np.zeros(GRID.size, int), np.zeros(GRID.size, int), np.zeros(GRID.size)] for v in ("v0", "v0-L")}
    with Pool() as pool:
        for v, d1, d3, pk in pool.imap_unordered(_trial_chunk, tasks):
            acc[v][0] += d1
            acc[v][1] += d3
            acc[v][2] += pk
    for v in ("v0", "v0-L"):
        mf = mf_gain(v)
        eta1 = th[f"{v}/n_up=1"]["eta_c"]
        eta3 = th[f"{v}/n_up=3"]["eta_c"]
        pd1 = acc[v][0] / TRIALS
        pd3 = acc[v][1] / TRIALS
        s1 = crossing(GRID, pd1, 0.9)
        s3 = crossing(GRID, pd3, 0.9)
        rho1 = theory_required_rho(eta1, 1)
        rho3 = theory_required_rho(eta3, 3)
        # ideal ders kitabı: aynı hücre başı Pfa
        pfa = float(np.exp(-eta1))
        eta3_ideal = float(stats.gamma.isf(pfa, 3))
        rho3_ideal = theory_required_rho(eta3_ideal, 3)
        K = mf["K_db"]
        out["variants"][v] = {
            "mf": mf,
            "eta1": eta1, "eta3": eta3,
            "pd_single": pd1.tolist(), "pd_triple": pd3.tolist(),
            "mean_pn_u1": (acc[v][2] / TRIALS).tolist(),
            "snr_req_pd09_single_db": s1, "snr_req_pd09_triple_db": s3,
            "measured_combining_gain_db": s1 - s3,
            "theory_snr_req_single_db": 10 * np.log10(rho1) - K,
            "theory_snr_req_triple_db": 10 * np.log10(rho3) - K,
            "theory_combining_gain_db_calibrated_eta": 10 * np.log10(rho1 / rho3),
            "theory_combining_gain_db_equal_pfa_cell": 10 * np.log10(rho1 / rho3_ideal),
            "coherent_upper_bound_db": 10 * np.log10(3),
        }
        print(v, json.dumps({k: (round(x, 2) if isinstance(x, float) else x) for k, x in out["variants"][v].items()
                             if k not in ("pd_single", "pd_triple", "mean_pn_u1")}, default=str))
    out["wall_s"] = round(time.time() - t0, 1)
    (RESULTS / "gain.json").write_text(json.dumps(out, indent=1) + "\n")
    print(f"süre {out['wall_s']} s")


if __name__ == "__main__":
    main()
