import itertools

import numpy as np
import pytest

from sesver_signal.payload import (
    Fields,
    battery_code,
    crc8_autosar,
    crc_ok,
    gray,
    gray_inv,
    nibbles_to_word,
    pack,
    shifts_to_nibbles,
    unpack,
    word_to_nibbles,
    word_to_shifts,
)


def test_crc_check_value():
    assert crc8_autosar(b"123456789") == 0xDF


def test_crc_all_zero_payload_not_valid():
    # init != 0: tamamen sıfır sözcük geçerli sayılmaz (sözleşme §4.2 gerekçesi)
    assert not crc_ok(0x00000000)


def test_pack_unpack_roundtrip_random():
    rng = np.random.default_rng(1)
    for _ in range(2000):
        f = Fields(id=int(rng.integers(1, 0xFFF)), people=int(rng.integers(0, 4)), injured=int(rng.integers(0, 2)),
                   life_age=int(rng.integers(0, 16)), battery=int(rng.integers(0, 8)), mode=int(rng.integers(0, 4)))
        w = pack(f)
        assert crc_ok(w)
        assert unpack(w) == f
        n = word_to_nibbles(w)
        assert nibbles_to_word(n) == w
        assert shifts_to_nibbles(word_to_shifts(w)) == n


def test_field_layout_bits():
    w = pack(Fields(id=0xABC, people=2, injured=1, life_age=9, battery=5, mode=1))
    assert (w >> 20) == 0xABC
    assert (w >> 18) & 3 == 2 and (w >> 17) & 1 == 1
    assert (w >> 13) & 0xF == 9 and (w >> 10) & 7 == 5 and (w >> 8) & 3 == 1
    assert w & 0xFF == crc8_autosar(((w >> 8) & 0xFFFFFF).to_bytes(3, "big"))


def test_reserved_ids_rejected_by_packer():
    for rid in (0x000, 0xFFF):
        with pytest.raises(ValueError):
            pack(Fields(id=rid))


def test_gray_roundtrip_and_adjacency():
    for x in range(16):
        assert gray_inv(gray(x)) == x
        assert gray(gray_inv(x)) == x
    # komşu kaydırma (15 <-> 0 dahil) tek bit farkı
    for s in range(16):
        d = gray(s) ^ gray((s + 1) % 16)
        assert bin(d).count("1") == 1


def test_battery_code():
    assert battery_code(0) == 0 and battery_code(12.49) == 0 and battery_code(12.5) == 1
    assert battery_code(87.49) == 6 and battery_code(87.5) == 7 and battery_code(100) == 7


def test_crc_hamming_distance_is_4_on_24bit_data():
    """Sözleşme §4.2 [Muhtemel] HD=4 iddiasının kaba kuvvet doğrulaması.

    CRC afin olduğu için mesafe, doğrusal kısmın (init=0, xorout=0) en küçük
    sıfırdan farklı kod sözcüğü ağırlığıdır.
    """
    def lin(d):
        return crc8_autosar(d.to_bytes(3, "big")) ^ crc8_autosar(b"\x00\x00\x00")

    best = 99
    for k in (1, 2, 3):
        for bits in itertools.combinations(range(24), k):
            d = sum(1 << b for b in bits)
            best = min(best, k + bin(lin(d)).count("1"))
    assert best >= 4
    # ağırlık 4 kod sözcüğü var mı (HD tam 4 mü)?
    found4 = best == 4
    if not found4:
        for bits in itertools.combinations(range(24), 4):
            if lin(sum(1 << b for b in bits)) == 0:
                found4 = True
                break
    assert found4
