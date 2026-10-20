# SignalSpec v0: Python referans uygulaması

Normatif kaynak: [`docs/contracts/signal-v0.md`](../../docs/contracts/signal-v0.md).
Bu paket verici ve akış (stream) alıcısının referansıdır. Swift (BeaconKit,
DetectorKit) aynı test vektörlerinde bu koda bit düzeyinde (dalga biçiminde
`|Δ| ≤ 1e−4`) eşleşmelidir.

## Kurulum

Depo kökünden:

```sh
python3 -m venv research/.venv
research/.venv/bin/pip install -r research/requirements.txt
```

Bu makinede doğrulanan sürümler: Python 3.15.0, numpy 2.5.4, scipy 1.18.1,
matplotlib 3.11.2, pytest 9.1.1.

## Paket yapısı (`sesver_signal/`)

| Modül | İçerik |
|---|---|
| `constants.py` | `SignalParams`, `V0` (1,8–4,2 kHz) ve `V0L` (1,2–3,0 kHz). Tüm süreler örnek cinsinden. Alıcı bandı: v0 1,5–4,5 kHz, v0-L 0,9–3,3 kHz. |
| `payload.py` | `Fields`, `pack` / `unpack`, CRC-8/AUTOSAR, Gray (`gray`, `gray_inv`), nibble ve kaydırma eşlemesi, `battery_code`. |
| `waveform.py` | §3'ün birebir uygulaması: yükselen/alçalan chirp, CSS sembolü (sarma örnek indeksi `3072 − 192·s`), yarım-Hann pencere, `frame()`. Alıcı şablonları. |
| `timing.py` | §5: nominal aralık, `U(0,85; 1,15)` sapma, görev döngüsü, 60 sn pencere en kötü görev döngüsü. |
| `receiver.py` | `StreamingReceiver`: blok besle, `FrameEvent` listesi al. `decode_buffer()` kolaylık işlevi. |

### Alıcı hattı ve durum

```
ham giriş ─► overlap-save FFT korelasyonu, çekirdek = (bant geçiren FIR ⊛ analitik yükselen chirp)
          ─► P = |y|² ─► CFAR (yerel: max(küçük-olan, 0,25·ortalama)) ─► Pn = P / taban
          ─► C[n] = Pn[n] + maxpool±3(Pn)[n+9600] + maxpool±3(Pn)[n+19200]
          ─► C ≥ eta_c (22,3) ve her tepe ≥ eta_min (2) ve ±12 000 örnekte yerel maksimum
          ─► çözme: FIR + analitik sinyal, alçalan senk ile ince zamanlama,
             dechirp + sıfır dolgulu FFT (v0: 3 200, v0-L: 3 840 nokta),
             kaydırma = argmax |Z(sB/M)|² + |Z(sB/M − B)|², Gray, CRC
```

Bloklar arası bütün durum `StreamingReceiver` alanlarındadır: ham giriş, `P`, `Pn`,
`maxpool`, `C` tamponları (mutlak örnek indeksli) ve her aşamanın "sıradaki indeks"
sayacı (`y_next`, `f_next`, `mp_next`, `c_next`, `nms_next`), bekleyen adaylar ve son
kabul edilen adaylar listesi. Ham giriş tamponu hiçbir zaman `max_history_samples()`
değerini (115 873 örnek, ≈ 2,4 sn) aşmaz. Swift'te bunlar sabit boyutlu halka tamponlar
olur. Gecikme: aday kararı için ≈ çerçeve süresi + 0,25 sn.

`FrameEvent.valid` yalnız CRC doğruysa ve `id ∉ {0x000, 0xFFF}` ise doğrudur.
`kind`: `beacon`, `response` (`mode = 3`), `crc_fail`, `reserved_id`. CRC öncesi
adaylar da olay olarak döner (yanlış alarm ölçümü için). Kullanıcıya yalnız
`valid` olanlar gösterilmelidir.

Eşik `eta_c = 22,3`, beyaz gürültüde ≈ 10 CRC öncesi tespit/saat verecek şekilde
kalibre edildi (`research/sim/calibrate_threshold.py`). Alıcı parametreleri
sözleşmenin parçası değildir.

## Testler

```sh
research/.venv/bin/python -m pytest research/signal/tests -q
```

Kapsam: CRC kontrol değeri (`"123456789" → 0xDF`), CRC'nin 24 bit veride Hamming
mesafesi 4 (kaba kuvvet), pack/unpack ve Gray gidiş-dönüş, örnek sayıları
(çerçeve 59 136, Ton 47 616), test vektörlerinin üreticiyle eşleşmesi ve
gürültüsüz çözülmesi, rastgele ofsette gömülü çerçeve (v0, v0-L), blok boyundan
bağımsızlık, ±100 ppm yeniden örnekleme, ardışık iki işaretin ayrılması,
yalnız gürültüde geçerli çerçeve olmaması, tampon sınırı, görev döngüsü değerleri.

## Test vektörleri

```sh
research/.venv/bin/python research/signal/make_vectors.py
```

Çıktı `vectors/v0/`: 55 vektör (en düşük, en yüksek, 4 `mode`, 16 `lifeAge`,
`id = 0x7F2`, sabit tohumlu 32 rastgele). Her biri `<ad>.json` + `<ad>.f32`
(küçük uçlu float32, 59 136 örnek, `A = 10^(−1/20)`, `outputGain = 1`) ve
`index.json`. JSON alanları: `fields`, `W_hex`, `crc_input_hex` (W >> 8, 3 bayt
büyük uçlu), `crc_hex`, `nibbles`, `shifts`, örnek sayısı, `sha256`, `rms`,
`first8` ve `probe` (seçilmiş indekslerde örnek değerleri). Swift eşleşme testi:
bitler, CRC, nibble'lar, kaydırmalar birebir; her örnekte `|Δ| ≤ 1e−4`.
`sha256` yalnız Python tarafında yeniden üretimi doğrular (Swift float32
çıktısının bit düzeyinde aynı olması beklenmez).

## Simülasyon (F0-3)

```sh
bash research/sim/run_all.sh          # tamamı (bu Mac’te ≈ 37 dk; bkz. rapor §1)
```

Tek tek: `calibrate_threshold.py`, `run_pd_fer.py`, `run_gain.py`,
`run_false_alarm.py`, `run_cpu.py`, `plot_report.py` (hepsi `research/sim/`).
Rapor: [`research/sim/reports/F0-3-report.md`](../sim/reports/F0-3-report.md).

## Ritim örnekleri (F0-6)

`rhythms/` altında üç aday ritim WAV'ı ve üretici betik. Ayrıntı: `rhythms/README.md`.
