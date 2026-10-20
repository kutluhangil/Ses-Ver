"""SignalSpec v0 test vektörlerini üretir (sözleşme §7).

Kullanım:
    research/.venv/bin/python research/signal/make_vectors.py [--out research/signal/vectors/v0]

Her vektör: <ad>.json + <ad>.f32 (küçük uçlu float32, A dahil, outputGain = 1).
Ayrıca index.json. Rastgele küme sabit tohumla (SEED) üretilir; çıktı belirlenimcidir.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

from sesver_signal import V0, Fields, frame_from_word, pack  # noqa: E402
from sesver_signal.payload import crc_of_word, word_to_nibbles, word_to_shifts  # noqa: E402

SEED = 20261020
DEFAULT_OUT = Path(__file__).resolve().parent / "vectors" / "v0"


def vector_set() -> list[tuple[str, Fields]]:
    vs: list[tuple[str, Fields]] = []
    vs.append(("min_all", Fields(id=0x001, people=0, injured=0, life_age=0, battery=0, mode=0)))
    vs.append(("max_all", Fields(id=0xFFE, people=3, injured=1, life_age=15, battery=7, mode=3)))
    for m in range(4):
        vs.append((f"mode_{m}", Fields(id=0x7F2, people=1, injured=0, life_age=3, battery=5, mode=m)))
    for la in range(16):
        vs.append((f"lifeage_{la:02d}", Fields(id=0x7F2, people=0, injured=1, life_age=la, battery=6, mode=0)))
    vs.append(("id_7F2", Fields(id=0x7F2, people=2, injured=1, life_age=2, battery=6, mode=0)))
    rng = np.random.default_rng(SEED)
    for i in range(32):
        while True:
            fid = int(rng.integers(0, 4096))
            if fid not in (0x000, 0xFFF):
                break
        vs.append((
            f"random_{i:02d}",
            Fields(id=fid, people=int(rng.integers(0, 4)), injured=int(rng.integers(0, 2)),
                   life_age=int(rng.integers(0, 16)), battery=int(rng.integers(0, 8)), mode=int(rng.integers(0, 4))),
        ))
    return vs


def write_vectors(out: Path) -> list[dict]:
    out.mkdir(parents=True, exist_ok=True)
    p = V0
    index = []
    for name, f in vector_set():
        w = pack(f)
        x = frame_from_word(w, p).astype("<f4")
        raw = x.tobytes()
        (out / f"{name}.f32").write_bytes(raw)
        meta = {
            "name": name,
            "spec": "SignalSpec v0",
            "variant": p.name,
            "fs": p.fs,
            "fields": {
                "id": f.id, "id_hex": f"0x{f.id:03X}", "id_label": f.id_label,
                "people": f.people, "injured": f.injured, "lifeAge": f.life_age,
                "battery": f.battery, "mode": f.mode,
            },
            "W_hex": f"0x{w:08X}",
            "crc_input_hex": f"{(w >> 8) & 0xFFFFFF:06X}",
            "crc_hex": f"0x{crc_of_word(w):02X}",
            "nibbles": word_to_nibbles(w),
            "shifts": word_to_shifts(w),
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
                "probe": {str(k): float(x[k]) for k in (120, 240, 2880, 5759, 9600, 28800 + 2880,
                                                        34560 + 100, 34560 + 3072 + 1536, 59135)},
            },
            "tolerance": {"bits_crc_nibbles_shifts": "exact", "waveform_abs_max": 1e-4},
        }
        (out / f"{name}.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n")
        index.append({"name": name, "W_hex": meta["W_hex"], "json": f"{name}.json", "f32": f"{name}.f32",
                      "sha256": meta["samples"]["sha256"]})
    layout = {
        "U": [[0, 5760], [9600, 15360], [19200, 24960]], "D": [28800, 34560],
        "S": [[34560 + i * 3072, 34560 + (i + 1) * 3072] for i in range(8)],
        "frame_len": p.frame_len, "on_len": p.on_len,
    }
    (out / "index.json").write_text(json.dumps({
        "spec": "SignalSpec v0", "contract": "docs/contracts/signal-v0.md", "generator": "research/signal/make_vectors.py",
        "random_seed": SEED, "count": len(index), "layout_samples": layout, "vectors": index,
    }, indent=2, ensure_ascii=False) + "\n")
    return index


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    a = ap.parse_args()
    idx = write_vectors(a.out)
    print(f"{len(idx)} vektör yazıldı: {a.out}")


if __name__ == "__main__":
    main()
