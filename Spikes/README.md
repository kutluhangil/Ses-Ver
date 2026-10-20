# Ses Ver · F0-2 iOS spike'ları

Plan, hipotezler, prosedürler ve geçti/kaldı ölçütleri: [`docs/field/spikes/F0-2-plan.md`](../docs/field/spikes/F0-2-plan.md).
Sonuçlar: [`docs/field/spikes/RESULT_TEMPLATE.md`](../docs/field/spikes/RESULT_TEMPLATE.md) kopyalanarak yazılır.

> **Simülatör kanıt değildir.** Her spike gerçek cihazda, parola açıkken koşulur.
> Bu dizin `ios-platform` sahipliğindedir; ürün kodu (`App/`, `Packages/`) değildir.

## Hedefler

| Hedef | Spike | Min. iOS | Not |
|---|---|---|---|
| `SpikeA_ActionButtonIntent` | (a) Eylem Düğmesi → `AudioPlaybackIntent` | 17.0 | App Shortcut "Sinyali başlat/durdur" |
| `SpikeB_LockScreenControl` + `SpikeB_LockScreenControlWidgets` | (b) Kilit ekranı / Kontrol Merkezi kontrolü | 17.0 / uzantı 18.0 | 3 kontrol: her zaman, kimlik, durdur |
| `SpikeC_BackgroundAudio72h` | (c) 72 sa arka plan ses + mikrofon | 17.0 | MetricKit çıkış nedenleri |
| `SpikeD_NotificationChain` | (d) 64 bildirim zinciri + `Library/Sounds` | 17.0 | planlar: Ürün 12 sa, **24 sa**, Hızlı, Taşma; BG yenileme |
| `SpikeE_BLEAdvertising` | (e) arka plan BLE reklamı + tarayıcı | 17.0 | iki cihaz |
| `SpikeF_OutputVolume` | (f) `outputVolume` | 17.0 | |
| `SpikeG_NightWatchPower` | (g) Gece Nöbeti güç | 17.0 | işaret çalmaz |
| `SpikeH_SiriOffline` | (h) Siri internetsiz | 17.0 | görünen ad "Ses Ver", dil `tr` + `en` |
| `SpikeI_AlarmKit` | (i) AlarmKit | **26.0** | Live Activity uzantısı yok (geri sayım kullanılmıyor) |

Ortak kod (`Shared/`):
- `SpikeLog.swift`: TSV olay günlüğü (`Documents/spike-logs/`), unified log (`subsystem: sesver.spike`), `OSSignposter`; `RunMarker` sistem sonlandırmasını bir sonraki açılışta raporlar.
- `ChirpWaveform.swift`: signal-v0 düzenine yaklaşık 1,8→4,2 kHz chirp çerçevesi, WAV yazıcı, `Library/Sounds` yazımı. **Normatif değil.**
- `ChirpEngine.swift`: `AVAudioEngine` + `AVAudioSourceNode`. Render bloğu bellek ayırmaz, kilit almaz, log yazmaz (tüm bellek başlatmadan önce ayrılır). Kesinti/rota/yapılandırma/medya sıfırlama sonrası yeniden başlatma.
- `SystemObservers.swift`: yaşam döngüsü, kilit (korumalı veri), termal, Düşük Güç Modu, bellek, pil olayları; `Heartbeat`; `MetricsSink` (MetricKit).
- `Intents/BeaconIntents.swift`: `StartBeaconIntent` (`.alwaysAllowed`), `StartBeaconAuthIntent` (`.requiresAuthentication`), `StopBeaconIntent`. Uzantıda `WIDGET_EXTENSION` koşuluyla gövdesiz derlenir; sistem bu niyetleri uygulama sürecinde çalıştırır.
- `Sounds/sv_chirp_25s.wav`: paketlenen 25 s ses (22,05 kHz, 3 çerçeve). Yeniden üret: `python3 -I Spikes/Tools/make_sounds.py`.

## Kurulum

