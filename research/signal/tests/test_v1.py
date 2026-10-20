"""F0-3b: RS(10,6) GF(16) ve v1 aday çerçeveleri (ADR-0004)."""

import numpy as np
import pytest

from sesver_signal import V0, Fields, ReceiverConfig, decode_buffer, frame_from_word, pack, rs16
from sesver_signal.v1 import (CODING, V1_E1, V1_E1E3, V1_E1S, V1_E3, FieldsP1, V1Receiver, decode_metrics,
                              frame_v1, pack_p1, unpack_p1)


def test_gf16_tables():
    assert rs16.EXP[15] == 1 and len(set(rs16.EXP[:15])) == 15
    assert rs16.GEN[0] == 1 and len(rs16.GEN) == 5


def test_rs_roundtrip_and_zero_remainder():
    rng = np.random.default_rng(1)
    for _ in range(500):
        d = [int(x) for x in rng.integers(0, 16, 6)]
        cw = rs16.encode(d)
        assert cw[:6] == d and rs16.remainder(cw) == 0
        ok, out, pat = rs16.decode(cw)
        assert ok and out == cw and pat == ()


def test_rs_corrects_two_symbol_errors():
    rng = np.random.default_rng(2)
    for _ in range(2000):
        cw = rs16.encode([int(x) for x in rng.integers(0, 16, 6)])
        r = list(cw)
        for i in rng.choice(10, 2, replace=False):
            r[i] ^= int(rng.integers(1, 16))
        ok, out, pat = rs16.decode(r, t_max=2)
        assert ok and out == cw and len(pat) == 2


def test_rs_detects_three_errors_with_t1():
    """t_max = 1: d_min = 5 olduğundan ≤ 3 hatanın hepsi tespit edilir (kabul yok)."""
    rng = np.random.default_rng(3)
    for _ in range(3000):
        cw = rs16.encode([int(x) for x in rng.integers(0, 16, 6)])
        r = list(cw)
        for i in rng.choice(10, 3, replace=False):
            r[i] ^= int(rng.integers(1, 16))
        ok, _, _ = rs16.decode(r, t_max=1)
        assert not ok


def test_rs_three_errors_t2_never_returns_original_and_mostly_detected():
    """t_max = 2: 3 hata orijinale düzeltilemez; bir kısmı başka kod sözcüğüne kayar."""
    rng = np.random.default_rng(4)
    n, mis = 3000, 0
    for _ in range(n):
        cw = rs16.encode([int(x) for x in rng.integers(0, 16, 6)])
        r = list(cw)
        for i in rng.choice(10, 3, replace=False):
            r[i] ^= int(rng.integers(1, 16))
        ok, out, _ = rs16.decode(r, t_max=2)
        assert out != cw
        mis += ok
    assert mis / n < 0.5


def test_rs_accept_fraction_formula():
    assert rs16.accept_fraction_random(2) == pytest.approx(10276 / 65536)
    assert rs16.accept_fraction_random(0) == pytest.approx(1 / 65536)
    assert len(rs16.ERR_TABLE) == 10275


def test_p1_pack_roundtrip():
    f = FieldsP1(id=0x7F2, people=7, injured=1, life_age=9, battery=3, mode=2)
    assert unpack_p1(pack_p1(f)) == f
    with pytest.raises(ValueError):
        pack_p1(FieldsP1(id=0xFFF))


@pytest.mark.parametrize("p", [V1_E1, V1_E3, V1_E1E3, V1_E1S])
def test_v1_frame_clean_decode(p):
    rng = np.random.default_rng(5)
    d = pack_p1(FieldsP1(id=0x1A3, people=3, injured=1, life_age=4, battery=2, mode=0))
    x = frame_v1(d, p)
    assert x.size == p.frame_len
    s = np.concatenate([np.zeros(7000), x, np.zeros(20000)]) + 1e-3 * rng.standard_normal(x.size + 27000)
    rx = V1Receiver(ReceiverConfig(params=p))
    ev = rx.process(s) + rx.flush()
    near = [e for e in ev if abs(e.start - 7000) <= 4]
    assert near
    dec = decode_metrics(near[0].e_coh[p.name], CODING[p.name])
    assert dec.ok and dec.data == d


def test_v1receiver_energy_matches_v0_receiver():
    """V1Receiver enerji kararı v0 alıcısının kaydırmalarıyla aynı olmalı."""
    rng = np.random.default_rng(6)
    w = pack(Fields(id=0x7F2, people=1, life_age=3, battery=5))
    x = np.concatenate([np.zeros(9000), frame_from_word(w, V0), np.zeros(30000)])
    p_s = np.sum(x**2) / V0.on_len
    x = x + np.sqrt(p_s * 10 ** (1.0)) * rng.standard_normal(x.size) * 0.05
    ev0 = [e for e in decode_buffer(x) if abs(e.start - 9000) <= 50]
    rx = V1Receiver(ReceiverConfig())
    ev1 = [e for e in rx.process(x) + rx.flush() if abs(e.start - 9000) <= 50]
    assert ev0 and ev1
    assert list(np.argmax(ev1[0].e_en["v0"], axis=1)) == ev0[0].shifts
