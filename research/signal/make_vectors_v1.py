"""SignalSpec v1 test vektörlerini üretir (docs/contracts/signal-v1.md).

Kullanım:
    research/.venv/bin/python research/signal/make_vectors_v1.py [--out research/signal/vectors/v1]
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

from sesver_signal import rs16
from sesver_signal.payload import gray_inv
from sesver_signal.v1 import CODING, V1, FieldsP1, codeword, frame_v1, pack_p1

SEED = 20261105
DEFAULT_OUT = Path(__file__).resolve().parent / "vectors" / "v1"


def vector_set_v1() -> list[tuple[str, FieldsP1]]:
    vs: list[tuple[str, FieldsP1]] = []
    vs.append(("min_all", FieldsP1(id=0x001, people=0, injured=0, life_age=0, battery=0, mode=0)))
    vs.append(("max_all", FieldsP1(id=0xFFE, people=7, injured=1, life_age=15, battery=3, mode=3)))
    for m in range(4):
        vs.append((f"mode_{m}", FieldsP1(id=0x7F2, people=1, injured=0, life_age=3, battery=2, mode=m)))
    for la in range(16):
        vs.append((f"lifeage_{la:02d}", FieldsP1(id=0x7F2, people=0, injured=1, life_age=la, battery=3, mode=0)))
    vs.append(("id_7F2", FieldsP1(id=0x7F2, people=4, injured=1, life_age=2, battery=2, mode=0)))
    rng = np.random.default_rng(SEED)
    for i in range(32):
        while True:
            fid = int(rng.integers(1, 0xFFF))
            if fid not in (0x000, 0xFFF):
                break
        vs.append((
            f"random_{i:02d}",
            FieldsP1(id=fid, people=int(rng.integers(0, 8)), injured=int(rng.integers(0, 2)),
                     life_age=int(rng.integers(0, 16)), battery=int(rng.integers(0, 4)), mode=int(rng.integers(0, 4))),
        ))
    return vs


def write_vectors_v1(out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    p = V1
    index = []
    for name, f in vector_set_v1():
        w24 = pack_p1(f)
        nib = codeword(w24, CODING[p.name])
        shifts = [gray_inv(n) for n in nib]
        x = frame_v1(w24, p).astype("<f4")
        raw = x.tobytes()
        (out / f"{name}.f32").write_bytes(raw)
        meta = {
            "name": name,
            "spec": "SignalSpec v1",
            "variant": p.name,
            "fs": p.fs,
            "fields": {
                "id": f.id, "id_hex": f"0x{f.id:03X}",
                "people": f.people, "injured": f.injured, "lifeAge": f.life_age,
                "battery": f.battery, "mode": f.mode,
            },
            "data24_hex": f"0x{w24:06X}",
            "nibbles": nib,
            "shifts": shifts,
            "samples": {
                "file": f"{name}.f32",
                "format": "float32 little-endian, mono",
                "count": int(x.size),
                "amplitude": p.amplitude,
                "outputGain": 1.0,
                "sha256": hashlib.sha256(raw).hexdigest(),
                "peak_abs": float(np.max(np.abs(x))),
                "rms": float(np.sqrt(np.mean(x.astype(np.float64) ** 2))),
                "first8": [float(v) for v in x[:8]],
            },
            "tolerance": {"bits_rs_nibbles_shifts": "exact", "waveform_abs_max": 1e-4},
        }
        (out / f"{name}.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n")
        index.append({"name": name, "data24_hex": meta["data24_hex"], "json": f"{name}.json", "f32": f"{name}.f32",
                      "sha256": meta["samples"]["sha256"]})

    (out / "index.json").write_text(json.dumps({
        "spec": "SignalSpec v1", "contract": "docs/contracts/signal-v1.md",
        "frame_len": p.frame_len, "on_len": p.on_len, "count": len(index),
        "vectors": index,
    }, indent=2) + "\n")
    print(f"v1 test vektörleri üretildi: {out} ({len(index)} adet)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    write_vectors_v1(args.out)


if __name__ == "__main__":
    main()
