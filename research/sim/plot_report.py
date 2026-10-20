"""Sonuç JSON'larından grafikler ve özet tablo üretir.

    research/.venv/bin/python research/sim/plot_report.py
Girdi: research/sim/results/{pdfer,gain,false_alarm,cpu,thresholds}.json
Çıktı: research/sim/reports/figs/*.png, research/sim/results/summary.json
"""

from __future__ import annotations

import json

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

from common import CHANNELS, FIGS, RESULTS, VARIANTS, rubble_gain, snr_conversions, wilson  # noqa: E402

# Doğrulanmış varsayılan kategorik palet (açık mod), sabit sıra.
SLOT = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300"]
INK, INK2, GRID = "#0b0b0b", "#52514e", "#e4e3df"
VSTYLE = {"v0": "-", "v0-L": "--"}

plt.rcParams.update({
    "figure.facecolor": "#fcfcfb", "axes.facecolor": "#fcfcfb", "axes.edgecolor": INK2,
    "axes.labelcolor": INK, "xtick.color": INK2, "ytick.color": INK2, "axes.grid": True,
    "grid.color": GRID, "grid.linewidth": 0.8, "lines.linewidth": 2.0, "font.size": 9,
    "axes.spines.top": False, "axes.spines.right": False, "legend.frameon": False,
})


def crossing(x, y, level):
    x, y = np.asarray(x, float), np.asarray(y, float)
    for i in range(1, x.size):
        if (y[i - 1] - level) * (y[i] - level) <= 0 and y[i] != y[i - 1]:
            return float(x[i - 1] + (level - y[i - 1]) * (x[i] - x[i - 1]) / (y[i] - y[i - 1]))
    return float("nan")


def curve_stats(c):
    n = c["n"]
    det, cor = np.array(c["det"]), np.array(c["cor"])
    pd = det / n
    fer = 1 - cor / n
    pd_ci = np.array([wilson(int(k), n) for k in det])
    succ_ci = np.array([wilson(int(k), n) for k in cor])
    fer_ci = np.stack([1 - succ_ci[:, 1], 1 - succ_ci[:, 0]], axis=1)
    x = np.array(c["snr_rx_db"])
    xs = np.array(c["snr_ref_db"])
    out = {"pd": pd, "fer": fer, "pd_ci": pd_ci, "fer_ci": fer_ci, "x": x, "xsrc": xs}
    # gerekli SNR ve %95 aralığı (Wilson sınır eğrilerinin kesişimi)
    out["pd09"] = crossing(x, pd, 0.9)
    out["pd09_ci"] = (crossing(x, pd_ci[:, 1], 0.9), crossing(x, pd_ci[:, 0], 0.9))
    out["fer01"] = crossing(x, fer, 0.1)
    out["fer01_ci"] = (crossing(x, fer_ci[:, 0], 0.1), crossing(x, fer_ci[:, 1], 0.1))
    out["pd09_src"] = crossing(xs, pd, 0.9)
    out["fer01_src"] = crossing(xs, fer, 0.1)
    und = int(np.sum(det - np.minimum(cor, det)))
    out["wrong_total"] = int(np.sum(c["wrong"]))
    out["undecoded_detections"] = und
    return out


def en0(variant, snr_ib):
    return snr_conversions(snr_ib, VARIANTS[variant])["e_n0_db"]


def fig_awgn_mp(curves, stats):
    chans = ["awgn", "mp03", "mp08", "mp08h"]
    fig, ax = plt.subplots(2, 2, figsize=(10, 7), sharex=True)
    for j, v in enumerate(("v0", "v0-L")):
        for k, ch in enumerate(chans):
            c = curves[f"{v}|{ch}|n_up=3|energy"]
            s = stats[c["id"]]
            lab = CHANNELS[ch].label
            ax[0, j].plot(s["x"], s["pd"], color=SLOT[k], label=lab)
            ax[0, j].fill_between(s["x"], s["pd_ci"][:, 0], s["pd_ci"][:, 1], color=SLOT[k], alpha=0.15, lw=0)
            ax[1, j].semilogy(s["x"], np.maximum(s["fer"], 1e-3), color=SLOT[k], label=lab)
            ax[1, j].fill_between(s["x"], np.maximum(s["fer_ci"][:, 0], 1e-3), np.maximum(s["fer_ci"][:, 1], 1e-3),
                                  color=SLOT[k], alpha=0.15, lw=0)
        ax[0, j].set_title(f"{v} ({VARIANTS[v].f_low/1000:g}–{VARIANTS[v].f_high/1000:g} kHz)", color=INK)
        ax[0, j].axhline(0.9, color=INK2, lw=0.8, ls=":")
        ax[1, j].axhline(0.1, color=INK2, lw=0.8, ls=":")
        ax[1, j].set_xlabel("Alıcıdaki bant içi SNR, SNR_ib (dB)")
        ax[1, j].set_ylim(1e-3, 1.05)
    ax[0, 0].set_ylabel("Tespit olasılığı Pd (CRC öncesi)")
    ax[1, 0].set_ylabel("Çerçeve hata oranı FER (alt sınır 1e-3 = 0 hata)")
    ax[0, 0].legend(loc="lower right")
    fig.suptitle("SNR'a karşı Pd ve FER — AWGN ve çok yollu kanallar (gölge: %95 Wilson)", color=INK)
    fig.tight_layout()
    fig.savefig(FIGS / "pd_fer_awgn_multipath.png", dpi=130)
    plt.close(fig)


