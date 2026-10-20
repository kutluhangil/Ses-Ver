import json
from pathlib import Path

import numpy as np

from sesver_signal import V0, V0L, Fields, frame, frame_from_word, symbol
from sesver_signal.timing import duty_cycle, frame_on_mask, max_window_duty, nominal_interval_s
from sesver_signal.waveform import half_hann_window, phase_symbol

VEC_DIR = Path(__file__).resolve().parents[1] / "vectors" / "v0"


def test_sample_counts():
    for p in (V0, V0L):
        assert p.n_pre == 5760 and p.n_gap == 3840 and p.n_sym == 3072
        assert p.up_starts == (0, 9600, 19200)
        assert p.down_start == 28800 and p.data_start == 34560
        assert p.frame_len == 59136
        assert p.on_len == 47616
        assert p.shift_step_samples == 192
        assert frame(Fields(id=0x7F2), p).size == 59136


def test_gaps_are_silent_and_peak_amplitude():
    x = frame(Fields(id=0x7F2, life_age=3), V0)
    for a, b in ((5760, 9600), (15360, 19200), (24960, 28800)):
        assert np.all(x[a:b] == 0.0)
    assert np.max(np.abs(x)) <= V0.amplitude + 1e-12
    assert np.max(np.abs(x)) > 0.99 * V0.amplitude
    assert int(frame_on_mask(V0).sum()) == V0.on_len


def test_window_definition():
    w = half_hann_window(5760, 240)
    assert w[0] == 0.0 and w[-1] == 0.0
    assert np.allclose(w[:240], w[::-1][:240])
    assert np.all(w[240:-240] == 1.0)


def test_symbol_phase_continuous_and_inst_freq():
    p = V0
    for s in range(16):
        phi = phase_symbol(p, s)
        f_inst = np.diff(phi) / (2 * np.pi) * p.fs
        # anlık frekans fL + ((sB/M + k t) mod B), ayrık türev yaklaşık
        t = (np.arange(p.n_sym - 1) + 0.5) / p.fs
        expect = p.f_low + np.mod(s * p.bandwidth / p.alphabet + p.chirp_rate_sym * t, p.bandwidth)
        nw = p.n_sym - s * 192
        mask = np.ones_like(expect, bool)
        mask[max(nw - 2, 0) : nw + 1] = False  # sarma anında türev tanımsız
        assert np.max(np.abs(f_inst[mask] - expect[mask])) < 0.5
        # faz sürekli: sarma anında atlama yok (adım < 2π fH / fs)
        assert np.max(np.diff(phi)) < 2 * np.pi * p.f_high / p.fs + 1e-9
        assert symbol(p, s).size == 3072


def test_vectors_match_generator():
    idx = json.loads((VEC_DIR / "index.json").read_text())
    assert idx["count"] >= 2 + 4 + 16 + 1 + 32
    for v in idx["vectors"]:
        meta = json.loads((VEC_DIR / v["json"]).read_text())
        x = np.fromfile(VEC_DIR / v["f32"], dtype="<f4")
        assert x.size == 59136
        ref = frame_from_word(int(meta["W_hex"], 16), V0)
        assert np.max(np.abs(x - ref)) <= 1e-6
        assert meta["shifts"] == [int(s) for s in meta["shifts"]]


def test_duty_cycle_info_values():
    assert abs(duty_cycle(10.0) - 0.09916) < 1e-4
    assert abs(duty_cycle(8.5) - 0.11666) < 1e-4
    assert nominal_interval_s(0) == 10 and nominal_interval_s(6) == 20
    assert nominal_interval_s(30) == 45 and nominal_interval_s(80) == 90
    assert nominal_interval_s(1, battery_percent=10) == 20


def test_worst_case_60s_window_duty_reported():
    """Sözleşme §5 'herhangi 60 sn pencerede ≤ %12' koşulunun en kötü durumu.

    Bu test sözleşmeyi doğrulamaz, ölçer: aralıkların hepsi 8,5 sn olduğunda
    60 sn pencerede görev döngüsü %12'yi aşar. Rapor 'Sözleşme bulguları'na bakın.
    """
    starts = np.arange(10) * 8.5
    d = max_window_duty(starts)
    assert d > 0.12  # bulgu: sınır en kötü durumda aşılıyor
