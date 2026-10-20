# F0-2 iOS spike planı (a)–(i)

> Sahip: `ios-platform` · Faz: F0 · Tarih: 2026-10-20 · Durum: **Plan** (hiçbir spike henüz cihazda koşulmadı)
> Kaynak iskeletler: `Spikes/` (XcodeGen, `Spikes/README.md`). Sonuç şablonu: [RESULT_TEMPLATE.md](RESULT_TEMPLATE.md).
> Etiketler BLUEPRINT ile aynı: [Kesin] doğrudan belge/SDK kanıtı · [Muhtemel] güçlü çıkarım veya Apple çalışanının forum yanıtı · [Tahmin].
> **Simülatör kanıt değildir.** Her hüküm gerçek cihazda, parola açıkken, cihaz modeli + iOS sürümü + tarih ile yazılır.

## 0. Özet

| Spike | Soru | Beslediği | Kritik yol? |
|---|---|---|---|
| (a) | Eylem Düğmesi → `AudioPlaybackIntent` kilitliyken uygulama açılmadan ses başlatıyor mu? | K1, **F0 kapısı #4** | Evet |
| (b) | Kilit ekranı / Kontrol Merkezi `ControlWidgetButton` + `authenticationPolicy` kilitliyken çalışıyor mu? | K1, **F0 kapısı #4** | Evet |
| (c) | `audio` arka plan modu ile ekran kapalı 72 sa duyulabilir işaret (+ mikrofon) sürüyor mu? | K3, **F0 kapısı #3**, F0-5 | Evet |
| (d) | 64 yerel bildirim zinciri + `Library/Sounds` sesi; uygulama ölünce ≥24 sa? | K2, **F0 kapısı #3 (alternatif kol)** | Evet |
| (e) | Arka planda BLE reklamı başka iPhone'dan bulunuyor mu? | §3.2 BLE, K6 (dolaylı) | Hayır |
| (f) | `outputVolume` güvenilir okunuyor mu? | R5, §0.4 | Hayır |
| (g) | Gece Nöbeti siyah ekran + 50 Hz Core Motion güç tüketimi | v1.1 Gece Nöbeti | Hayır |
| (h) | Siri ile internetsiz başlatma (TR/EN) | K1 (yedek yol) | Hayır |
| (i) **yeni** | AlarmKit: sessiz modu/Odak'ı aşan alarm Katman 2'ye alternatif/ek olabilir mi? | K2, R3, R5, **F0 kapısı #3** | Evet (R3 yedeği) |

## 1. Platform doğrulaması (2026-10-20, Xcode 27.1 / iPhoneOS 27.1 SDK)

Masa başında doğrulandı (belge + yerel SDK `.swiftinterface`). Cihaz kanıtı değildir; spike'lar bunları sahada test eder.