```sh
brew install xcodegen
cd Spikes
xcodegen            # project.yml → SesVerSpikes.xcodeproj
open SesVerSpikes.xcodeproj
```

Gereken: Xcode 27.1+ (iPhoneOS 27.1 SDK ile denendi). `xcodegen` bu makinede kurulu olmadığı için `project.yml` henüz üretilip derlenmedi; yalnız Swift tip denetimi yapıldı (aşağıda). İlk `xcodegen` çalıştırmasında hata çıkarsa (ör. `templateAttributes` sözdizimi) hedef başına `sources`/`settings` blokları elle açılabilir.

## İmzalama

1. `project.yml` → `settings.base.DEVELOPMENT_TEAM` = Team ID; `SPIKE_BUNDLE_PREFIX` = kendi önekiniz (ör. `com.<siz>.sesver.spike`). Paket kimlikleri `<önek>.a … .i`, uzantı `<önek>.b.controls`.
2. Otomatik imzalama yeterli. Ücretsiz (kişisel) hesapta: arka plan modları çalışır; **zaman duyarlı bildirim** ve **kritik uyarı** entitlement'ları ücretli üyelik ister.
3. **Critical Alerts:** `SpikeD-Critical.entitlements` yalnız Apple onayı (F0-8) geldikten ve profil yenilendikten sonra `CODE_SIGN_ENTITLEMENTS` olarak seçilir. Onaysız seçilirse imzalama başarısız olur. **Başvuru insan onayı olmadan yapılmaz.**
4. Cihazda: Ayarlar › Gizlilik ve Güvenlik › Geliştirici Modu açık; parola açık (kilit testleri için şart).

## Her spike'ı cihazda çalıştırma (özet; ayrıntı plan §3)

Ortak: uygulamayı Xcode'dan cihaza kurun → bir kez açın (App Intents kaydı ve gözlemciler) → "Ayarları kaydet" → testten sonra "Bu çalıştırmanın logunu paylaş" veya Mac'te:

```sh
xcrun devicectl list devices
xcrun devicectl device copy from --device <UDID> --domain-type appDataContainer \
  --domain-identifier <bundle id> --source Documents/spike-logs --destination ./logs
sudo log collect --device-udid <UDID> --last 2h --output spike.logarchive   # unified log
log show spike.logarchive --predicate 'subsystem == "sesver.spike"'
```

- **A:** Ayarlar › Eylem Düğmesi › Kestirme › "SV A" › "Sinyali başlat". Kilitle, 15 s bekle, bas-tut. Log'da `intent_perform … protectedData=false appState=background` aranır.
- **B:** Kilit ekranını özelleştir → köşelere "SV başlat (her zaman)" ve "SV başlat (kimlik)"; Kontrol Merkezi'ne "SV durdur".
- **C:** varyant + aralık seç → Başlat → kilitle → dokunma. Bitince uygulamayı aç (`previous_run_unclean`), log + `Documents/metrickit` + sysdiagnose.
- **D:** İzin iste → "Library/Sounds dosyalarını yaz" → ses/düzey/plan seç → "Zinciri planla" → zorla kapat, kilitle. Ertesi açılışta `chain_status deliveredList`.
- **E:** iki cihaz: biri "Reklamı başlat" sonra kilitle; diğeri "Taramayı başlat" (ön planda).
- **F:** "KVO başlat", durumları değiştir, "Şimdi oku ve etiketle".
- **G:** parlaklığı elle en düşüğe al → tezgâh modu → Başlat (çıkış: 3 kez dokun).
- **H:** Uçak Modu + Wi-Fi kapalı → kilitliyken "Ses Ver başlat" / "Start Ses Ver".
- **I:** İzin iste → (Library sesi için) dosyaları yaz → ses seç → tek alarm / seri / limit testi.

Kanıt seti, kesinti matrisi ve geçti/kaldı ölçütleri plan §2–§3'tedir.

## Güvenlik ve kurallar

