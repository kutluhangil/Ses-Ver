"""Kısaltılmış Reed–Solomon RS(10,6), GF(16) (ADR-0004 aday E1).

- Alan: GF(2^4), ilkel polinom x^4 + x + 1 (0x13), α = 2.
- Üreteç: g(x) = (x − α)(x − α²)(x − α³)(x − α⁴) (ilk ardışık kök α¹).
- RS(15,11)'den kısaltılmış: 6 veri + 4 eşlik nibble'ı, d_min = 5.
- Sistematik: kod sözcüğü [d0..d5, p0..p3]; d0 en yüksek dereceli katsayı (x^9).
- Çözme: kalan (r(x) mod g(x)) tablosu. Ağırlığı ≤ 2 olan 10 276 hata deseninin
  kalanları birbirinden farklıdır (d_min = 5'in sonucu, testte doğrulanır).
  `t_max` düzeltilecek en çok sembol sayısıdır (0, 1 veya 2):
    t_max = 2: 2 hatayı düzeltir; 3 hatanın bir kısmı yanlış düzeltilir.
    t_max = 1: 1 hatayı düzeltir; ≤ 3 hatanın tamamı tespit edilir.
    t_max = 0: yalnız tespit; ≤ 4 hata tespit edilir.

Bu modül v0'a dokunmaz. Swift taşıması için tablo yöntemi bit düzeyinde aynıdır.
"""

from __future__ import annotations

from itertools import combinations, product

N = 10
K = 6
NPAR = N - K
PRIM = 0x13

EXP = [0] * 30
LOG = [0] * 16
_v = 1
for _i in range(15):
    EXP[_i] = _v
    LOG[_v] = _i
    _v <<= 1
    if _v & 0x10:
        _v ^= PRIM
for _i in range(15, 30):
    EXP[_i] = EXP[_i - 15]


def gf_mul(a: int, b: int) -> int:
    if a == 0 or b == 0:
        return 0
    return EXP[LOG[a] + LOG[b]]


def _poly_mul(p: list[int], q: list[int]) -> list[int]:
    """Katsayılar en yüksek dereceden başlar."""
    out = [0] * (len(p) + len(q) - 1)
    for i, a in enumerate(p):
        for j, b in enumerate(q):
            out[i + j] ^= gf_mul(a, b)
    return out


GEN = [1]
for _j in range(1, NPAR + 1):
    GEN = _poly_mul(GEN, [1, EXP[_j]])  # (x + α^j); karakteristik 2'de − = +


def _poly_mod(num: list[int]) -> list[int]:
    """num mod GEN (GEN mönik). Dönen: NPAR katsayı, en yüksek dereceden."""
    r = list(num)
    for i in range(len(r) - NPAR):
        c = r[i]
        if c:
            for j in range(1, NPAR + 1):
                r[i + j] ^= gf_mul(GEN[j], c)
    return r[-NPAR:]


def _pack4(nibs: list[int]) -> int:
    v = 0
    for x in nibs:
        v = (v << 4) | x
    return v


# REM[i][v]: kod sözcüğünün i. konumunda (derece N-1-i) v değerinin kalanı, 16 bit.
REM = []
for _i in range(N):
    row = []
    for _val in range(16):
        poly = [0] * N
        poly[_i] = _val
        row.append(_pack4(_poly_mod(poly)))
    REM.append(row)


def remainder(word: list[int]) -> int:
    """r(x) mod g(x), 4 nibble -> 16 bit. Geçerli kod sözcüğünde 0."""
    s = 0
    for i, v in enumerate(word):
        s ^= REM[i][v]
    return s


def encode(data: list[int]) -> list[int]:
    """6 veri nibble'ı -> 10 nibble'lık kod sözcüğü (sistematik)."""
    if len(data) != K or any(not 0 <= d < 16 for d in data):
        raise ValueError("6 adet 4 bitlik veri gerekli")
    s = 0
    for i, v in enumerate(data):
        s ^= REM[i][v]
    par = [(s >> (4 * (NPAR - 1 - j))) & 0xF for j in range(NPAR)]
    return list(data) + par


def _build_table() -> dict[int, tuple[tuple[int, int], ...]]:
    """Kalan -> hata deseni ((konum, değer), ...). Ağırlık 1 ve 2."""
    table: dict[int, tuple[tuple[int, int], ...]] = {}
    for i in range(N):
        for v in range(1, 16):
            key = REM[i][v]
            if key in table:
                raise AssertionError("ağırlık 1 çakışması")
            table[key] = ((i, v),)
    for i, j in combinations(range(N), 2):
        for v, u in product(range(1, 16), repeat=2):
            key = REM[i][v] ^ REM[j][u]
            if key == 0 or key in table:
                raise AssertionError("ağırlık 2 çakışması: d_min < 5")
            table[key] = ((i, v), (j, u))
    return table


ERR_TABLE = _build_table()


def decode(word: list[int], t_max: int = 2) -> tuple[bool, list[int], tuple[tuple[int, int], ...]]:
    """Alınan 10 nibble -> (başarılı mı, düzeltilmiş kod sözcüğü, uygulanan düzeltmeler).

    Başarısızsa kod sözcüğü olarak alınan sözcük döner.
    """
    if len(word) != N:
        raise ValueError("10 nibble gerekli")
    s = remainder(word)
    if s == 0:
        return True, list(word), ()
    pat = ERR_TABLE.get(s)
    if pat is None or len(pat) > t_max:
        return False, list(word), ()
    out = list(word)
    for i, v in pat:
        out[i] ^= v
    return True, out, pat


def accept_fraction_random(t_max: int) -> float:
    """Rastgele 10 nibble'lık bir sözcüğün kabul edilme olasılığı (kesin).

    16^6 · V(10, t) / 16^10; V(10, t) = Σ_{w ≤ t} C(10, w) 15^w.
    """
    from math import comb

    vol = sum(comb(N, w) * 15**w for w in range(t_max + 1))
    return vol / 16**NPAR
