"""Yük (payload) paketleme, CRC-8/AUTOSAR ve Gray eşlemesi (sözleşme §4)."""

from __future__ import annotations

from dataclasses import asdict, dataclass

RESERVED_IDS = (0x000, 0xFFF)


def crc8_autosar(data: bytes) -> int:
    """CRC-8/AUTOSAR: poly 0x2F, init 0xFF, yansıtma yok, xorout 0xFF."""
    crc = 0xFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = ((crc << 1) ^ 0x2F) & 0xFF if crc & 0x80 else (crc << 1) & 0xFF
    return crc ^ 0xFF


def gray(x: int) -> int:
    """G(x) = x XOR (x >> 1)."""
    return x ^ (x >> 1)


def gray_inv(g: int) -> int:
    x = g
    shift = 1
    while (g >> shift) > 0:
        x ^= g >> shift
        shift += 1
    return x


@dataclass(frozen=True)
class Fields:
    id: int
    people: int = 0
    injured: int = 0
    life_age: int = 15
    battery: int = 0
    mode: int = 0

    def validate(self, allow_reserved_id: bool = False) -> None:
        if not 0 <= self.id <= 0xFFF:
            raise ValueError("id 12 bit olmalı")
        if not allow_reserved_id and self.id in RESERVED_IDS:
            raise ValueError("id 0x000 ve 0xFFF ayrılmış")
        for name, bits in (("people", 2), ("injured", 1), ("life_age", 4), ("battery", 3), ("mode", 2)):
            v = getattr(self, name)
            if not 0 <= v < (1 << bits):
                raise ValueError(f"{name} {bits} bite sığmalı: {v}")

    @property
    def id_label(self) -> str:
        return f"K-{self.id:03X}"

    def to_dict(self) -> dict:
        return asdict(self)


def battery_code(percent: float) -> int:
    """min(7, floor(yüzde / 12,5))."""
    if percent < 0:
        raise ValueError("yüzde negatif olamaz")
    return min(7, int(percent // 12.5))


def pack(fields: Fields, allow_reserved_id: bool = False) -> int:
    """Alanları 32 bitlik W sözcüğüne paketler (CRC dahil)."""
    fields.validate(allow_reserved_id)
    head = (
        (fields.id << 20)
        | (fields.people << 18)
        | (fields.injured << 17)
        | (fields.life_age << 13)
        | (fields.battery << 10)
        | (fields.mode << 8)
    )
    crc = crc8_autosar((head >> 8).to_bytes(3, "big"))
    return head | crc


def crc_of_word(w: int) -> int:
    return crc8_autosar(((w >> 8) & 0xFFFFFF).to_bytes(3, "big"))


def crc_ok(w: int) -> bool:
    return crc_of_word(w) == (w & 0xFF)


def unpack(w: int) -> Fields:
    """W'dan alanları çıkarır. CRC'yi kontrol etmez (crc_ok ayrı)."""
    return Fields(
        id=(w >> 20) & 0xFFF,
        people=(w >> 18) & 0x3,
        injured=(w >> 17) & 0x1,
        life_age=(w >> 13) & 0xF,
        battery=(w >> 10) & 0x7,
        mode=(w >> 8) & 0x3,
    )


def word_to_nibbles(w: int) -> list[int]:
    return [(w >> (28 - 4 * i)) & 0xF for i in range(8)]


def nibbles_to_word(nibbles: list[int]) -> int:
    w = 0
    for n in nibbles:
        w = (w << 4) | (n & 0xF)
    return w


def nibbles_to_shifts(nibbles: list[int]) -> list[int]:
    """Verici: s_i = G^-1(n_i)."""
    return [gray_inv(n) for n in nibbles]


def shifts_to_nibbles(shifts: list[int]) -> list[int]:
    """Alıcı: n_i = G(s_i)."""
    return [gray(s) for s in shifts]


def word_to_shifts(w: int) -> list[int]:
    return nibbles_to_shifts(word_to_nibbles(w))
