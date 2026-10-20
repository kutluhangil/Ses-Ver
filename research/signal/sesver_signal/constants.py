"""SignalSpec v0 sabitleri (docs/contracts/signal-v0.md §1, §2).

Tüm süreler örnek sayısı olarak tutulur (fs = 48 kHz). Böylece Swift tarafı
kayan nokta yuvarlamasına bağlı kalmadan aynı indeksleri kullanır.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class SignalParams:
    name: str
    fs: int = 48_000
    f_low: float = 1_800.0
    f_high: float = 4_200.0
    n_pre: int = 5_760  # Tp = 120 ms
    n_gap: int = 3_840  # Tg = 80 ms
    n_sym: int = 3_072  # Ts = 64 ms
    alphabet: int = 16  # M
    n_symbols: int = 8  # Nsym
    ramp_chirp: int = 240  # 5 ms
    ramp_symbol: int = 96  # 2 ms
    amplitude: float = 10.0 ** (-1.0 / 20.0)  # -1 dBFS
    # Alıcı bant geçireni (sözleşme §6.1 yalnız v0 için 1,5-4,5 kHz verir).
    rx_band: tuple[float, float] = (1_500.0, 4_500.0)

    # --- türetilmiş büyüklükler ---
    @property
    def bandwidth(self) -> float:
        return self.f_high - self.f_low

    @property
    def tp(self) -> float:
        return self.n_pre / self.fs

    @property
    def ts(self) -> float:
        return self.n_sym / self.fs

    @property
    def chirp_rate_pre(self) -> float:
        """Giriş/senk chirp hızı B/Tp (Hz/s)."""
        return self.bandwidth / self.tp

    @property
    def chirp_rate_sym(self) -> float:
        """Veri sembolü chirp hızı k = B/Ts (Hz/s)."""
        return self.bandwidth / self.ts

    @property
    def shift_step_samples(self) -> int:
        """Bir kaydırma adımının örnek karşılığı, Ts/M = 192."""
        return self.n_sym // self.alphabet

    @property
    def up_starts(self) -> tuple[int, int, int]:
        p = self.n_pre + self.n_gap
        return (0, p, 2 * p)

    @property
    def up_spacing(self) -> int:
        return self.n_pre + self.n_gap  # 9 600

    @property
    def down_start(self) -> int:
        return 3 * (self.n_pre + self.n_gap)  # 28 800

    @property
    def data_start(self) -> int:
        return self.down_start + self.n_pre  # 34 560

    def symbol_start(self, i: int) -> int:
        return self.data_start + i * self.n_sym

    @property
    def frame_len(self) -> int:
        return self.data_start + self.n_symbols * self.n_sym  # 59 136

    @property
    def on_len(self) -> int:
        """Ton: boşluklar hariç akustik açık süre (örnek)."""
        return 4 * self.n_pre + self.n_symbols * self.n_sym  # 47 616

    @property
    def rx_bandwidth(self) -> float:
        return self.rx_band[1] - self.rx_band[0]


V0 = SignalParams(name="v0")
# v0-L: yalnız F0-3/F0-4 karşılaştırması (sözleşme §1). Süreler aynı.
# Alıcı bandı v0 ile aynı kenar payıyla (300 Hz) seçildi: 0,9-3,3 kHz.
V0L = SignalParams(name="v0-L", f_low=1_200.0, f_high=3_000.0, rx_band=(900.0, 3_300.0))

VARIANTS = {"v0": V0, "v0-L": V0L}
