"""F0-3b karar tablosu: results/f03b_*.json -> markdown (stdout).

    research/.venv/bin/python research/sim/f03b_table.py
Eksen: SNR_wb (aynı hoparlör genliği, aynı beyaz gürültü yoğunluğu). Moloz satırları kaynak SNR_wb.
"""
import json

from common import RESULTS

S = {(r["wave"], r["channel"]): r for r in json.loads((RESULTS / "f03b_summary.json").read_text())["rows"]}
FA = {(r["layout"], r["decoder"]): r for r in json.loads((RESULTS / "f03b_false_alarm.json").read_text())["results"]}
CD = json.loads((RESULTS / "f03b_cpu_duty.json").read_text())
DUTY = {(d["wave"], d["nominal_s"]): d for d in CD["duty"]}


def wb(wave, ch, key):
    r = S.get((wave, ch))
    if r is None:
        return "—"
    off = r["wb_offset_db"] + (r["rubble_loss_ib_db"] if ch.startswith("rub") else 0)
    v = r["pd09_rx"] if key == "pd" else r["fer01_rx"].get(key)
    if v is None or v[0] is None:
        return "—"
    f = lambda x: "?" if x is None else f"{x + off:+.1f}".replace(".", ",").replace("-", "−")  # noqa: E731
    return f"{f(v[0])} [{f(v[1])}; {f(v[2])}]"


def fa(lay, dec, e4=False):
    r = FA.get((lay, dec))
    if r is None:
        return "ölçülmedi"
    k = "single_plus_e4" if e4 else "single"
    v, (lo, hi) = r[f"{k}_per_h"], r[f"{k}_ci95"]
    n = r["single"] + (r["e4_extra"] if e4 else 0)
    g = lambda x: f"{x:.2f}".replace(".", ",")  # noqa: E731
    return f"{g(v)} [{g(lo)}; {g(hi)}] (n={n})"


def rule(fak):
    if not fak:
        return "ölçülmedi"
    r = FA[(fak[0], fak[1])]
    k = "e4_verified" if fak[2] else "single_verified"
    return f"{r[k]} gözlendi (%95 üst {r[k + '_ci95'][1]:.2f})".replace(".", ",")


rows = [
    ("v0 (B0, enerji kararı, CRC-8) — referans", "v0", "en", "B0", ("v0", "en", False), ("v0", 10.0)),
    ("v0 + E0", "v0", "coh", "B0", ("v0", "coh", False), ("v0", 10.0)),
    ("v0 + E0 + E4", "v0", "coh+E4", "B0", ("v0", "coh", True), ("v0", 10.0)),
    ("B1 + E0 (yalnız bant, v0-L)", "v0-L", "coh", "B1", None, ("v0", 10.0)),
    ("B1 + E1 RS t=1 + P1", "v1-E1", "rs_t1", "B1", ("v1-E1", "rs_t1", False), ("v1-E1", 10.0)),
    ("B1 + E1 RS t=1 + P1 + E4", "v1-E1", "rs_t1+E4", "B1", ("v1-E1", "rs_t1", True), ("v1-E1", 10.0)),
    ("B1 + E1 RS t=2 + P1", "v1-E1", "rs_t2", "B1", ("v1-E1", "rs_t2", False), ("v1-E1", 10.0)),
    ("B1 + E1 RS t=2 yumuşak doğrulamalı (t2s)", "v1-E1", "rs_t2s", "B1", ("v1-E1", "rs_t2s", False), ("v1-E1", 10.0)),
    ("B1 + E1 (chirp 100 ms) RS t=1", "v1-E1s", "rs_t1", "B1", None, ("v1-E1s", 10.0)),
    ("B1 + E3 + P1 (CRC-8)", "v1-E3", "coh", "B1", ("v1-E3", "coh", False), ("v1-E3", 10.0)),
    ("B1 + E3 + P1 + E4", "v1-E3", "coh+E4", "B1", ("v1-E3", "coh", True), ("v1-E3", 10.0)),
    ("B1 + E1 + E3 RS t=1", "v1-E1E3", "rs_t1", "B1", ("v1-E1E3", "rs_t1", False), ("v1-E1E3", 10.0)),
]
cpu = {}
for c in CD["cpu"]:
    if c["frames_every_10s"]:
        cpu.setdefault(c["receiver"] + c["wave"], []).append(c["ms_per_audio_s"])
cpu_of = {"v0|en": "energy (v0)v0", "v0|coh": "E0 coherentv0", "v0|coh+E4": "V1Receiver + E0 + E4v0",
          "v1-E1|": "V1Receiver + RS t2sv1-E1", "v1-E3|": "V1Receiver + CRCv1-E3"}
print("| Aday | FER 0,1 AWGN | FER 0,1 RT60 0,8/DRR −6 | FER 0,1 moloz R2 (kaynak) | Pd 0,9 AWGN | Pd 0,9 R2 (kaynak) "
      "| Yanlış kabul/sa, kuralsız | Yanlış kabul/sa, iki çerçeve kuralı | Ton (s) | En kötü 60 sn (I = 10 sn, 0,86) | CPU ms/sn |")
print("|---|---|---|---|---|---|---|---|---|---|---|")
for lab, wave, key, bnd, fak, dk in rows:
    d = DUTY[dk]
    ck = cpu_of.get(f"{wave}|{key}") or cpu_of.get(f"{wave}|")
    cp = "–".join(f"{x:.1f}" for x in sorted(cpu[ck])).replace(".", ",") if ck in cpu else "ölçülmedi"
    print(f"| {lab} | {wb(wave, 'awgn', key)} | {wb(wave, 'mp08h', key)} | {wb(wave, 'rub2', key)} | {wb(wave, 'awgn', 'pd')} "
          f"| {wb(wave, 'rub2', 'pd')} | {fa(*fak) if fak else 'ölçülmedi'} | {rule(fak)} | {d['ton_s']:.3f}".replace(".", ",")
          + f" | {100 * d['worst_60s_at_0.86']:.2f} %".replace(".", ",") + f"{'' if d['ok'] else ' (aşar)'} | {cp} |")