| # | İddia | Durum | Kaynak |
|---|---|---|---|
| V1 | `AudioPlaybackIntent` iOS 17.0+; amacı sistemin sesi kesecek diyalogdan kaçınması | [Kesin] | [AudioPlaybackIntent](https://developer.apple.com/documentation/appintents/audioplaybackintent), SDK |
| V2 | `authenticationPolicy` varsayılanı `.alwaysAllowed` = "kilitliyken dahil" kimlik doğrulamasız çalışır. Diğerleri `.requiresAuthentication`, `.requiresLocalDeviceAuthentication` | [Kesin] | [authenticationPolicy](https://developer.apple.com/documentation/appintents/appintent/authenticationpolicy), [IntentAuthenticationPolicy](https://developer.apple.com/documentation/appintents/intentauthenticationpolicy) |
| V3 | `AudioPlaybackIntent`/`LiveActivityIntent` niyetleri widget/kontrol uzantısında değil **uygulama sürecinde** çalışır (uygulama açılmadan arka planda başlatılır) | [Kesin] | [Adding interactivity to widgets](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities) |
| V4 | iOS 26: `openAppWhenRun` kullanımdan kalktı, yerine `supportedModes` (`.background`, `.foreground(.immediate/.deferred/.dynamic)`) | [Kesin] | iPhoneOS27.1.sdk `AppIntents.swiftinterface` |
| V5 | `ControlWidgetButton` iOS 18+; kontroller Kontrol Merkezi, Kilit Ekranı ve Eylem Düğmesi'nde. Kimlik doğrulama niyetin `authenticationPolicy`'si ile ayarlanır | [Kesin] | [ControlWidgetButton](https://developer.apple.com/documentation/widgetkit/controlwidgetbutton), [Creating controls](https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system), [Refinements](https://developer.apple.com/documentation/widgetkit/adding-refinements-and-configuration-to-controls) |
| V6 | **Uyarı:** geliştiriciler `.alwaysAllowed` olsa da kilitliyken "kodu girin" istendiğini raporluyor (`openAppWhenRun = true` ile; yanıtsız) | [Muhtemel] risk | [Forum 793047](https://developer.apple.com/forums/thread/793047), [Forum 738252](https://developer.apple.com/forums/thread/738252) |
| V7 | **Uyarı:** iOS 26'da kilit ekranında `AudioRecordingIntent` içinden `AVAudioSession.setActive` hata veriyor (561015905); uygulamaya yönlendirince Face ID isteniyor. Mikrofonlu kategoriyi kilitliyken başlatmak sorunlu olabilir → (a)'da `.playback` ve `.playAndRecord` ayrı test edilir | [Muhtemel] risk | [Forum 836958](https://developer.apple.com/forums/thread/836958) |
| V8 | `criticalSoundNamed(_:withAudioVolume:)`: kritik uyarılar sessiz anahtarını ve Rahatsız Etme'yi yok sayar; özel entitlement gerekir. Dosya ana pakette **veya `Library/Sounds`** içinde; ikisinde de varsa `Library/Sounds` kazanır | [Kesin] (BLUEPRINT'te `Library/Sounds` [Muhtemel] idi → **doğrulandı**) | [criticalSoundNamed](https://developer.apple.com/documentation/usernotifications/unnotificationsound/criticalsoundnamed(_:withaudiovolume:)) |
| V9 | Bildirim sesi `aiff`/`wav`/`caf`, **< 30 s**; uzunsa varsayılan ses çalar | [Kesin] | [UNNotificationSound](https://developer.apple.com/documentation/usernotifications/unnotificationsound) |
| V10 | Critical Alerts: entitlement `com.apple.developer.usernotifications.critical-alerts`, başvuru formu; yanıt haftalar–aylar sürebiliyor; sağlık/güvenlik/acil durum kullanımlarına veriliyor | [Kesin] (anahtar+form) / [Muhtemel] (süre, kapsam) | [Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.usernotifications.critical-alerts), [Form](https://developer.apple.com/contact/request/notifications-critical-alerts-entitlement/), [Forum 130016](https://developer.apple.com/forums/thread/130016), [Forum 106042](https://developer.apple.com/forums/thread/106042) (bekleme süreleri geliştirici raporu) |
| V11 | Bekleyen yerel bildirim sınırı 64 (en erken 64 tutulur, kalanı atılır) | [Kesin] eski API belgesi + Apple mühendisi forum yanıtı (UN API'si için ayrı belge yok) | [UILocalNotification](https://developer.apple.com/documentation/uikit/uilocalnotification), [Forum 811171](https://developer.apple.com/forums/thread/811171) |
| V12 | Kritik uyarı sesleri uygulamanın ses oturumuyla çalınmaz; aynı anda yalnız biri çalar | [Muhtemel] (DTS forum) | [Forum 838099](https://developer.apple.com/forums/thread/838099) |
| V13 | Arka planda yerel ad reklam edilmez; tüm servis UUID'leri "overflow" alanına gider, yalnızca o UUID'yi açıkça tarayan iOS cihazı görür | [Kesin] (BLUEPRINT [Muhtemel] → **doğrulandı**) | [startAdvertising(_:)](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager/startadvertising(_:)) |
| V14 | `outputVolume` salt okunur, KVO ile izlenebilir; sistem ses düzeyini yalnızca kullanıcı değiştirir (`MPVolumeView` kullanıcı kontrolü olarak önerilir) | [Kesin] | [outputVolume](https://developer.apple.com/documentation/avfaudio/avaudiosession/outputvolume) |
| V15 | `audio` arka plan kategorisi + etkin oturum = süresiz canlı kalma; oturum **yalnız ön planda** etkinleştirilmeli; iOS 26'da değişiklik yok; sesli/sessiz kayıt ayrımı yok | [Muhtemel] (Apple DTS forum yanıtı, belge değil) | [Forum 826462](https://developer.apple.com/forums/thread/826462) |
| V16 | AlarmKit iOS/iPadOS 26.0+; alarm gerekirse Odak'ı ve sessiz modu aşar; kullanıcı izni (`NSAlarmKitUsageDescription`, boşsa planlanamaz); Ayarlar'dan geri alınabilir | [Kesin] | [AlarmKit](https://developer.apple.com/documentation/alarmkit), [Örnek](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit), [WWDC25-230](https://developer.apple.com/videos/play/wwdc2025/230/) |
| V17 | AlarmKit sesi: `AlertConfiguration.AlertSound.named(_:)`, ana paket veya `Library/Sounds`; `Alarm.Schedule.fixed(Date)` ve `.relative`; `AlarmManager.AlarmError.maximumLimitReached` var ama **sayı belgelenmemiş** | [Kesin] API / sayı **doğrulanamadı** | SDK `AlarmKit.swiftinterface`, WWDC25-230 |
| V18 | Apple: "Alarms … are not a replacement for other prominent notifications, like critical alerts or time-sensitive notifications." | [Kesin] → App Review riski | [WWDC25-230](https://developer.apple.com/videos/play/wwdc2025/230/) |
| V19 | AlarmKit özel sesi < 30 s, bir kez çalar (döngü yok); `Library/Sounds` sesi varsayılana düşüyor (Şubat 2026'da hâlâ açık) | [Muhtemel] (Apple mühendisi + geliştirici raporları) | [Forum 797172](https://developer.apple.com/forums/thread/797172), [Forum 798140](https://developer.apple.com/forums/thread/798140) |
| V20 | iOS 27 beta'da AlarmKit gerilemeleri: `.alerting` güncellemesi uygulama çalışana kadar gecikiyor, geç yeniden gösterim, Odak altında UI'sız ses (FB23754550, açık) | [Muhtemel] (tek geliştirici) | [Forum 844479](https://developer.apple.com/forums/thread/844479) |
| V21 | iOS 27: zil, alarm, zamanlayıcı, bildirim için ayrı ses düzeyleri (kullanıcı ayarı). AlarmKit ve bildirim seslerinin hangi kaydırıcıya bağlı olduğu **doğrulanamadı** | [Muhtemel] (basın) | [Appleosophy](https://appleosophy.com/2026/06/08/ios-27-features-separate-volume-controls-for-ringtone-alarms-and-notifications/) |
| V22 | Siri'de cihaz üstü işleme A12+ (iOS 15); "uygulama açma" çevrimdışı çalışır. App Shortcut niyetlerinin çevrimdışı çalışması ve **Türkçe** cihaz üstü desteği **doğrulanamadı** | [Muhtemel] (basın) | [MacRumors iOS 15 Siri](https://www.macrumors.com/guide/ios-15-siri) |
| V23 | Düşük Güç Modu'nun arka plan ses oturumuna etkisi | **doğrulanamadı** (belge yok) → (c) ölçer | — |
| V24 | Arka plan BLE reklam aralığı/sıklığı | **doğrulanamadı** (belge yok) → (e) ölçer | [Core Bluetooth arka plan (arşiv)](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html) |
| V25 | iOS 26/27'de yerel bildirim / kritik uyarı davranışında değişiklik | **doğrulanamadı** (sürüm notlarında bulunamadı) | — |

**Blueprint'e etkiler (Orkestratör/architect'e öneri, bu belge değiştirmez):**
1. §3.2 BLE "overflow" ve `Library/Sounds` etiketleri [Muhtemel] → [Kesin] (V8, V13).
2. §3.2 Katman 1 `.playAndRecord` + kilitliyken niyetle başlatma birlikte riskli (V7). Öneri: niyet `.playback` ile başlatsın; dinleme penceresi (v1.1) için kategori geçişi ayrıca test edilsin.
3. Ürün niyetlerinde `openAppWhenRun` kullanılmasın; iOS 26+ `supportedModes = .background` (V4, V6).
4. `Library/Sounds` dosyası `FileProtectionType.completeUntilFirstUserAuthentication` (veya daha gevşek) ile yazılmalı; `.complete` korumalı dosya kilitliyken okunamaz [Muhtemel] → (d)'de ölçülür.
5. K2 boşluğu (ADR-0003): 64 bildirim ürün planıyla ~12 sa. (d) ve (i) bu boşluğu ölçer (§d, §i, §3).
6. Yeni aday: AlarmKit (§i). ADR-0003 "aday ek mekanizma" maddesi spike (i) sonucuyla güncellenmeli.
7. iOS 27 ayrı alarm/bildirim ses düzeyleri, R5'i (kısık ses) yeni bir yüzeye taşıyor; Hazırlık kontrolü yalnız `outputVolume` okumakla yetinemeyebilir (§f).

## 2. Ortak kurallar

- **Yasaklar:** sessiz ses çalarak canlı kalma, özel API, `MPVolumeView` ile programatik ses değiştirme. Spike'larda her çerçeve gerçek, duyulabilir chirp'tür (`Spikes/Shared/ChirpWaveform.swift`, signal-v0 düzenine yaklaşık, normatif değil). Çerçeveler arası sessizlik, oturumun kesintisiz kalması içindir (BLUEPRINT §3.2); App Review notunda açıklanır.
- **Kulak güvenliği (R9):** aralık alt sınırı 10 s (Ton/I ≈ %9,9 ≤ %12). Bildirim/alarm sesi 25 s'de 3 çerçeve (60 s'de ≈ %5). Kazanç 1,0 ölçülmemiş = açık risk: testlerde telefon kulaktan ≥ 1 m, tezgâh testi kutuda, test eden kişide kulak koruyucu.
- **Kilit kanıtı:** cihazda parola açık. Log satırındaki `protectedData=false` + `appState=background` "kilitli ve uygulama önde değil" kanıtıdır (`protectedDataWillBecomeUnavailable` kilitten ~10 s sonra gelir; testte kilitten sonra ≥ 15 s bekle).
- **Zaman:** her log satırı duvar saati (UTC, ms) + monotonik saat (`CLOCK_MONOTONIC`) içerir. Harici kayıt cihazının saati telefonla aynı NTP kaynağına eşitlenir; kayıt başında ekranda saat gösterilir.
- **Kanıt seti:** (1) harici kamera + mikrofon kaydı (ekran + duyulabilir ses), (2) spike TSV log'u, (3) sysdiagnose (sesi aç + sesi kıs + yan tuş ~1 s; Mac'te `xcrun devicectl` ile alın), (4) gerekiyorsa Instruments izi (`os_signpost` "spike-event", "intent-perform", "engine-start"; Power Profiler), (5) MetricKit JSON (yalnız uzun koşular). Dosyalar paylaşılan sürücüde; repoya yol + SHA-256 yazılır.
- **Kesinti matrisi (K-matrisi):** ilgili spike'larda uygulanır, her satır ayrı deneme:
  | Kod | Kesinti | Nasıl |
  |---|---|---|
  | K-ara | Gelen telefon araması (kabul et / reddet / cevapsız) | İkinci telefondan hücresel veya FaceTime Audio |
  | K-siri | Siri çağrısı | "Hey Siri, saat kaç" |
  | K-ses | Başka uygulamanın sesi | Müzik / YouTube başlat, 60 s sonra durdur |
  | K-kulak | Kulaklık | AirPods bağla/ayır; kablolu (USB-C/Lightning adaptör) tak/çıkar |
  | K-lpm | Düşük Güç Modu | Kontrol Merkezi'nden aç/kapat |
  | K-term | Termal | Xcode › Devices › Device Conditions › Thermal State: Fair/Serious/Critical (gerçek cihazda çalışır) |
  | K-bellek | Bellek baskısı | Kamera 4K60 kayıt + ağır oyun + 20 Safari sekmesi art arda (cihazda "Simulate Memory Warning" yok; `memory_warning` olayı aranır) |
  | K-alarm | Saat uygulaması alarmı / AlarmKit alarmı | 2 dk sonraya alarm |
  | K-kamera | Mikrofonu başka uygulama alır | Kamera'da video kaydı 30 s |
  | K-zorla | Zorla kapatma | Uygulama değiştiriciden yukarı kaydır |
  | K-reboot | Yeniden başlatma | Kapat-aç, ilk kilit açmadan önce ve sonra gözle |

## 3. Spike'lar

### (a) Eylem Düğmesi → `AudioPlaybackIntent`, kilitliyken

- **Hipotez:** iPhone 15 Pro+ cihazda Eylem Düğmesi'ne atanmış `StartBeaconIntent` (`AudioPlaybackIntent`, `.alwaysAllowed`, `openAppWhenRun` yok / iOS 26+ `supportedModes = .background`) kilitli cihazda parola istemeden, uygulamayı öne getirmeden ≤ 2 s içinde duyulabilir işaret başlatır ve işaret kilitliyken sürer.
- **Besler:** K1 (1 hareket), F0 kapısı #4.
- **Mevcut bilgi:** V1–V4 [Kesin]; V6–V7 risk [Muhtemel]. Kilitliyken davranış belgelerde açıkça vaat edilmiyor → spike gerekli.
- **Hedef:** `SpikeA_ActionButtonIntent` (+ `Shared/Intents/BeaconIntents.swift`).
- **Info.plist / entitlement:** `UIBackgroundModes = [audio]`, `NSMicrophoneUsageDescription` (yalnız playAndRecord varyantı). Entitlement gerekmez (App Shortcuts için SiriKit entitlement'ı gerekmez [Muhtemel]).
- **Cihaz/iOS:** iPhone 15 Pro (iOS 26.x son + iOS 27.1), iPhone 16/17 (iOS 27.1). En az 2 model × 2 iOS. iOS 17'de Eylem Düğmesi yalnız Kestirme ile; 17.x cihaz bulunursa 1 deneme.
- **Prosedür:**
  1. Uygulamayı kur, bir kez aç (ilk açılış; niyet meta verisi kaydolur), varyant `playback`, aralık 10 s, kazanç 0,5 → kaydet.
  2. Ayarlar › Eylem Düğmesi › Kestirme › "SV A" › "Sinyali başlat".
  3. Uygulamayı arka plana al, kilitle, 15 s bekle. Harici kamerayı başlat.
  4. Eylem Düğmesi'ne bas-tut. Gözle: parola/Face ID istemi, uygulamanın açılması, ilk çerçevenin duyulduğu an.
  5. 5 dk kilitli bekle; çerçeveler sürmeli. "Sinyali durdur" (Kestirmeler'den) ile durdur.
  6. Tekrarla: varyant `playAndRecord` (V7), `playbackMix`.
  7. Tekrarla: uygulama **zorla kapatılmışken** (K-zorla) ve **yeniden başlatma sonrası ilk kilit açmadan önce** (K-reboot; beklenti: dosya koruması nedeniyle başarısız olabilir, sonuç yazılır) ve sonra.
  8. Eylem Düğmesi › Denetimler ile Spike B'nin kontrolünü ata ve 3–5'i tekrarla (iOS 18+).
  9. K-matrisi: K-ara, K-siri, K-ses, K-kulak, K-lpm (işaret çalarken).
- **Ölçülecekler:** tetik→ilk çerçeve gecikmesi (video, ±50 ms), istem var/yok, `intent_perform` satırındaki `protectedData`/`appState`, 5 dk'da çerçeve sayısı (beklenen ≈ 30), kesinti sonrası `engine_restarted`.
- **Geçti:** 10/10 denemede parola istemi olmadan, uygulama açılmadan, ≤ 2 s içinde duyulabilir çerçeve ve 5 dk kesintisiz; en az `playback` varyantında. **Kaldı:** herhangi bir istem veya sessiz başarısızlık > 1/10.
- **Kanıt:** video (kilit ekranı görünür + ses), TSV log, sysdiagnose (bir başarılı + her başarısız deneme), Instruments `intent-perform` aralığı.
- **App Review riski:** Düşük (Apple'ın amaçladığı kullanım). `.alwaysAllowed` durdurma niyeti kötüye kullanıma açık → ürün K7 ile uygulama içi.
- **Süre:** 0,5 gün / cihaz.

### (b) Kilit ekranı / Kontrol Merkezi kontrolü + kimlik doğrulama politikası

- **Hipotez:** `ControlWidgetButton(action: StartBeaconIntent())` kilit ekranı köşesinden/Kontrol Merkezi'nden `.alwaysAllowed` iken kilitliyken çalışır; `.requiresAuthentication` varyantı Face ID/parola ister.
- **Besler:** K1 (2 hareket), F0 kapısı #4.
- **Mevcut bilgi:** V2, V3, V5 [Kesin]; V6 risk. BLUEPRINT tetik tablosunda "[Tahmin] ayara bağlı".
- **Hedef:** `SpikeB_LockScreenControl` + uzantı `SpikeB_LockScreenControlWidgets` (iOS 18.0, `WIDGET_EXTENSION` koşulu).
- **Info.plist:** uygulama `UIBackgroundModes = [audio]`; uzantı `NSExtensionPointIdentifier = com.apple.widgetkit-extension`. Entitlement/App Group gerekmez (niyet uygulama sürecinde çalışır, V3).
- **Cihaz/iOS:** iOS 18 (iPhone XR/XS veya 12), iOS 26.x, iOS 27.1; en az 3 cihaz. iOS 17: kontrol yok → Back Tap + Kestirme yedek yolu 1 deneme.
- **Prosedür:**
  1. Kur, uygulamayı bir kez aç. Kilit ekranı › Özelleştir › sol köşe "SV başlat (her zaman)", sağ köşe "SV başlat (kimlik)". Kontrol Merkezi'ne "SV durdur".
  2. Kilitle, 15 s bekle, kamera başlat. Sol köşeye basılı tut → gözlem (istem? gecikme? ses?).
  3. Durdur, sağ köşe ile tekrarla; Face ID istemi beklenir. Face ID'yi reddet → ses başlamamalı.
  4. Kontrol Merkezi'nden (kilitliyken) başlat.
  5. Ayarlar › Face ID ve Parola › "Kilitliyken erişime izin ver" altındaki **Kontrol Merkezi** anahtarı kapalı/açık ile 2–4'ü tekrarla (BLUEPRINT "ayara bağlı" iddiası).
  6. Uzantı, uygulama zorla kapatılmışken ve yeniden başlatma sonrası (ilk kilit açma öncesi/sonrası).
  7. K-matrisi: K-ara, K-ses, K-lpm.
- **Ölçülecekler:** hareket sayısı (K1: ≤ 2), istem, gecikme, `intent_perform` içinde `intent=StartBeaconIntent/alwaysAllowed` ve `protectedData=false`.
- **Geçti:** `.alwaysAllowed` kontrol 10/10 kilitliyken istemsiz başlatır ve `.requiresAuthentication` 10/10 kimlik ister (politikanın gerçekten uygulandığını gösterir). **Kaldı:** `.alwaysAllowed` iken istem.
- **Kanıt:** video, TSV log, kilit ekranı ayar ekran görüntüleri, sysdiagnose.
- **App Review riski:** Düşük.
- **Süre:** 0,5 gün / cihaz.

### (c) 72 saat arka plan ses (+ mikrofon), ekran kapalı

- **Hipotez:** `UIBackgroundModes: audio` + ön planda etkinleştirilmiş, hiç kapatılmayan oturumla `AVAudioEngine` 10 s'de bir duyulabilir çerçeve çalmayı ≥ 72 sa (veya pil bitene kadar) sürdürür; sistem uygulamayı sonlandırmaz. Kesintilerden sonra motor yeniden başlar.
- **Besler:** K3, F0 kapısı #3, F0-5 (pil tezgâhı ile birleştirilebilir; pil eğrisi `heartbeat.battery`).
- **Mevcut bilgi:** V15 [Muhtemel]; iOS 26.5'te ~50 s'de SIGKILL raporu var (DTS: ses sistemi kaynaklı değil, crash log'a bakın) → sistem günlüğü (runningboardd) zorunlu kanıt. V23 Düşük Güç Modu etkisi doğrulanamadı.
- **Hedef:** `SpikeC_BackgroundAudio72h` (+ `MetricsSink`, `RunMarker`).
- **Info.plist:** `UIBackgroundModes = [audio]`, `NSMicrophoneUsageDescription`.
- **Cihaz/iOS:** iPhone 12, 13, 15 (F0-5 ile aynı); iOS 26.x ve 27.1 (en az bir cihaz her birinde). Her cihazda: koşu-1 `playback` 10 s; koşu-2 `playAndRecord` 10 s; koşu-3 ürün görev döngüsü yaklaşımı (`playback`, 20 s).
- **Prosedür:**
  1. %80 şarj, Düşük Güç Modu açık, SIM yok/Uçak Modu (F0-5 koşulu ile hizalı), ses %100, kazanç 1,0 (kutuda) veya 0,5 (masada).
  2. Uygulamayı aç, Başlat, ilk `heartbeat` satırını gör, kilitle. Şarjdan ayır. Saat yaz.
  3. İlk 1 saat: K-matrisinin hepsi, aralarında ≥ 5 dk (K-ara, K-siri, K-ses, K-kulak, K-lpm kapat/aç, K-term Serious 10 dk, K-bellek, K-alarm, K-kamera [yalnız playAndRecord]).
  4. Sonra dokunmadan bırak. Harici kayıt cihazı (ses seviyesi kaydedici veya ikinci telefon + FieldRecorder) çerçeveleri sayar.
  5. Bitiş: pil bitti / 72 sa / uygulama öldü. Uygulamayı aç (`previous_run_unclean`?), log + MetricKit klasörünü paylaş, sysdiagnose al.
  6. Ek koşu: uygulama arka plandayken K-zorla → işaretin bittiğini ve Katman 2'ye (d/i) devrin gerektiğini belgele.
- **Ölçülecekler:** hayatta kalma süresi (sa), `framesEmitted` / beklenen (≥ %99), kesinti sonrası yeniden başlama süresi ve başarısızlıklar, %/sa pil, termal geçişler, MetricKit `backgroundExitData` sayaçları, runningboardd sonlandırma nedenleri.
- **Geçti:** 3 cihazdan ≥ 2'sinde ≥ 72 sa (pil yetmezse pil bitene kadar) sistem sonlandırması yok ve çerçeve kaybı < %1; her K-matrisi satırından sonra ≤ 30 s içinde çalma geri gelir (telefon araması hariç: arama bitince). **Kaldı:** herhangi bir sistem sonlandırması → nedeni log ile, F0 kapısı #3 Katman 2 koluna düşer.
- **Kanıt:** TSV log (60 s kalp atışı), MetricKit JSON, sysdiagnose, harici ses kaydı (en az ilk/son 1 sa), pil eğrisi grafiği.
- **App Review riski:** Orta (R4). Gerekçe: gerçek, duyulabilir, kullanıcı başlatmalı işaret; not + video.
- **Süre:** 3,5 gün duvar saati × paralel cihazlar; 1 sa kurulum / koşu.

### (d) 64 yerel bildirim zinciri + `Library/Sounds`

- **Hipotez:** Etkinleştirmede planlanan 64 yerel bildirim, uygulama zorla kapatılsa da zamanında, `Library/Sounds`'a çalışma anında yazılmış 25 s işaret sesiyle çalar. 31 s dosya varsayılan sese düşer. 65+. istek tutulmaz.
- **Besler:** K2, F0 kapısı #3 (Katman 2 kolu), R5 (kritik varyant).
- **Mevcut bilgi:** V8, V9, V11 [Kesin]; V10, V12 [Muhtemel]. Kritik varyant entitlement onayı olmadan imzalanamaz → onay gelene kadar `normal` ve `timeSensitive` ölçülür.
- **Hedef:** `SpikeD_NotificationChain`.
- **Info.plist / entitlement:** `UIBackgroundModes = [audio, fetch]`, `BGTaskSchedulerPermittedIdentifiers = [sesver.spike.d.refresh]`; `SpikeD.entitlements` (time-sensitive). Onay gelince `SpikeD-Critical.entitlements`.
- **Cihaz/iOS:** iPhone 12 ve 15 Pro; iOS 26.x ve 27.1.
- **K2 boşluğu (ADR-0003):** ürün planı (24×5 dk + 40×15 dk) yalnız **12 sa** kapsar; K2 **24 sa** ister. Spike bunu üç yoldan ölçer/kapatır:
  1. **Seyrekleştirme:** `product24` planı = 12×5 dk + 12×15 dk + 40×30 dk = **24 sa** (64 istek). Ölçüt: 24 sa'te 64/64 teslim. Bedel: 4.–24. saatte boşluklar 30 dk.
  2. **Canlanmayla yeniden doldurma:** `BGAppRefreshTask` (`sesver.spike.d.refresh`, en erken 30 dk) her çalıştığında zinciri yeniden doldurur; `bg_refresh_run` olaylarının sıklığı ölçülür. [Muhtemel] Zorla kapatılmış uygulamada çalışmaz; ayrıca ölçülür.
  3. **AlarmKit ile ek kapsama:** (i)'deki 24×60 dk serisi 12–36. saatleri kaplar; ikisi birlikte 64 + N istek.
  Sonuç tablosu: her yol için "uygulama zorla kapatılmış / kapatılmamış" × "kapsanan saat" × "en uzun boşluk".
- **Prosedür:**
  1. İzin iste (normal). "Library/Sounds dosyalarını yaz". Ses = Library 25 s, düzey = normal, plan = Hızlı (64×1 dk). Planla → `chain_status pending=64`.
  2. Zorla kapat, kilitle, sessiz anahtar **kapalı**, kamera ile 64 dk kaydet (ya da örnekle: ilk 10 + son 5). Her bildirimde sesin süresini ölç (ilk ses → son çerçeve).
  3. Taşma planı (70×10 dk) → `pending` sayısı (beklenen 64) ve hangi kimliklerin atıldığı.
  4. 31 s dosya ile 3 bildirim → varsayılan ses mi?
  5. Paket 25 s vs Library 25 s; ikisi aynı adla varsa Library kazanır mı (V8).
  6. Dosya koruması: kilitliyken, yeniden başlatma sonrası ilk kilit açma öncesi bildirim sesi çalıyor mu (BLUEPRINT önerisi 4).
  7. `product24` planı, zorla kapatılmış, 24 sa; teslim listesi ertesi açılışta `chain_status deliveredList` + Bildirim Merkezi ekran görüntüsü.
  8. `product` (12 sa) planı + uygulama arka planda (zorla kapatılmamış) 24 sa → `bg_refresh_run` sayısı.
  9. Sessiz anahtar açık, ses %10, Odak/Rahatsız Etme açık, Uyku Odağı, Bildirim Özeti: normal / timeSensitive (/ critical) her biri için duyuldu mu?
  10. Katman 1 + 2 etkileşimi: Spike D'de işaret sesini de başlat, "En yakını 5 dk ileri kaydır" → iki katman üst üste çaldı mı?
  11. K-matrisi: K-ara (bildirim anında arama), K-ses, K-kulak (ses kulaklığa mı gidiyor?), K-lpm, K-reboot.
- **Ölçülecekler:** teslim oranı ve zamanlama sapması (s), çalınan ses süresi, düşme davranışı (31 s), `pending` tavanı, sessiz/Odak altında duyulabilirlik matrisi, en uzun kapsamasız aralık, BG yenileme sıklığı.
- **Geçti:** zorla kapatılmış uygulamada 64/64 zamanında (±60 s) ve 25 s özel ses çalar; `product24` 24 sa kapsar. **Kaldı:** teslim < 64 veya Library sesi düşer. Kritik olmayan düzeyde sessiz anahtar açıkken duyulmaması **beklenen** sonuçtur (R3/R5 kaydı), kaldı sayılmaz.
- **Kanıt:** video (örneklenmiş), TSV log, Bildirim Merkezi ekran görüntüleri, sysdiagnose (`usernotificationsd` satırları).
- **App Review riski:** Düşük (normal) / Orta (kritik: kapsam gerekçesi ister; zaman duyarlı kötüye kullanım uyarısı).
- **Süre:** 1 gün çalışma + 24 sa duvar saati.

### (e) Arka planda BLE reklamı

- **Hipotez:** Kurban cihaz arka planda/kilitliyken `bluetooth-peripheral` moduyla servis UUID'sini overflow alanında yayınlar; kurtarıcı iPhone ön planda o UUID'yi tarayarak ≤ 10 s'de bulur, bağlanır ve GATT'tan 32 bit yükü okur.
- **Besler:** §3.2 BLE, §3.4.1 BLE taraması, K6 (dolaylı).
- **Mevcut bilgi:** V13 [Kesin]; V24 aralık doğrulanamadı.
- **Hedef:** `SpikeE_BLEAdvertising` (aynı uygulama, iki rol).
- **Info.plist:** `UIBackgroundModes = [audio, bluetooth-peripheral, bluetooth-central]`, `NSBluetoothAlwaysUsageDescription`. Durum geri yükleme kimliği `sesver.spike.e.peripheral`.
- **Cihaz/iOS:** 2 iPhone (ör. 12 reklamcı, 15 Pro tarayıcı) + çapraz; iOS 26.x/27.1.
- **Prosedür:**
  1. Reklamcı: reklamı başlat (ön plan) → tarayıcı: tara; `ble_first_seen svcInMain=true name=SV-7F2` beklenir.
  2. Reklamcıyı arka plana al + kilitle → tarayıcıda `svcInOverflow=true`, `name=-` ve ilk görülme gecikmesi.
  3. Aynısını reklamcıda işaret sesi çalarken (canlı Katman 1) ve çalmazken (yalnız BLE modu) tekrarla; 1 sa izle.
  4. Mesafe: 1, 5, 10, 20 m (açık alan) ve bir duvar arkası; RSSI.
  5. Reklamcı uygulaması zorla kapatılınca reklam biter mi (beklenen: evet); sistem sonlandırırsa durum geri yükleme ile döner mi (`ble_peripheral_restored`).
  6. Tarayıcı iOS olmayan cihaz (Android/nRF Connect) ile overflow görünmez mi (bilgi amaçlı).
  7. K-matrisi: K-lpm, K-term.
- **Ölçülecekler:** ilk tespit gecikmesi, tespit sürekliliği (1 sa'te görülme aralıkları), RSSI-mesafe, bağlanıp okuma başarısı, pil etkisi (c ile karşılaştır).
- **Geçti:** kilitli reklamcı ≥ 10 m'de 10/10 denemede ≤ 10 s'de bulunur ve yük okunur. **Kaldı:** kilitliyken bulunamaz.
- **Kanıt:** iki cihazın TSV log'u, ekran kaydı (tarayıcı), sysdiagnose (reklamcı, `bluetoothd`).
- **App Review riski:** Düşük–Orta (`bluetooth-peripheral` gerekçesi ister).
- **Süre:** 0,5 gün.

### (f) `outputVolume` okuma

- **Hipotez:** `AVAudioSession.outputVolume` medya ses düzeyini doğru yansıtır, KVO ile değişimler gelir; sessiz anahtarını ve iOS 27'deki ayrı zil/alarm/bildirim düzeylerini yansıtmaz.
- **Besler:** R5, §0.4 (ses düzeyi kontrolü), Hazırlık ekranı.
- **Mevcut bilgi:** V14 [Kesin]; V21 doğrulanamadı. [Muhtemel] Oturum etkin değilken değer bayat olabilir → ölçülür.
- **Hedef:** `SpikeF_OutputVolume`.
- **Info.plist:** `UIBackgroundModes = [audio]`.
- **Cihaz/iOS:** iPhone 12 (iOS 26), 15 Pro (iOS 27.1), XR (iOS 18).
- **Prosedür:** KVO başlat → oturum kapalıyken düğmelerle ses değiştir, oku → oturumu etkinleştir, tekrarla → sessiz anahtar/Sessiz mod aç-kapat → AirPods/kablolu kulaklık → iOS 27: Ayarlar'daki alarm ve bildirim kaydırıcılarını ayrı ayrı değiştir, her adımda "Şimdi oku ve etiketle".
- **Ölçülecekler:** her durumda değer ve gerçek (tuş adımı), KVO gecikmesi, etkin değilken bayatlık.
- **Geçti:** oturum etkinken değer ±1 adım doğruluğunda ve KVO ≤ 1 s. **Kaldı:** oturum etkinken bile yanlış. İOS 27 kaydırıcılarının bağımsızlığı ayrıca raporlanır (Hazırlık ekranı gereksinimine girdi).
- **Kanıt:** TSV log, ekran kaydı.
- **App Review riski:** Yok (MPVolumeView yalnız kullanıcı kaydırıcısı).
- **Süre:** 0,25 gün.

### (g) Gece Nöbeti siyah ekran güç tüketimi

- **Hipotez:** Ön planda siyah ekran (OLED pikselleri kapalı) + soluk saat + `isIdleTimerDisabled` + 50 Hz ivmeölçer + STA/LTA ≈ 0,3–0,5 W [Tahmin]; şarjdayken önemsiz, şarjsız %/sa ölçülür.
- **Besler:** v1.1 Gece Nöbeti kararı (F3-5), STA/LTA ilk veri (F3-6).
- **Mevcut bilgi:** yalnız BLUEPRINT tahmini. Belge yok.
- **Hedef:** `SpikeG_NightWatchPower` (işaret çalmaz; tetiği yalnız loglar).
- **Info.plist:** `UIStatusBarHidden`. Ham ivmeölçer için izin anahtarı gerekmez [Muhtemel].
- **Cihaz/iOS:** iPhone 12 (OLED), 13, 15; iOS 26/27. (LCD'li SE varsa karşılaştırma.)
- **Prosedür:** (1) %100, şarjdan ayır, tezgâh modu, parlaklık en düşük, Otomatik Parlaklık kapalı, 2 sa → %/sa. (2) Aynı cihazda kontrol koşusu: ekran kilitli boşta 2 sa. (3) Instruments › Power Profiler ile 10 dk iz (ekran, CPU, sensör). (4) Şarjda 8 gece saati koşu: termal durum + `sta_lta_trigger` sayısı (yanlış pozitif tabanı). (5) Masaya vur, kapı çarp, yatağa düş, kamyon geçişi kaydı → tetik oranları. K-matrisi: K-term, K-lpm, K-ara (gelen arama ekranı öne çıkar mı).
- **Ölçülecekler:** W (Power Profiler), %/sa (fark), gece boyu tetik sayısı, termal.
- **Geçti:** şarjsız ≤ %3/sa ve 8 sa gecede termal ≥ serious yok. **Kaldı:** üstü → Gece Nöbeti tasarımı yeniden.
- **Kanıt:** Instruments izi, TSV log, pil eğrisi.
- **App Review riski:** Orta (ekranı sürekli açık tutan ön plan modu; yalnız şarjda açılması gerekçe).
- **Süre:** 0,5 gün + 1 gece.

### (h) Siri internetsiz

- **Hipotez:** Uçak Modu'nda (Wi-Fi/Bluetooth kapalı) "Ses Ver başlat" (TR) / "Start Ses Ver" (EN) ifadesi `StartBeaconIntent`'i çalıştırır; kilitliyken de.
- **Besler:** K1 yedek yol, BLUEPRINT tetik tablosu ([Tahmin] → ölçüm).
- **Mevcut bilgi:** V22: A12+ cihaz üstü Siri, "uygulama açma" çevrimdışı; App Shortcuts + Türkçe çevrimdışı doğrulanamadı.
- **Hedef:** `SpikeH_SiriOffline` (görünen ad "Ses Ver", geliştirme dili `tr`, `en.lproj/AppShortcuts.strings`).
- **Info.plist:** `UIBackgroundModes = [audio]`, `CFBundleDevelopmentRegion = tr`.
- **Cihaz/iOS:** iPhone XR/XS (A12, iOS 18), iPhone 15 Pro (iOS 27.1, Apple Intelligence açık/kapalı), Siri dili TR ve EN.
- **Prosedür:** Kur, bir kez aç (App Shortcuts kaydı). Çevrimiçi kontrol denemesi → Uçak Modu + Wi-Fi kapalı → `network_path status=unsatisfied` log'da → kilitliyken "Hey Siri" + yan tuş ile her ifade 5'er kez. TR ve EN. "Ses Ver" ile çakışan başka uygulama adı olmamalı (diğer spike'lar "SV x"). K-lpm.
- **Ölçülecekler:** başarı oranı, Siri'nin istediği onay/kilit açma, gecikme.
- **Geçti:** çevrimdışı, kilitliyken ≥ 8/10 (en az bir dilde). **Kaldı:** çevrimdışı hiç çalışmıyorsa tetik tablosunda "internet gerekir" yazılır.
- **Kanıt:** video (ekran + Siri yanıtı + ses), TSV log (ağ durumu + `intent_perform`).
- **App Review riski:** Düşük.
- **Süre:** 0,5 gün.

### (i) AlarmKit (yeni)

- **Hipotez:** AlarmKit ile planlanan sabit tarihli alarmlar, uygulama zorla kapatılmış olsa da sessiz anahtar ve Odak'ı aşarak özel işaret sesini çalar; Critical Alerts onayı gelmezse (R3) Katman 2'yi güçlendirir ve K2 boşluğunu (12→24+ sa) kapatmaya yeter sayıda planlanabilir.
- **Besler:** K2, R3, R5, F0 kapısı #3; ADR-0003 "aday ek mekanizma".
- **Mevcut bilgi:**
  - [Kesin] iOS 26+, Odak + sessiz modu aşar, kullanıcı izni şart, Ayarlar'dan geri alınabilir (V16).
  - [Kesin] ses: paket veya `Library/Sounds`, `AlertSound.named`; `.fixed(Date)` planı (V17).
  - [Muhtemel] ses < 30 s, döngü yok (bir kez çalar); `Library/Sounds` varsayılana düşüyor (açık hata) (V19).
  - **Doğrulanamadı:** planlanabilecek alarm sayısı (yalnız `maximumLimitReached` hatası var), alarm UI'ının kendiliğinden ne zaman sustuğu, iOS 27 ayrı alarm ses düzeyinin AlarmKit'e etkisi (V21).
  - [Kesin] Apple'ın beyanı: alarmlar kritik/zaman duyarlı bildirimlerin yerine geçmez (V18) → **App Review riski Yüksek** (ürün kullanımı "zamanlayıcı/alarm" çerçevesine sığmalı: "işaretin tekrar çalacağı zamanlar"; kullanıcı açıkça başlatır).
  - [Muhtemel] iOS 27 gerilemeleri (V20).
- **Hedef:** `SpikeI_AlarmKit` (iOS 26.0; geri sayımlı alarm kullanılmadığı için Live Activity uzantısı yok).
- **Info.plist:** `NSAlarmKitUsageDescription` (boşsa planlama yapılamaz), `NSSupportsLiveActivities`, `UIBackgroundModes = [audio]`. Entitlement gerekmez [Kesin, belgede yok].
- **Cihaz/iOS:** iPhone 15 Pro ve 12; iOS 26.x son ve 27.1 (V20 için ikisi şart). Apple Watch eşli/eşsiz (alarm saate de gider).
- **Prosedür:**
  1. İzin iste → kabul/ret; ret sonrası planlama hatası log'u.
  2. Tek alarm 2 dk (paket 25 s): kilitli, sessiz anahtar açık, ses %10, Rahatsız Etme açık → duyuldu mu, ne kadar çaldı (kamera), kilit ekranında hangi UI, durdurmak için ne gerekti.
  3. Ses varyantları: Library 25 s, Library 31 s, varsayılan → varsayılana düşüyor mu, döngü var mı.
  4. Zorla kapatılmış uygulama + kilitli: seri 6×2 dk → 6/6 çaldı mı. Yeniden başlatma sonrası (ilk kilit açma öncesi/sonrası) 1 alarm.
  5. **Limit testi:** 500 × 30 dk (yarından itibaren) → `alarm_schedule_failed … maximumLimitReached` hangi indekste; `totalNow`.
  6. **K2 boşluğu:** (d) `product` (12 sa) zinciri + burada 24×60 dk seri (12.–36. sa) → zorla kapatılmış cihazda 36 sa boyunca kapsama tablosu (d §K2 ile ortak sonuç).
  7. iOS 27.1: Ayarlar'da alarm düzeyi en düşük, medya en yüksek → alarm duyuldu mu? (V21)
  8. Katman 1 çalarken alarm (K-alarm): `audio_interruption_began/ended` ve motor geri geldi mi.
  9. Panik bağlamı: alarm UI'ı açıkken telefona dokunulmazsa ne kadar sürede susuyor; susunca sonraki alarm çalıyor mu.
  10. K-matrisi: K-ara (alarm anında arama), K-kulak (ses kulaklığa mı?), K-lpm.
- **Ölçülecekler:** duyulabilirlik matrisi (sessiz/Odak/düşük alarm sesi), çalma süresi ve döngü, planlanabilen alarm sayısı, zorla kapatma/yeniden başlatma sonrası teslim, iOS 26 vs 27 farkı.
- **Geçti:** zorla kapatılmış ve sessiz modda 6/6 alarm zamanında özel sesle çalar ve limit ≥ 24 → "Katman 2 eki olarak aday". **Kaldı:** sessiz modda duyulmaz veya limit < 24 veya özel ses çalınamaz (varsayılan ses kabul edilebilir mi → sinyal verisi taşımaz; yalnız insan için işaret).
- **Kanıt:** video, TSV log (`alarm_updates`, `alarm_series_scheduled`), sysdiagnose, kilit ekranı ekran görüntüleri.
- **App Review riski:** **Yüksek** (V18). Ürüne alınırsa: kullanıcı onaylı, Hazırlık ekranında açıklanan, ayrı izinli, "işaretin kendiliğinden tekrar çalacağı zamanlar" olarak; `safety-redteam` + `release` incelemesi şart.
- **Süre:** 1 gün çalışma + 36 sa duvar saati.
- **Katman 2'ye olası etki:** (1) Critical Alerts reddedilirse sessiz anahtarı aşan tek resmî yol olabilir (R3 yedeği). (2) Bildirim sınırına (64) ek kapasite verir (sayı ölçülecek). (3) Ancak alarm UI'ı tam ekran ve kullanıcı etkileşimi bekler; ses verisi (CSS yükü) korunur mu ölçülecek; iOS 27'de ayrı alarm ses düzeyi kullanıcı tarafından kısılabilir (R5 yeni yüzey).

## 4. Yürütme sırası (kritik yol önce)

| Gün | İş | Neden |
|---|---|---|
| 0 | **F0-8 Critical Alerts başvurusu insan onayıyla gönderilsin** (bu belge göndermez) | Onay süresi en uzun belirsizlik |
| 1 | (a), (b) — 15 Pro + 12 + XR | F0 kapısı #4 |
| 1 (akşam) | (c) koşu-1 üç cihazda başlat (F0-5 ile birlikte) | 72 sa duvar saati, kapı #3 |
| 2 | (d) hızlı + taşma + 31 s; akşam `product24` 24 sa koşusu | Kapı #3 alternatif kolu, K2 boşluğu |
| 2–3 | (i) 1–5. adımlar; akşam (d)+(i) 36 sa birleşik kapsama koşusu | R3 yedeği |
| 3 | (h), (f) | Hızlı, yan yollar |
| 4 | (e) | İki cihaz gerekir |
| 4 (gece) | (g) | Bir gece |
| 5 | (c) koşu-2 (playAndRecord), sonuç dosyaları, kapı özeti | |

Kapı kararı için en az: (a) veya (b) EVET; (c) EVET **veya** [(d) `product24` EVET (+ isteğe bağlı (i))].

## 5. Gerekli cihazlar

| Cihaz | iOS | Kullanım |
|---|---|---|
| iPhone 15 Pro (veya 16/17 Pro) | 27.1 | (a) Eylem Düğmesi, (b), (d), (h, Apple Intelligence), (i) |
| İkinci Eylem Düğmeli iPhone (15 Pro / 16 / 17) | 26.x son | (a), (i) iOS 26 karşılaştırması |
| iPhone 12 | 26.x | (c) + F0-5 pil, (d), (e), (g), (i) |
| iPhone 13 | 26.x veya 27.1 | (c) + F0-5 pil, (g) |
| iPhone 15 (Pro olmayan) | 27.1 | (c) + F0-5 pil |
| iPhone XR veya XS (A12) | 18.x | (b) iOS 18 kontrolleri, (f), (h) en düşük Siri cihazı |
| iOS 17'de kalmış herhangi bir iPhone (varsa) | 17.x | iOS 17 yedek yollar (Kestirme + Back Tap) |
| Tarayıcı iPhone (herhangi) | 26+ | (e) |
| Harici: kamera + mikrofon, ses seviyesi ölçer, metal kutu, ikinci telefon (arama), AirPods + kablolu kulaklık | | Kanıt ve K-matrisi |

Tüm cihazlarda parola açık; Apple Developer hesabında cihazlar kayıtlı; Geliştirici Modu açık.

## 6. F0-8 Critical Alerts başvurusu: gerekçe taslağının ana noktaları

> **Başvuru gönderilmez.** Metin `release` + insan onayı ile hazırlanır; mağaza dili `safety-redteam` onayından geçer ("hayat kurtarır", "garanti" yok).

1. **Kullanım alanı:** Kamu güvenliği / acil durum. Deprem sonrası enkaz altında kalan kullanıcının telefonu, kullanıcı tek hareketle başlattıktan sonra periyodik akustik işaret verir; kurtarıcılar kulakla ve uygulamayla bulur.
2. **Neden kritik uyarı:** Uygulama sistem tarafından sonlandırılırsa veya pil koruması devreye girerse işaret yerel bildirim zinciriyle sürer. Enkaz altındaki kişi telefonun sesini/sessiz anahtarını ayarlayamayabilir; normal bildirim sesi sessiz anahtarında duyulmaz → işaret yok olur.
3. **Kapsam ve sınır:** Yalnız kullanıcı işareti açıkça başlattığında, yerel (sunucusuz) bildirimler; pazarlama/genel bildirim yok. Kullanıcı durdurunca tüm zincir iptal. Sayı ≤ 64, sesler ≤ 30 s, görev döngüsü ≤ %12 (kulak güvenliği).
4. **Kullanıcı denetimi:** Hazırlık ekranında açık izin akışı, Ayarlar'dan kapatılabilir, ilk kullanımda açıklama.
5. **Kanıt (F0 çıktısı eklenir):** (c)/(d) spike sonuçları, saha akustik verisi (F0-4), demo videosu, sesin duyulabilir ve gerçek olduğu.
6. **Kurumsal destek:** AFAD/AKUT/TÜBİTAK MAM teması varsa destek mektubu (BLUEPRINT §0.6) — başvuruyu güçlendirir [Muhtemel].
7. **Gizlilik:** veri toplanmaz, hesap yok, konum sunucuya gitmez.
8. **Alternatiflerin yetersizliği:** zaman duyarlı bildirim sessiz anahtarını aşmaz; AlarmKit Apple'ın beyanıyla kritik uyarının yerine geçmez (V18) — spike (i) sonucu eklenir.

## 7. Açık riskler

- V6/V7: kilitli başlatma istem/oturum hatası → kapı #4'ü düşürebilir.
- V15'in tek dayanağı DTS forum yanıtı; 50 s SIGKILL raporu çözülmemiş.
- V19/V20: AlarmKit özel ses ve iOS 27 gerilemeleri; limit belgesiz.
- V21: iOS 27 ayrı ses düzeyleri kısık ses riskini (R5) çoğaltır.
- Kritik uyarı onay süresi/kapsamı (R3).
- Çerçeveler arası sessizlik içeren sürekli oturum App Review'da "sessiz ses" sanılabilir (R4): not + video şart.
- Spike'larda kazanç 1,0 kulak güvenliği ölçülmeden (signal-v0 §3.5) açık risk.
