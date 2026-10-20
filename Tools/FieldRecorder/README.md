# FieldRecorder (F0-4-T1)

F0-4 saha akustiği için iç araç: iPhone'da ham ses kaydı alır, her kaydı deneme meta verisiyle etiketler. Uygulama arayüzü değildir, ürüne girmez.

**Durum: cihazda doğrulanmadı.** Yalnız tip denetiminden geçti. Sahadan önce bir tezgâh denemesi yapın (saha rehberi A1).

## Kurulum
```
brew install xcodegen
cd Tools/FieldRecorder && xcodegen      # FieldRecorder.xcodeproj
```
`project.yml` içinde `DEVELOPMENT_TEAM` ve `PRODUCT_BUNDLE_IDENTIFIER` değerlerini doldurun, gerçek cihaza kurun (iOS 17+).

Tip denetimi (kabul):
```
xcrun --sdk iphoneos swiftc -typecheck -swift-version 6 -target arm64-apple-ios17.0 Sources/*.swift
```
Sonuç: 0 hata, 0 uyarı.

## Sahada kullanım
1. Uygulamayı açın, mikrofon iznini verin. Telefonu Rahatsız Etmeyin'e alın (arama kesintisi kaydı durdurur).
2. Oturum, operatör, verici model/kılıf/yönelim/ses %, moloz tipi, derinlik, gürültü, sıcaklık alanlarını girin. Son değerler bir sonraki denemeye taşınır; yalnız değişeni düzeltin (nokta, dinleyici yatay m).
3. **Oturum başı ve sonu:** "Kalibrasyon" anahtarını açın, kalibratörü (94 dB, 1 kHz) mikrofona takın, "KALİBRASYON KAYDI". 10 sn sonra kendiliğinden durur. Dosya adı `<oturum>_KAL_<zaman>`, CSV notu "94 dB kalibratör tonu".
4. Her nokta için **KAYDET**, ölçüm bitince **DURDUR**. Üstteki uyarılara bakın (48 kHz verilmedi, mono değil, harici mikrofon, çerçeve boşluğu).
5. Bitince "Oturum dosyalarını paylaş" ile AirDrop/Dosyalar'a gönderin. Dosyalar uygulaması > Bu iPhone > SV Kayıt > `<oturum>/` altında da görünür.

Kayıt sırasında form kilitlidir (yanlış dokunuş olmasın). Hedefler >= 56 pt, KAYDET/DURDUR 72 pt.

## Dosya biçimi
`Belgeler/<oturum>/` altında:
- `<oturum>_<nokta>_<yyyyMMddTHHmmss>.wav`: WAV, linear PCM 24 bit, mono beklenir, hız cihazın gerçek hızı (48 kHz istenir). Oturum kategorisi `.record`, mod `.measurement` (AGC/işleme kapalı).
- Aynı adla `.json`: form alanları, alıcı model (`iPhone16,1`) ve iOS, istenen/gerçek örnekleme hızı, kanal, biçim, başlangıç/bitiş (ISO 8601, yerel saat), süre, yazılan çerçeve, tepe dBFS, uyarılar, `kesintiOlaylari` (kesinti, rota değişimi, motor yapılandırma, durdu + neden).
- `<oturum>_deneme.csv`: her kayda bir satır, `docs/field/forms/F0-4_deneme.csv` başlık sırası. Doldurulmayan sütunlar (foto_no, nem, rüzgâr, insan_*, makine_*) boş. `model/ios/ses_yuzde/kilif/yonelim/output_gain` verici bilgisidir; alıcı cihaz yalnız JSON'da.

## Gerçek zamanlı güvenlik
Yazma `AVAudioEngine` tap bloğunda `AVAudioFile.write` ile yapılır. Tap bloğu HAL IO iş parçacığında değil, motorun gerçek zamansız kuyruğunda çalışır; blokta uygulama tarafı bellek ayırma, kilit ve log yoktur (yalnız skaler sayaçlar). Ayrıntı: `RecorderController.swift` başındaki `TapWriter` yorumu.

## Kesintiler
Arama/Siri (`interruptionNotification .began`), giriş rotası değişimi ve motor yapılandırma değişimi kaydı durdurur; dosya kapatılır, JSON ve CSV yazılır, olay `kesintiOlaylari`'na girer. Kesinti sonrası kayıt otomatik sürmez, yeni kayıt başlatılır.

## Bilinen sınırlar
- Cihazda doğrulanmadı; 24 bit WAV yazımı ve `measurement` modunda hızın 48 kHz olması cihaza göre değişebilir (uyarı yazılır).
- Canlı seviye ölçeri yok (tap'ta kilitsiz paylaşım olmadığı için); tepe dBFS kayıttan sonra gösterilir/yazılır.
- Kayıt sırasında ekran kilidi/arka plan kaydı desteklenmez (arka plan ses modu yok); ekranı açık tutun.
- Zip yok, dosya listesi paylaşılır. Çok kanallı giriş gelirse tüm kanallar yazılır (uyarı verilir).
- Mutlak SPL yok: seviye kalibrasyon kaydı ve harici ölçerle bağlanır.
- Tüm metinler sabit Türkçe; Localizable.xcstrings kullanılmaz (iç araç).
- SwiftLint/Swift Testing henüz eklenmedi.