def fig_rubble(curves, stats):
    chans = ["mp03", "rub1", "rub2", "rub3"]
    fig, ax = plt.subplots(2, 2, figsize=(10, 7))
    for v in ("v0", "v0-L"):
        for k, ch in enumerate(chans):
            c = curves[f"{v}|{ch}|n_up=3|energy"]
            s = stats[c["id"]]
            lab = f"{v} · {'moloz yok (RT60 0,3)' if ch == 'mp03' else CHANNELS[ch].label.split(' + ')[0]}"
            src_en0 = en0(v, s["xsrc"])
            ax[0, 0].plot(s["x"], s["pd"], color=SLOT[k], ls=VSTYLE[v], label=lab)
            ax[1, 0].semilogy(s["x"], np.maximum(s["fer"], 1e-3), color=SLOT[k], ls=VSTYLE[v])
            ax[0, 1].plot(src_en0, s["pd"], color=SLOT[k], ls=VSTYLE[v])
            ax[1, 1].semilogy(src_en0, np.maximum(s["fer"], 1e-3), color=SLOT[k], ls=VSTYLE[v])
    for a in ax[0]:
        a.axhline(0.9, color=INK2, lw=0.8, ls=":")
    for a in ax[1]:
        a.axhline(0.1, color=INK2, lw=0.8, ls=":")
        a.set_ylim(1e-3, 1.05)
    ax[1, 0].set_xlabel("Alıcıdaki bant içi SNR_ib (dB) — moloz kaybı SNR'ın İÇİNDE")
    ax[1, 1].set_xlabel("Kaynak düzeyine göre E/N0 (dB), moloz öncesi")
    ax[0, 0].set_ylabel("Pd")
    ax[1, 0].set_ylabel("FER")
    ax[0, 0].legend(loc="lower right", fontsize=7)
    fig.suptitle("Moloz modeli (RT60 0,3 s + frekansa bağlı kayıp) — düz: v0, kesik: v0-L", color=INK)
    fig.tight_layout()
    fig.savefig(FIGS / "pd_fer_rubble.png", dpi=130)
    plt.close(fig)


def fig_en0(curves, stats):
    fig, ax = plt.subplots(1, 2, figsize=(10, 3.8))
    for k, ch in enumerate(("awgn", "mp08")):
        for v in ("v0", "v0-L"):
            s = stats[f"{v}|{ch}|n_up=3|energy"]
            e = en0(v, s["x"])
            ax[0].plot(e, s["pd"], color=SLOT[k], ls=VSTYLE[v], label=f"{v} · {CHANNELS[ch].label}")
            ax[1].semilogy(e, np.maximum(s["fer"], 1e-3), color=SLOT[k], ls=VSTYLE[v])
    ax[0].axhline(0.9, color=INK2, lw=0.8, ls=":")
    ax[1].axhline(0.1, color=INK2, lw=0.8, ls=":")
    ax[1].set_ylim(1e-3, 1.05)
    for a in ax:
        a.set_xlabel("E/N0 (çerçeve enerjisi / gürültü SGY, dB) — bant tanımından bağımsız")
    ax[0].set_ylabel("Pd")
    ax[1].set_ylabel("FER")
    ax[0].legend(fontsize=7, loc="lower right")
    fig.suptitle("v0 ile v0-L, aynı enerji ve aynı gürültü yoğunluğunda (beyaz)", color=INK)
    fig.tight_layout()
    fig.savefig(FIGS / "v0_vs_v0L_en0.png", dpi=130)
    plt.close(fig)


def fig_css(curves, stats):
    fig, ax = plt.subplots(figsize=(6, 3.8))
    for k, ch in enumerate(("awgn", "mp08")):
        for mode, ls in (("energy", "-"), ("coherent", "--")):
            s = stats[f"v0|{ch}|n_up=3|{mode}"]
            ax.semilogy(s["x"], np.maximum(s["fer"], 1e-3), color=SLOT[k], ls=ls,
                        label=f"{CHANNELS[ch].label} · {'enerji toplamı (§6.1)' if mode == 'energy' else 'tutarlı 16 şablon'}")
    ax.axhline(0.1, color=INK2, lw=0.8, ls=":")
    ax.set_ylim(1e-3, 1.05)
    ax.set_xlabel("SNR_ib (dB)")
    ax.set_ylabel("FER")
    ax.legend(fontsize=7)
    ax.set_title("v0 CSS karar kuralı karşılaştırması", color=INK)
    fig.tight_layout()
    fig.savefig(FIGS / "css_energy_vs_coherent.png", dpi=130)
    plt.close(fig)


