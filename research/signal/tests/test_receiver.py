import json
from pathlib import Path

import numpy as np
import pytest
from scipy import signal as sps

from sesver_signal import V0, V0L, Fields, ReceiverConfig, StreamingReceiver, decode_buffer, frame, pack

VEC_DIR = Path(__file__).resolve().parents[1] / "vectors" / "v0"


def _noise(rng, n, sigma):
    return sigma * rng.standard_normal(n)


def test_all_vectors_decode_noiseless():
    idx = json.loads((VEC_DIR / "index.json").read_text())
    for v in idx["vectors"]:
        meta = json.loads((VEC_DIR / v["json"]).read_text())
        x = np.fromfile(VEC_DIR / v["f32"], dtype="<f4").astype(np.float64)
        sig = np.concatenate([np.zeros(7000), x, np.zeros(5000)])
        ev = decode_buffer(sig)
        assert len(ev) == 1, (v["name"], [(e.kind, e.start) for e in ev])
        e = ev[0]
        assert e.crc_ok and e.valid
        assert e.word == int(meta["W_hex"], 16)
        assert e.shifts == meta["shifts"] and e.nibbles == meta["nibbles"]
        assert abs(e.start - 7000) < 1.0
        assert e.kind == ("response" if meta["fields"]["mode"] == 3 else "beacon")


@pytest.mark.parametrize("p", [V0, V0L], ids=["v0", "v0-L"])
@pytest.mark.parametrize("seed", [1, 2, 3])
def test_random_offset_embedded_frame(p, seed):
    rng = np.random.default_rng(seed)
    f = Fields(id=int(rng.integers(1, 0xFFF)), people=2, injured=1, life_age=4, battery=3, mode=0)
    x = frame(f, p)
    off = int(rng.integers(3000, 90_000))
    n = off + x.size + 40_000
    sig = _noise(rng, n, 0.02)
    sig[off : off + x.size] += x
    block = int(rng.integers(100, 6000))
    ev = [e for e in decode_buffer(sig, ReceiverConfig(params=p), block=block) if e.valid]
    assert len(ev) == 1
    assert ev[0].word == pack(f)
    assert abs(ev[0].start - off) < 2.0


def test_block_size_invariance():
    rng = np.random.default_rng(7)
    x = frame(Fields(id=0x123, life_age=2), V0)
    sig = _noise(rng, 150_000, 0.05)
    sig[40_000 : 40_000 + x.size] += x
    a = decode_buffer(sig)
    b = decode_buffer(sig, block=480)
    c = decode_buffer(sig, block=4097)
    assert [(e.word, e.kind) for e in a] == [(e.word, e.kind) for e in b] == [(e.word, e.kind) for e in c]
    assert all(abs(ea.start - eb.start) < 1e-6 for ea, eb in zip(a, b))


@pytest.mark.parametrize("ppm", [-100, 100])
@pytest.mark.parametrize("p", [V0, V0L], ids=["v0", "v0-L"])
def test_clock_offset_100ppm(ppm, p):
    f = Fields(id=0xA5C, people=3, injured=0, life_age=11, battery=1, mode=2)
    x = frame(f, p)
    up, down = (10_000 + ppm // 100, 10_000) if ppm > 0 else (10_000 - 1, 10_000)
    y = sps.resample_poly(x, up, down)
    rng = np.random.default_rng(11)
    sig = _noise(rng, 20_000 + y.size + 30_000, 0.03)
    sig[20_000 : 20_000 + y.size] += y
    ev = [e for e in decode_buffer(sig, ReceiverConfig(params=p), block=2048) if e.valid]
    assert len(ev) == 1 and ev[0].word == pack(f)


def test_two_non_overlapping_beacons_separated():
    rng = np.random.default_rng(5)
    f1 = Fields(id=0x111, people=0, injured=1, life_age=1, battery=7, mode=0)
    f2 = Fields(id=0x222, people=3, injured=0, life_age=9, battery=2, mode=1)
    x1, x2 = frame(f1), 0.3 * frame(f2)  # ikinci işaret ~10 dB daha zayıf
    o1 = 10_000
    o2 = o1 + x1.size + 2_400  # yalnız 50 ms boşlukla ardışık
    sig = _noise(rng, o2 + x2.size + 40_000, 0.02)
    sig[o1 : o1 + x1.size] += x1
    sig[o2 : o2 + x2.size] += x2
    rx = StreamingReceiver()
    ev = []
    for i in range(0, sig.size, 1024):
        ev += rx.process(sig[i : i + 1024])
    ev += rx.flush()
    valid = [e for e in ev if e.valid]
    assert [e.word for e in valid] == [pack(f1), pack(f2)]
    assert abs(valid[0].start - o1) < 2 and abs(valid[1].start - o2) < 2


def test_noise_only_produces_no_valid_frame():
    rng = np.random.default_rng(99)
    ev = decode_buffer(_noise(rng, 48_000 * 20, 0.1), block=4800)
    assert not any(e.valid for e in ev)


def test_history_bound():
    rx = StreamingReceiver()
    rng = np.random.default_rng(3)
    x = frame(Fields(id=0x456), V0)
    sig = _noise(rng, 400_000, 0.05)
    sig[100_000 : 100_000 + x.size] += x
    worst = 0
    for i in range(0, sig.size, 512):
        rx.process(sig[i : i + 512])
        worst = max(worst, rx.x.data.size)
    assert worst <= rx.max_history_samples()
