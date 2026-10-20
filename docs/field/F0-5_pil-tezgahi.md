# F0-5: Pil tezgâh testi protokolü

> Sürüm 0.1 · 2026-10-20 · Sahip: `field-qa` + `ios-platform`
> Kapı: F0 kapısı #3, "canlı işaret ≥ 72 sa **veya** Katman 2 ile ≥ 24 sa ek kapsama". BLUEPRINT §2.2 pil hedefi.
> Uygulama: Spike C (`Spikes/SpikeC_BackgroundAudio72h`). Koşu-1 `.playback`, koşu-2 `.playAndRecord`. Ayrıntı: `docs/field/spikes/F0-2-plan.md` (c).
> Kural: Başarısız sonuç silinmez, yumuşatılmaz.

## Amaç
Gerçek SignalSpec v0 zamanlamasıyla (10/20/45/90 sn aralık, pil < %20'de ×2) canlı işaretin kaç saat sürdüğünü ölçmek. Koşullar enkaz altına yakın olmalı: şebeke arayışı, düşük güç modu, ekran kapalı.

## Matris
| Değişken | Değerler |
|---|---|
| Cihaz | iPhone 12, 13, 15 (pil sağlığı not edilir; mümkünse %85+) |
| Başlangıç şarjı | %80 |
| Düşük Güç Modu | Açık |
| Şebeke | **Metal kutu** (Faraday): telefon sürekli şebeke arar. Kontrol koşusu: Uçak modu. |
| Ses düzeyi | %100 |
| Ses oturumu | Koşu-1 `.playback` · Koşu-2 `.playAndRecord` (v1.1 transponder dinleme penceresi taklidi) |
| Sıcaklık | Oda 20–24 °C. Ek koşu: buzdolabı 4–6 °C (R11). |
| Tekrar | Her hücre ≥ 2 |

Asgari koşu: 3 cihaz × metal kutu × koşu-1 × 2 tekrar = 6 koşu. Paralel yürütülürse ~4 gün. Soğuk koşu: 1 cihaz × 1 = ek 3–4 gün.

## Kurulum
1. Cihazı fabrika ayarına yakın tut: arka plan uygulamalarını kapat, Konum Servisleri'ni yalnız sistem için açık bırak, otomatik güncellemeleri kapat.
2. Spike C'yi yükle, "72 sa koşu" modunu seç. Uygulama her çerçevede `SpikeLog`'a şunları yazar: zaman, pil %, termal durum, ses oturumu durumu, kesinti olayı.
3. %80'de şarjdan çıkar, Düşük Güç Modu'nu aç, ekranı kilitle, metal kutuya koy. Kutunun içine kalibre bir ses seviye ölçeri veya ikinci bir kayıt telefonu koy: işaretin gerçekten çaldığını bağımsız olarak kanıtlar.
4. Kutunun dış yüzeyine sıcaklık sensörü koy.

## Ölçümler
- **Süre:** İşaretin başlamasından son duyulabilir çerçeveye kadar (bağımsız kayıttan).
- **Eğri:** %/saat. Görev döngüsü adımlarındaki eğim değişimleri (6, 24, 72 sa).
- **Kesintiler:** Sistem uygulamayı öldürdü mü? Ses oturumu kesildi mi? Ne zaman? (log + sysdiagnose)
- **Termal:** Kısıtlama durumu değişimleri.

## Geçti / kaldı
- Kapı #3 kol A: 3 modelin en az ikisinde, iki tekrarın da ≥ 72 sa sürmesi.
- Kol A geçmezse kol B: Katman 2 (`product24`) ile ≥ 24 sa ek kapsama. Ölçümü spike (d) yapar.
- İkisi de geçmezse BLUEPRINT §6 "Pil yetmiyor" yön değişikliği uygulanır.

## Kayıt formu (koşu başına)
`docs/field/forms/F0-5_kosu.csv`: cihaz, seri son 4 hane, iOS, pil sağlığı %, oturum türü, şebeke koşulu, sıcaklık, başlangıç zamanı, bitiş zamanı, süre sa, öldürülme olayı (evet/hayır, saat), not, kanıt yolu.
