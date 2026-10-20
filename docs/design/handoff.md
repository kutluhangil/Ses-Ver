# Tasarım devri: DesignSystem bileşenleri (F1-2 girdisi)

> Sahip: `swiftui-ui`. Kaynaklar:
> - Token'lar: `tokens.json`
> - Metinler: `copy.md`
> - Görsel: `ses-ver-ios-ekranlari.pdf` (v0) ve `DESIGN_PROMPT_v2.md` (v1, beklemede)
> - Güvenlik: `docs/safety/findings-2026-10-20.md`
>
> **Uyarı:** Token sayıları PDF'ten gözle okundu, ölçülmedi. Claude Design'dan kesin ölçü dışa aktarılınca güncellenir. F0 kapısı geçilmeden ekran kodu yazılmaz. Bu belge F1-2'nin girdisidir.

## Bileşenler

| Bileşen | Mod | Durumlar | Erişilebilirlik | Not |
|---|---|---|---|---|
| `PrimaryButton` | ikisi | normal, basılı, devre dışı | Etiket = metin. Hedef ≥ 60/56 pt. | Kehribar zemin, `onSignal` metin, ikon solda |
| `HoldToStopButton` | kurban | boş, doluyor (0→3 sn), tamamlandı | VoiceOver: "Durdur. Üç saniye basılı tutun." Erişilebilirlik eylemi: onay diyaloğu. | Dolgu soldan sağa `stop` %20 opaklık. Bırakınca geri sarar. |
| `MuteBanner` | kurban | gizli, sessizde (geri sayım) | Geri sayım her 30 sn'de bir okunur | S10 |
| `UndoBanner` | kurban | gizli, görünür (10 sn) | Görünür olunca odak bu banda gider | S9 |
| `ChecklistRow` | kurban | tamam, eksik (uyarı), yapılmadı, gezinme oku | Durum ikon + kelime ile verilir | Hazırlık listesi |
| `StatusChip` | ikisi | nötr, uyarı | Metin = durum + sayı | "Ses %100", "Yedek · 24 sa" |
| `HereButton` | kurban | normal, basıldı (haptik + "şimdi") | Büyük hedef, el yordamıyla bulunur: ekranın orta %40'ı | |
| `SegmentPicker` | kurban | hiçbiri seçili değil, biri seçili | "Kaç kişisiniz, seçilmedi" | S7: varsayılan seçim yok |
| `BeaconRing` | kurban | boşta, çalıyor (genişleme) | Azaltılmış harekette statik | |
| `BeaconCard` | kurtarıcı | doğrulanmış, doğrulanıyor, otomatik/dokunuşsuz, yedek zincir, olası çakışma | Okuma sırası: ID → SNR → kişi → yaralı → son dokunuş → duyulma | Sıralama: doğrulanmış > lifeAge dilimi > SNR. Geri plan kartları en sonda. |
| `SNRBar` | kurtarıcı | 0…+24 dB doğrusal dolgu | Değer metinle de verilir | |
| `SNRRamp` | kurtarıcı | 10 segment, aktif segment vurgulu | "+17 dB, rampanın 7. segmenti" | |
| `TrendRow` | kurtarıcı | güçleniyor, zayıflıyor, sabit, belirsiz | Ok + kelime + "±" | S12 |
| `WhistleHistory` | kurtarıcı | son N ıslık çubuğu | Özet: "Son 12 ıslıkta artış" | |
| `BigNumber` | kurtarıcı | — | `monospacedDigit`, ondalık ayırıcı yerel | |
| `TrackingChip` | kurtarıcı | iyi, zayıf, kayıp | İkon + kelime | AR |
| `RegionPanel` | kurtarıcı | normal, donmuş | "DENEYSEL" kalıcı | S13 |
| `TabBar` | kurtarıcı | İşaret / Dinle | — | Ayarlar dişli ikonla |

## Ekran → bileşen eşlemesi (mevcut 7)

| Ekran | Bileşenler | Bağlı güvenlik bulgusu |
|---|---|---|
| Hazırlık | `PrimaryButton`, `ChecklistRow` × 6, sayaç | S6, S15 |
| İşaret aktif | `BeaconRing`, `StatusChip` × 3, `HereButton`, `SegmentPicker`, `MuteBanner`, `HoldToStopButton` | S3, S4, S5, S7, S10, S17 |
| Gece Nöbeti sallantı | geri sayım halkası, `PrimaryButton` × 2, `UndoBanner` | S9 |
| Dinle | `PrimaryButton` (Sessizlik), `BeaconCard` × n, `TabBar` | S1, S2, S7, S8, S11 |
| Sıcak-soğuk | `BigNumber`, `TrendRow`, `SNRRamp`, `WhistleHistory`, `PrimaryButton` | S12 |
| AR | `TrackingChip`, `RegionPanel`, `PrimaryButton` | S13 |

## Uygulama notları
- Kurban modu her zaman koyu. `preferredColorScheme(.dark)` kullanılır, sistem açık modu yok sayılır.
- Kontrast oranları (WCAG, hesaplandı). Hepsi AA'yı (4,5:1) geçiyor:

| Çift | Oran |
|---|---|
| Kurtarıcı `text` / `bg` | 16,8:1 |
| Kurtarıcı `text2` / `bg` | 8,3:1 |
| Kurban `text` / `bg` | 18,3:1 |
| Kurban `text2` / `surface` | 7,6:1 |
| `signal` / kurtarıcı `bg` | 10,5:1 |
| `onSignal` / `signal` | 10,4:1 |
| `stop` / kurban `surface` | 6,7:1 |

  Güneş altı için kurtarıcı birincil metinde ≥ 12:1 hedefi yalnız `text` ile sağlanıyor. Kritik sayılar (SNR, ID) `text2` ile yazılmaz.
- Tüm metinler `Localizable.xcstrings`'ten gelir. Anahtarlar `copy.md` ile birebir aynıdır.
- Snapshot testleri: her bileşen × durum × {varsayılan, AX3, AX5} × {TR, EN}.