def fig_gain(gain):
    fig, ax = plt.subplots(1, 2, figsize=(10, 3.8), sharey=True)
    x = np.array(gain["grid_snr_ib_db"])
    for j, v in enumerate(("v0", "v0-L")):
        g = gain["variants"][v]
        ax[j].plot(x, g["pd_single"], color=SLOT[0], label=f"tek chirp (eşik {g['eta1']:.1f})")
        ax[j].plot(x, g["pd_triple"], color=SLOT[1], label=f"3 chirp toplamı (eşik {g['eta3']:.1f})")
        ax[j].axhline(0.9, color=INK2, lw=0.8, ls=":")
        ax[j].set_title(f"{v}: ölçülen birleştirme kazancı {g['measured_combining_gain_db']:.1f} dB", color=INK)
        ax[j].set_xlabel("SNR_ib (dB)")
    ax[0].set_ylabel("Tepe düzeyinde Pd")
    ax[0].legend(loc="lower right")
    fig.tight_layout()
    fig.savefig(FIGS / "combining_gain.png", dpi=130)
    plt.close(fig)


def fig_rubble_model():
    f = np.linspace(500, 5000, 400)
    fig, ax = plt.subplots(figsize=(6, 3.6))
    for k, ch in enumerate(("rub1", "rub2", "rub3")):
        c = CHANNELS[ch]
        ax.plot(f / 1000, -20 * np.log10(rubble_gain(f, c.rubble_l1k_db, c.rubble_beta)), color=SLOT[k + 1],
                label=f"R{k+1}: {c.rubble_l1k_db:g} dB @1 kHz, β={c.rubble_beta:g}")
    for v, col in (("v0", "#d8e6f7"), ("v0-L", "#f6dccf")):
        p = VARIANTS[v]
        ax.axvspan(p.f_low / 1000, p.f_high / 1000, color=col, alpha=0.6, lw=0)
        ax.text((p.f_low + p.f_high) / 2000, 2, v, ha="center", color=INK2)
    ax.set_xlabel("Frekans (kHz)")
    ax.set_ylabel("Moloz kaybı L(f) (dB)")
    ax.set_title("Moloz zayıflama modeli [Tahmin]: L(f) = L1k·(f/1 kHz)^β", color=INK)
    ax.legend(fontsize=8)
    fig.tight_layout()
    fig.savefig(FIGS / "rubble_model.png", dpi=130)
    plt.close(fig)


def main() -> None:
    FIGS.mkdir(parents=True, exist_ok=True)
    pdfer = json.loads((RESULTS / "pdfer.json").read_text())
    curves = {c["id"]: c for c in pdfer["curves"]}
    stats = {cid: curve_stats(c) for cid, c in curves.items()}
    fig_awgn_mp(curves, stats)
    fig_rubble(curves, stats)
    fig_en0(curves, stats)
    fig_css(curves, stats)
    fig_rubble_model()
    summary = {"trials_per_point": pdfer["trials_per_point"], "pdfer_wall_s": pdfer["wall_s"], "curves": []}
    for cid, c in curves.items():
        s = stats[cid]
        v = c["variant"]
        row = {"id": cid, "variant": v, "channel": c["channel"], "css_mode": c["css_mode"],
               "rubble_loss_ib_db": round(c["rubble_loss_ib_db"], 2)}
        for key in ("pd09", "fer01"):
            val = s[key]
            row[f"{key}_snr_ib"] = round(val, 2)
            row[f"{key}_snr_ib_ci95"] = [round(t, 2) for t in s[f"{key}_ci"]]
            conv = snr_conversions(val, VARIANTS[v])
            row[f"{key}_snr_wb"] = round(conv["snr_wb_db"], 2)
            row[f"{key}_e_n0"] = round(conv["e_n0_db"], 2)
            if CHANNELS[c["channel"]].is_rubble:
                src = s[f"{key}_src"]
                row[f"{key}_snr_src"] = round(src, 2)
                row[f"{key}_e_n0_src"] = round(snr_conversions(src, VARIANTS[v])["e_n0_db"], 2)
        row["wrong_crc_pass_total"] = s["wrong_total"]
        row["undecoded_detections"] = s["undecoded_detections"]
        summary["curves"].append(row)
    if (RESULTS / "gain.json").exists():
        gain = json.loads((RESULTS / "gain.json").read_text())
        fig_gain(gain)
        summary["gain"] = {v: {k: g[k] for k in g if not isinstance(g[k], list)} for v, g in gain["variants"].items()}
    for name in ("false_alarm", "cpu", "thresholds"):
        f = RESULTS / f"{name}.json"
        if f.exists():
            summary[name] = json.loads(f.read_text())
    (RESULTS / "summary.json").write_text(json.dumps(summary, indent=1, default=float) + "\n")
    for r in summary["curves"]:
        print(r["id"], "Pd0.9:", r["pd09_snr_ib"], r["pd09_snr_ib_ci95"], "FER0.1:", r["fer01_snr_ib"],
              r["fer01_snr_ib_ci95"], "src:", r.get("pd09_snr_src"), r.get("fer01_snr_src"), "L:", r["rubble_loss_ib_db"],
              "wrong:", r["wrong_crc_pass_total"], "/", r["undecoded_detections"])


if __name__ == "__main__":
    main()
