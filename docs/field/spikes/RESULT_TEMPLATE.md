# F0-2(?) Spike sonucu: <kısa başlık>

> Dosya adı: `docs/field/spikes/F0-2<harf>-<cihaz>-<iOS>-<YYYY-MM-DD>.md` (ör. `F0-2a-iPhone15Pro-27.1-2026-10-27.md`).
> Başarısız sonuç silinmez, yumuşatılmaz (field-qa kuralı). Her deneme ayrı satır.

## Kimlik
| Alan | Değer |
|---|---|
| Spike | (a) … (i) |
| Hedef (target) | ör. `SpikeA_ActionButtonIntent` |
| Kod sürümü | git kısa SHA veya tarih |
| Yürüten | |
| Tarih / saat dilimi | YYYY-MM-DD, Europe/Istanbul |

## Cihaz
| Alan | Değer |
|---|---|
| Model (pazarlama adı) | ör. iPhone 15 Pro |
| Donanım kimliği | log'daki `model=` (ör. iPhone16,1) |
| iOS sürümü + yapı | ör. 27.1 (24B…) |
| Pil sağlığı (Ayarlar › Pil) | % |
| Kılıf | yok / var (tür) |
| SIM / şebeke | yok / var · Uçak Modu açık/kapalı |
| Parola / Face ID | açık/kapalı (kilit testleri için parola ZORUNLU açık) |

## Kurulum
- Ses düzeyi (outputVolume ve iOS 27'de zil/alarm/bildirim kaydırıcıları):
- Sessiz anahtar / Sessiz mod:
- Odak (Rahatsız Etme, Uyku…):
- Düşük Güç Modu:
- Bildirim izinleri (normal / zaman duyarlı / kritik):
- AlarmKit izni (yalnız i):
- Spike ayarları (oturum varyantı, aralık, kazanç, plan, ses dosyası):
- Ortam: oda sıcaklığı °C, metal kutu (F0-5) evet/hayır, şarj durumu:

## Sonuç
| # | Senaryo / kesinti | Beklenen | Gözlenen | Sonuç (evet/hayır) | Kanıt |
|---|---|---|---|---|---|
| 1 | | | | | |

**Spike hükmü:** EVET / HAYIR / KISMİ (bir cümle; ölçüt plandaki geçti/kaldı tanımına göre)

## Ölçümler
- Süreler (tetik → ilk duyulabilir çerçeve, s; hayatta kalma süresi, sa; pil %/sa …):
- Sayılar (çalınan çerçeve, teslim edilen bildirim, planlanabilen alarm sayısı …):

## Kanıt yolları
> Büyük dosyalar repoya girmez; paylaşılan sürücü yolu + SHA-256 yazılır.
- Ekran / harici kamera kaydı:
- Harici ses kaydı (ikinci cihaz):
- Spike TSV log'u: `Documents/spike-logs/…`
- MetricKit JSON: `Documents/metrickit/…`
- sysdiagnose: `sysdiagnose_YYYY.MM.DD_….tar.gz`
- Instruments izi (`os_signpost`, Power Profiler): `.trace`
- Ekran görüntüleri:

## Notlar
- Beklenmeyen davranışlar, sistem diyalogları (ör. "Kodu girin"), Feedback Assistant numarası (FB…):
- Plan/blueprint varsayımına etkisi (hangi etiket değişmeli: [Muhtemel] → [Kesin] / çürütüldü):
