"""F0-3b: aday başına Ton, görev döngüsü (nominal ve en kötü 60 sn penceresi) ve alıcı CPU süresi.

    research/.venv/bin/python research/sim/run_f03b_cpu_duty.py
Çıktı: research/sim/results/f03b_cpu_duty.json

Görev döngüsü: bütün aralıklar sapma alt sınırında (0,86 · I) iken herhangi bir 60 sn penceredeki
en yüksek açık süre oranı (`timing.max_window_duty`, 1 ms çözünürlük). Ayrıca ≤ %12 için gereken
en küçük sapma alt sınırı (I = 10 sn) ve en küçük nominal aralık (alt sınır 0,86).
CPU: F0-3 `run_cpu.py` ile aynı düzen (120 sn ses, her 10 sn'de bir çerçeve SNR_ib = −10 dB veya
yalnız gürültü, time.process_time, 3 tekrarın en iyisi, tek iş parçacığı). v1 alıcıları çözme
sonrası karar ve RS çözmeyi de içerir.
"""

from __future__ import annotations

import os

for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_v, "1")

import json
import platform
import time

import numpy as np

from common import RESULTS, inband_energy
from run_f03b_pdfer import WAVES, make_frame
from sesver_signal import V0, ReceiverConfig, StreamingReceiver, rs16
from sesver_signal.timing import max_window_duty
from sesver_signal.v1 import CODING, V1_E1, V1_E1E3, V1_E1S, V1_E3, V1Receiver, decode_metrics

DUR_S = 120
SEED = 71_105
LIMIT = 0.12


def worst(p, interval_s: float) -> float:
    return max_window_duty(np.arange(16) * interval_s, p=p)


def duty_rows() -> list[dict]:
    rows = []
    for p, nom in ((V0, 10.0), (V1_E1, 10.0), (V1_E1, 11.0), (V1_E1S, 10.0), (V1_E3, 10.0), (V1_E1E3, 10.0)):
        ton = p.on_len / p.fs
        w = worst(p, 0.86 * nom)
        lb = next((x for x in np.arange(0.80, 1.151, 0.005) if worst(p, x * nom) <= LIMIT), None)
        i_min = next((x for x in np.arange(8.0, 20.01, 0.1) if worst(p, 0.86 * x) <= LIMIT), None)
        rows.append({"wave": p.name, "nominal_s": nom, "ton_s": ton, "tf_s": p.frame_len / p.fs,
                     "duty_nominal": ton / nom, "worst_60s_at_0.86": w, "ok": w <= LIMIT,
                     "min_jitter_lb_for_12pct": None if lb is None else round(float(lb), 3),
                     "min_nominal_s_at_0.86": None if i_min is None else round(float(i_min), 1)})
        print(rows[-1])
    return rows


def audio(wave: str, frames: bool) -> np.ndarray:
    p = WAVES[wave]
    rng = np.random.default_rng(SEED)
    n = DUR_S * p.fs
    y = np.zeros(n)
    if frames:
        x, _ = make_frame(wave, rng)
        e = inband_energy(np.concatenate([np.zeros(4800), x, np.zeros(4800)]), p.rx_band) / p.on_len
        for st in range(p.fs, n - x.size, 10 * p.fs):
            y[st : st + x.size] += x
        sigma = np.sqrt(e / (10 ** (-1.0) * p.rx_bandwidth / (p.fs / 2)))
    else:
        sigma = 0.05
    return y + sigma * rng.standard_normal(n)


def cpu_rows() -> list[dict]:
    cases = [("v0", "energy (v0)", False), ("v0", "energy (v0)", True), ("v0", "E0 coherent", True),
             ("v1-E1", "V1Receiver + RS t2s", False), ("v1-E1", "V1Receiver + RS t2s", True),
             ("v1-E3", "V1Receiver + CRC", True), ("v0", "V1Receiver + E0 + E4", True)]
    rows = []
    for wave, label, frames in cases:
        y = audio(wave, frames)
        p = WAVES[wave]
        for block in (1024, 4800):
            best, n_ev = None, 0
            for _ in range(3):
                if label.startswith("V1Receiver"):
                    rx = V1Receiver(ReceiverConfig(params=p, eta_c=22.25 if wave == "v0" else 22.3))
                else:
                    rx = StreamingReceiver(ReceiverConfig(params=p, eta_c=22.25,
                                                          css_mode="coherent" if "coherent" in label else "energy"))
                t = time.process_time()
                prev = None
                n_ev = 0
                for i in range(0, y.size, block):
                    for e in rx.process(y[i : i + block]):
                        n_ev += 1
                        if label.startswith("V1Receiver"):
                            cod = CODING[wave]
                            d = decode_metrics(e.e_coh[p.name], cod, 2, 2 if cod == "rs" else None)
                            if "E4" in label and prev is not None and not d.ok:
                                decode_metrics(e.e_coh[p.name] + prev, cod)
                            prev = e.e_coh[p.name]
                dt = time.process_time() - t
                best = dt if best is None else min(best, dt)
            rows.append({"wave": wave, "receiver": label, "frames_every_10s": frames, "block": block,
                         "events": n_ev, "ms_per_audio_s": 1000 * best / DUR_S, "rtf": DUR_S / best})
            print(rows[-1])
    return rows


def rs_micro() -> dict:
    rng = np.random.default_rng(1)
    words = [[int(v) for v in rng.integers(0, 16, 10)] for _ in range(20000)]
    t = time.process_time()
    for w in words:
        rs16.decode(w, 2)
    return {"rs_decode_us_per_call_python": 1e6 * (time.process_time() - t) / len(words)}


def main() -> None:
    out = {"machine": platform.machine(), "python": platform.python_version(), "duration_s": DUR_S}
    out["duty"] = duty_rows()
    out["cpu"] = cpu_rows()
    out.update(rs_micro())
    (RESULTS / "f03b_cpu_duty.json").write_text(json.dumps(out, indent=1) + "\n")


if __name__ == "__main__":
    main()
