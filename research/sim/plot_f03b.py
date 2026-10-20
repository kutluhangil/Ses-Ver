"""F0-3b: eşik SNR'ları, özet JSON ve grafikler.

    research/.venv/bin/python research/sim/plot_f03b.py
Girdi: results/f03b_pdfer.json · Çıktı: results/f03b_summary.json, reports/figs/f03b_*.png

Eksenler (F0-3 §2): SNR_ib (alıcıda), SNR_wb = SNR_ib + 10 log10(W/24 kHz), E/N0 = SNR_ib + 10 log10(W·Ton).
Sabit hoparlör genliği ve aynı beyaz gürültü yoğunluğunda adaylar arasında adil eksen SNR_wb'dir
(aynı A -> aynı işaret gücü; bant ve Ton farkı kendiliğinden hesaba girer). Moloz kanallarında
kaynak SNR_wb (moloz öncesi) de verilir.
"""

from __future__ import annotations

import json

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

from common import FIGS, RESULTS, wilson  # noqa: E402
from plot_report import INK, SLOT, crossing  # noqa: E402  (aynı stil)

CH_LABEL = {"awgn": "AWGN", "mp03": "RT60 0,3 s, DRR 0", "mp08h": "RT60 0,8 s, DRR −6",
            "rub1": "Moloz R1", "rub2": "Moloz R2", "rub3": "Moloz R3"}


def thr(x, k, n, level, kind):
    """kind 'pd': oran k/n'nin `level`i geçtiği SNR; 'fer': 1 - k/n'nin `level`e indiği SNR."""
    k = np.asarray(k)
    ci = [wilson(int(v), n) for v in k]
    if kind == "pd":
        y, ylo, yhi = k / n, [c[0] for c in ci], [c[1] for c in ci]
        return crossing(x, y, level), crossing(x, yhi, level), crossing(x, ylo, level)
    y, ylo, yhi = 1 - k / n, [1 - c[1] for c in ci], [1 - c[0] for c in ci]
    return crossing(x, y, level), crossing(x, ylo, level), crossing(x, yhi, level)


def r1(v):
    return None if v is None or not np.isfinite(v) else round(float(v), 1)


def summarize(c) -> dict:
    n = c["n"]
    x = np.asarray(c["snr_rx_db"])
    W, ton = c["rx_bw_hz"], c["ton_s"]
    wb = 10 * np.log10(W / 24_000)
    en0 = 10 * np.log10(W * ton)
    L = c["rubble_loss_ib_db"]
    out = {"wave": c["wave"], "channel": c["channel"], "n": n, "rubble_loss_ib_db": round(L, 2),
           "wb_offset_db": round(wb, 2), "en0_offset_db": round(en0, 2)}
    t = thr(x, c["det"], n, 0.9, "pd")
    out["pd09_rx"] = [r1(v) for v in t]
    dec = sorted({k.split("|")[0] for k in c if "|" in k})
    out["fer01_rx"] = {}
    for d in dec:
        out["fer01_rx"][d] = [r1(v) for v in thr(x, c[f"{d}|cor"], n, 0.1, "fer")]
        if c["two"]:
            out["fer01_rx"][d + "+sel"] = [r1(v) for v in thr(x, c[f"{d}|sel"], n, 0.1, "fer")]
            out["fer01_rx"][d + "+E4"] = [r1(v) for v in thr(x, c[f"{d}|e4"], n, 0.1, "fer")]
        # yanlış kabul / (tespit edilip doğru çözülmeyen deneme)
        det = np.asarray(c["det"])
        cor = np.asarray(c[f"{d}|cor"])
        out.setdefault("wrong_accept", {})[d] = {"wrong": int(np.sum(c[f"{d}|wrong"])),
                                                 "det_not_correct": int(np.sum(np.maximum(det - cor, 0)))}
    return out


def fig_fer(curves, chans, fname, title):
    fig, axs = plt.subplots(1, len(chans), figsize=(4.0 * len(chans), 3.4), sharey=True)
    series = [("v0", "en", "v0 (enerji)", SLOT[0], ":"), ("v0", "coh", "v0 + E0", SLOT[0], "-"),
              ("v0", "coh|e4", "v0 + E0 + E4", SLOT[0], "--"),
              ("v1-E1", "rs_t2s", "B1+E1 (t2s)", SLOT[1], "-"), ("v1-E1", "rs_t1", "B1+E1 (t1)", SLOT[1], ":"),
              ("v1-E3", "coh", "B1+E3", SLOT[2], "-"), ("v1-E3", "coh|e4", "B1+E3 + E4", SLOT[2], "--")]
    for ax, ch in zip(axs, chans):
        for wave, key, lab, col, ls in series:
            cs = [c for c in curves if c["wave"] == wave and c["channel"] == ch]
            if not cs:
                continue
            c = cs[0]
            k = c[key] if "|" in key else c[f"{key}|cor"]
            xw = np.asarray(c["snr_rx_db"]) + 10 * np.log10(c["rx_bw_hz"] / 24_000)
            if c["snr_ref_kind"] == "src":
                xw = xw + c["rubble_loss_ib_db"]
            ax.semilogy(xw, np.maximum(1 - np.asarray(k) / c["n"], 1e-3), ls, color=col, label=lab)
        ax.axhline(0.1, color=INK, lw=0.6)
        ax.set_title(CH_LABEL[ch])
        ax.set_xlabel("kaynak SNR_wb (dB)" if ch.startswith("rub") else "SNR_wb (dB)")
        ax.set_ylim(1e-3, 1.05)
    axs[0].set_ylabel("FER")
    axs[-1].legend(fontsize=7, loc="lower left")
    fig.suptitle(title)
    fig.tight_layout()
    fig.savefig(FIGS / fname, dpi=130)
    plt.close(fig)


def main() -> None:
    d = json.loads((RESULTS / "f03b_pdfer.json").read_text())
    curves = d["curves"]
    summ = [summarize(c) for c in curves]
    (RESULTS / "f03b_summary.json").write_text(json.dumps({"trials_per_point": d["trials_per_point"],
                                                          "wall_s": d["wall_s"], "rows": summ}, indent=1) + "\n")
    fig_fer(curves, ["awgn", "mp03", "mp08h"], "f03b_fer_awgn_multipath.png",
            "F0-3b: FER, aynı hoparlör düzeyi ekseni (SNR_wb)")
    fig_fer(curves, ["rub1", "rub2", "rub3"], "f03b_fer_rubble.png", "F0-3b: FER, moloz (kaynak SNR_wb) [Tahmin modeli]")
    for s in summ:
        print(s["wave"], s["channel"], "Pd", s["pd09_rx"][0], {k: v[0] for k, v in s["fer01_rx"].items()})


if __name__ == "__main__":
    main()