- Yasak yöntem yok: sessiz ses çalarak canlı kalma yok (her aralıkta gerçek, duyulabilir çerçeve), özel API yok, `MPVolumeView` yalnız kullanıcının oynattığı kaydırıcı (Spike F).
- Kulak güvenliği: aralık alt sınırı 10 s (görev döngüsü ≤ %12). Kazanç 1,0 ölçülmemiş → telefonu kulaktan ≥ 1 m uzak tutun, uzun koşular kutuda.
- Mikrofon yalnız `playAndRecord` varyantında açılır, tepe seviyesi ölçülür; kayıt saklanmaz.

## Tip denetimi (2026-10-20, Xcode 27.1, Swift 6.4, `-swift-version 6`, iPhoneOS 27.1 SDK)

Komut (hedef başına):

```sh
cd Spikes
xcrun --sdk iphoneos swiftc -typecheck -swift-version 6 -parse-as-library \
  -target arm64-apple-ios17.0 Shared/*.swift [Shared/Intents/BeaconIntents.swift] <Hedef>/*.swift
# Uzantı:
xcrun --sdk iphoneos swiftc -typecheck -swift-version 6 -parse-as-library -application-extension \
  -D WIDGET_EXTENSION -target arm64-apple-ios18.0 Shared/Intents/BeaconIntents.swift SpikeB_LockScreenControlWidgets/*.swift
# AlarmKit: -target arm64-apple-ios26.0
```

| Hedef | Hedef iOS | Sonuç |
|---|---|---|
| SpikeA_ActionButtonIntent | 17.0 | GEÇTİ (0 hata, 0 uyarı) |
| SpikeB_LockScreenControl | 17.0 | GEÇTİ |
| SpikeB_LockScreenControlWidgets | 18.0, `-application-extension` | GEÇTİ |
| SpikeC_BackgroundAudio72h | 17.0 | GEÇTİ |
| SpikeD_NotificationChain | 17.0 | GEÇTİ |
| SpikeE_BLEAdvertising | 17.0 | GEÇTİ |
| SpikeF_OutputVolume | 17.0 | GEÇTİ |
| SpikeG_NightWatchPower | 17.0 | GEÇTİ |
| SpikeH_SiriOffline | 17.0 | GEÇTİ |
| SpikeI_AlarmKit | 26.0 | GEÇTİ |

Ek: `-target arm64-apple-ios27.0` (SpikeI + Shared) → GEÇTİ, 0 hata, 8 kullanımdan kalkma uyarısı, hepsi `ChirpEngine.swift` içinde: iOS 27'de `AVAudioEngine.connect(_:to:format:)`, `installTap(onBus:…)` ve `AVAudioSession.InterruptionType/Options` kullanımdan kalktı. Apple'ın önerdiği yerine geçenler `AVAudioSessionDidBecomeInactiveNotification` + `AVAudioSessionResumptionRecommendationNotification`. Spike'lar iOS 17'yi hedeflediği için eski API'ler kalıyor; F1-4 AudioSessionCtl iOS 27'de yeni bildirimleri ele almalı.

Sınırlar: tip denetimi bağlama, imzalama, App Intents meta veri çıkarımı (`appintentsmetadataprocessor`) ve Info.plist doğrulamasını kapsamaz; bunlar ilk `xcodegen` + Xcode derlemesinde görülür. `project.yml` bu makinede YAML/XcodeGen ile doğrulanamadı.

## Bilinen bilinçli ödünler (spike, üretim değil)

- `ChirpRenderState.frames` render iş parçacığında yazılır, ana iş parçacığında okunur (hizalı sözcük). Üretimde `Synchronization.Atomic` (iOS 18+).
- `@unchecked Sendable` sınıflar (`SpikeLog`, `MicPeakBox`, `StaLta`, `MetricsSink`) erişimi kendi kuyruğuyla sınırlar.
- Çerçeve dalga biçimi signal-v0'a yaklaşıktır, CRC/yük yoktur; kod çözme testi `research/signal` + DetectorKit işidir.
