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


def decode_erasures(
    word: list[int], erasures: list[int], t_max: int = 0
) -> tuple[bool, list[int], tuple[tuple[int, int], ...]]:
    """Silinme (erasure) konumları bilinen kod sözcüğü çözücü.

    2*t + e <= 4 koşulunu sağlar (d_min = 5).
    erasures: silinmiş (güvenilmeyen) sembollerin indeksleri (0..9).
    t_max: silinmeler dışındaki ek rastgele sembol hatası sınırı.
    """
    if len(word) != N:
        raise ValueError("10 nibble gerekli")
    er_set = sorted(set(erasures))
    e_cnt = len(er_set)
    if 2 * t_max + e_cnt > NPAR:
        return False, list(word), ()

    s_orig = remainder(word)
    if s_orig == 0 and e_cnt == 0:
        return True, list(word), ()

    # e = 0: normal decode
    if e_cnt == 0:
        return decode(word, t_max=t_max)

    # e = 1 silinme
    if e_cnt == 1:
        p0 = er_set[0]
        # s_orig ^ REM[p0][v0] = s_target
        # t = 0 için s_target = 0 => REM[p0][v0] == s_orig
        for v0 in range(16):
            s_rem = s_orig ^ REM[p0][v0]
            if s_rem == 0:
                out = list(word)
                out[p0] ^= v0
                return True, out, ((p0, v0),)
            if t_max >= 1 and s_rem in ERR_TABLE:
                pat = ERR_TABLE[s_rem]
                if len(pat) <= t_max and all(pos != p0 for pos, _ in pat):
                    out = list(word)
                    out[p0] ^= v0
                    for pos, val in pat:
                        out[pos] ^= val
                    corr = ((p0, v0),) + pat
                    return True, out, corr
        return False, list(word), ()

    # e = 2 silinme
    if e_cnt == 2:
        p0, p1 = er_set[0], er_set[1]
        for v0 in range(16):
            s_partial = s_orig ^ REM[p0][v0]
            for v1 in range(16):
                s_rem = s_partial ^ REM[p1][v1]
                if s_rem == 0:
                    out = list(word)
                    out[p0] ^= v0
                    out[p1] ^= v1
                    corr = tuple((pos, val) for pos, val in ((p0, v0), (p1, v1)) if val != 0)
                    return True, out, corr
                if t_max >= 1 and s_rem in ERR_TABLE:
                    pat = ERR_TABLE[s_rem]
                    if len(pat) <= t_max and all(pos not in (p0, p1) for pos, _ in pat):
                        out = list(word)
                        out[p0] ^= v0
                        out[p1] ^= v1
                        for pos, val in pat:
                            out[pos] ^= val
                        corr = tuple((pos, val) for pos, val in ((p0, v0), (p1, v1)) if val != 0) + pat
                        return True, out, corr
        return False, list(word), ()

    # e in (3, 4) silinme (t_max = 0 olmalı)
    if e_cnt <= NPAR and t_max == 0:
        def _solve_rec(idx: int, curr_s: int, current_vals: list[int]):
            if idx == e_cnt:
                if curr_s == 0:
                    return current_vals
                return None
            pos = er_set[idx]
            for v in range(16):
                res = _solve_rec(idx + 1, curr_s ^ REM[pos][v], current_vals + [v])
                if res is not None:
                    return res
            return None

        sol = _solve_rec(0, s_orig, [])
        if sol is not None:
            out = list(word)
            corr = []
            for pos, v in zip(er_set, sol):
                out[pos] ^= v
                if v != 0:
                    corr.append((pos, v))
            return True, out, tuple(corr)

    return False, list(word), ()


def accept_fraction_random(t_max: int) -> float:
    """Rastgele 10 nibble'lık bir sözcüğün kabul edilme olasılığı (kesin).

    16^6 · V(10, t) / 16^10; V(10, t) = Σ_{w ≤ t} C(10, w) 15^w.
    """
    from math import comb

    vol = sum(comb(N, w) * 15**w for w in range(t_max + 1))
    return vol / 16**NPAR
