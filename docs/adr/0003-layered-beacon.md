# ADR-0003: Katmanlı işaret — canlı işaret + bildirim zinciri (+ v2 sunucu uyarısı)

- Durum: Önerildi (F0-2 spike'ları sonrası kesinleşir)
- Tarih: 2026-10-20
- Sahip: `architect` · Uygulayan: `ios-platform`
- İlgili: BLUEPRINT §0.1, §1.4, §2.1 K1–K3, §3.2, R3, R4, R5

## Bağlam
- iOS, askıdaki bir uygulamayı ivmeölçer olayıyla uyandırmaz [Kesin].
- Sistem uygulamayı her an sonlandırabilir: bellek baskısı, kullanıcı kaydırması, çökme.
- İşaret en az 24 saat (K2) ve hedef olarak 72 saat (K3) sürmeli.
- Ses düzeyi kısık telefon yüksek olasılıklı bir risk (R5).

Tek bir mekanizma bu koşulların hepsini karşılamıyor.

## Seçenekler
1. **Yalnızca canlı işaret** (`AVAudioEngine`, arka plan ses modu). En yüksek veri kalitesi: canlı `lifeAge`, transponder. Uygulama ölünce işaret de ölür. Ses düzeyi kısıksa sessiz kalır.
2. **Yalnızca bildirim zinciri** (yerel/kritik bildirimler). Uygulama ölse de çalar. 64 bekleyen bildirim sınırı ve 30 sn ses sınırı var [Kesin]. Veri statik, transponder yok, dinleme yok.
3. **Katmanlı: Katman 1 canlı işaret + Katman 2 bildirim zinciri (+ Katman 3 v2'de sunucudan kritik uyarı).** Katman 1 birincil. Katman 2 sigorta: uygulama ölürse ve Critical Alerts varsa ses kısıkken de çalar.
4. **Sessiz ses çalarak canlı kalma + otomatik algılama.** App Review 2.5.4 ihlali. §0.1 gereği reddedildi.

## Karar
Seçenek 3.
- **Katman 1:** `.playAndRecord`, `UIBackgroundModes: audio`, `AVAudioSourceNode` ile sentez. Çerçeveler arası sessizlik aynı motor içinde çalınır, oturum kesintisiz kalır. Bu meşru bir kullanımdır, çünkü çalınan içerik gerçek ve duyulabilir bir işarettir.
- **Katman 2:** Etkinleştirme anında 64 yerel bildirim planlanır (ilk 2 sa 5 dk'da bir, sonraki 10 sa 15 dk'da bir). Ses dosyası ≤ 30 sn olur, `Library/Sounds` içine etkinleştirmeye özel ID ve `mode = 1` ile yazılır. Critical Alerts yetkisi varsa `criticalSoundNamed(_:withAudioVolume: 1.0)`, yoksa normal ses kullanılır. Normal ses kullanıldığında kullanıcıya açık uyarı gösterilir. Katman 1 her çalışmasından sonra en yakın bildirimi ileri kaydırır, iki katman üst üste çalmaz. Uygulama her canlandığında zincir yeniden doldurulur.
- **Katman 3 (v2):** AFAD/EMSC/USGS akışı + "Güvendeyim" yoklaması. Sunucu ve KVKK yükü nedeniyle MVP dışı.
- **Aday ek mekanizma:** AlarmKit (iOS 26+) [Tahmin, doğrulanmadı]. Sessiz modu aşan alarm planlama yolu olabilir. F0-2 spike (i) ile değerlendirilecek. Doğrulanırsa bu ADR güncellenir. Critical Alerts onayı gelmezse (R3) birincil yedek olabilir.

## Sonuçlar
- Olumlu: K2, uygulama ölümünden bağımsız sağlanır. R5 için Critical Alerts kısık sesi de kapsar.
- Olumsuz:
  - Katman 2 yalnız ~12 saat kapsar (64 bildirim), uygulama yeniden canlanmazsa uzamaz. K2'nin 24 saat hedefi için ya aralıklar seyrekleşir ya da uygulamanın periyodik canlanması gerekir. Bu boşluk F0-2(d)'de ölçülecek ve planlama tablosu yeniden ayarlanacak.
  - Zincir çerçeveleri canlılık bilgisi taşımaz. Kurtarıcı arayüzü bunu geri planda göstermeli (R6).
  - Critical Alerts onayı belirsiz (R3).
- Arıza modu tablosu (özet):

| Durum | Katman 1 | Katman 2 | Sonuç |
|---|---|---|---|
| Uygulama çalışıyor, ses açık | Çalar | Ertelenir | Tam işaret |
| Uygulama sonlandırıldı | — | Çalar | Statik işaret, ≤ ~12 sa |
| Ses kısık, kritik yetki var | Kısık çalar | Tam sesle çalar | Kısmi |
| Ses kısık, kritik yetki yok | Kısık | Kısık / sessiz | **Zayıf.** Hazırlık ve işaret ekranı uyarısı zorunlu. |
| Telefon araması / Siri kesintisi | Durur, sonra yeniden başlar | Ertelenir | F0-2 kesinti matrisi |
| Pil biter | — | — | İşaret yok. Pil bütçesi F0-5. |

## F0-2 plan aşaması bulguları (2026-10-20, belge taraması; cihazda henüz ölçülmedi)
Kaynak: `docs/field/spikes/F0-2-plan.md`.
- **[Kesin]** `criticalSoundNamed`: ses `Library/Sounds`'tan çalınabilir, sessiz anahtarı ve Rahatsız Etme'yi aşar. Bildirim sesi < 30 sn olmalı.
- **[Kesin]** Arka planda BLE reklamında servis UUID'si "overflow" alanına taşınır.
- **[Kesin]** AlarmKit, iOS 26+:
  - Odak ve sessiz modu aşar. Kullanıcı izni ve `NSAlarmKitUsageDescription` gerekir, ek entitlement gerekmez.
  - Alarm sayısı sınırı belgelenmemiş.
  - Apple'ın ifadesi (WWDC25): alarmlar Critical Alerts'in yerine geçmez. Bu yüzden App Review riski yüksek.
  - [Muhtemel] `Library/Sounds` sesi varsayılan sese düşüyor. iOS 27'de ayrı alarm ses düzeyi var, bu R5 için yeni bir yüzey.
- **Risk:** iOS 26'da kilit ekranından başlatılan niyette `.playAndRecord` oturumunun `setActive` hatası verdiği bildirilmiş (forum). Katman 1, niyetten yalnız `.playback` ile başlayıp mikrofonu sonradan ekleyebilir. Spike (a) iki yolu ayrı test eder.
- **K2 boşluğu için aday plan (`product24`):** 12 × 5 dk + 12 × 15 dk + 40 × 30 dk = 24 sa, 64 bildirim. Bedeli: 4. saatten sonra 30 dk aralık. AlarmKit ve `BGAppRefreshTask` ile yeniden doldurma ek kapsama olarak ölçülecek.

## Yeniden değerlendirme tetikleyicisi
- F0-2(c): sistem 72 saatten önce arka plan sesini sonlandırıyorsa → Katman 2 süresi uzatılır ve canlanma stratejisi değişir.
- F0-2(d): 64 sınırı veya `Library/Sounds` yazımı beklenenden farklıysa.
- F0-2(i): AlarmKit doğrulanırsa.
- Critical Alerts reddedilirse (F0-8).
- App Review arka plan ses kullanımını reddederse (R4).
