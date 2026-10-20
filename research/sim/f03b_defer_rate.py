"""F0-3b: vericinin 60 sn pencere kontrolü (signal-v0 r2 §5) adaylarda ne sıklıkla çerçeve erteletir?

    research/.venv/bin/python research/sim/f03b_defer_rate.py
Basit model: aralıklar I·U(0,86; 1,15); her çerçeve için, çerçeve sonunda biten 60 sn penceredeki
açık süre (önceki çerçevelerin tam Ton'u, pencereye taşan kısmı dahil) > %12 · 60 sn ise "ertelenir"
(erteleme sonrası zamanlama değişikliği modellenmez; oran üst kestirimdir). Tohum 91009, 10^6 çerçeve.
"""
import json

import numpy as np

from common import RESULTS

rng = np.random.default_rng(91_009)
N = 1_000_000
out = []
for name, ton, nom in (("v0", 0.992, 10), ("v1-E1", 1.12, 10), ("v1-E1", 1.12, 11), ("v1-E1s", 1.04, 10),
                       ("v1-E1s", 1.04, 11), ("v1-E3", 1.248, 10)):
    st = np.cumsum(nom * rng.uniform(0.86, 1.15, N))
    end = st + ton
    lo = end - 60.0
    on = np.full(N, ton)
    for k in range(1, 8):
        prev = np.roll(st, k)
        on[k:] += np.clip(prev[k:] + ton - np.maximum(prev[k:], lo[k:]), 0, ton)
    frac = float(np.mean(on[8:] > 0.12 * 60 + 1e-9))
    out.append({"wave": name, "ton_s": ton, "nominal_s": nom, "defer_fraction": frac})
    print(out[-1])
(RESULTS / "f03b_defer_rate.json").write_text(json.dumps(out, indent=1) + "\n")
