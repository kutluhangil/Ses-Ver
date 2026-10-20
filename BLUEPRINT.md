# Ses Ver: Enkaz Altı Akustik İşaret ve Kurtarıcı Konum Kestirimi
## iOS blueprint'i: ajan ve alt ajan tabanlı geliştirme planı

> Çalışma adı: **Ses Ver**. Kurtarıcıların enkaz başında seslendiği "Sesimi duyan var mı? Ses ver!" çağrısından geliyor.
> Platform: **yalnızca iOS**, native Swift. Gerekçesi §4'te.
> Etiketler: [Kesin] doğrudan kanıta dayanıyor. [Muhtemel] güçlü bir çıkarım. [Tahmin] boşluk dolduruyor.
> Bu belge hayati bir alanla ilgili. Bu yüzden her bölüm "neyi bilmiyoruz" sorusunu açıkça işaretliyor. Saha verisi gelmeden hiçbir iddia ürün metnine girmez.

---

## 0. Önce okunacak altı gerçek

### 0.1 Telefonun depremi kendi kendine algılayıp ses çalması iOS'ta yapılamaz.
[Kesin] iOS, askıya alınmış (suspended) bir uygulamayı ivmeölçer olayıyla uyandıran bir API sunmuyor. `CMSensorRecorder` arka planda ivme verisi kaydedebilir, ama bu veri yalnızca uygulama sonradan çalıştığında okunabilir, anlık tetikleme yapmaz. Sessiz ses çalarak uygulamayı canlı tutmak App Review kuralı 2.5.4'e göre reddedilir.
**Sonuç:** Fikrin çekirdeği "otomatik algıla ve çal"dan **"tek hareketle başlayan ve günlerce dayanan işaret"e** dönüşüyor. Otomatik tetikleme, iOS'un izin verdiği üç dar kanaldan sağlanıyor (§3.2): Gece Nöbeti, kritik bildirim zinciri ve (v2'de) sunucudan kritik uyarı.

### 0.2 "3–4 kurtarıcı telefonu zaman farkıyla üçgenleme yapar" fikri, sahada çalışmayacak iki varsayıma dayanıyor.
- **Saat senkronu:** Sesin havadaki hızı ~343 m/s. 1 ms saat hatası ~34 cm konum hatası demek. [Muhtemel] İnternet yokken iPhone'lar arasında milisaniyenin altında hassasiyetle saat eşitlemenin hazır bir yolu yok.
- **Dinleyici konumları:** Zaman farkından konum hesaplamak (TDOA) için dinleyen telefonların birbirine göre konumunu santimetre düzeyinde bilmek gerekiyor. GPS'in hatası ~5 m, bu iş için işe yaramaz.
- **Moloz:** [Kesin] Ses betonda ~3.000–4.000 m/s hızla ilerler. Havadaki yol ise boşluklar arasından dolanır. Bu yüzden ilk ulaşan sinyalin varış zamanı, düz çizgi mesafesine karşılık gelmez.

**Sonuç:** MVP'de çoklu telefonla TDOA **yok**. Yerine iki daha sağlam yöntem var (§3.4):
1. **Sıcak-soğuk haritası:** Tek kurtarıcı telefonu dolaştırılır, ARKit konumuyla birlikte sinyal gücü (SNR) kaydedilir.
2. **İki yönlü akustik mesafe ölçümü:** BeepBeep yöntemi. Saat senkronu gerektirmez.

Çoklu telefonla TDOA, araştırma backlog'unda kalıyor.

### 0.3 Kurban tarafı yeni değil. Rakipler ve önceki çalışmalar var.
Kısa bir tarama yaptım ve şunlar çıktı:
- **Türkçe düdük uygulamaları:** "Düdüğüm" (düdük, fener, 112, iki kişiye konum SMS'i, açılınca sesi en yükseğe çıkarma) ve "Deprem Düdüğü" var. iOS'ta "Whistle for Sport & SOS" var ("Real Whistle" adıyla bir iOS uygulaması bulunamadı, bkz. docs/research/landscape.md). ([tamindir](https://www.tamindir.com/indir/dudugum/), [Vatan](https://www.gazetevatan.com/gundem/mutlaka-telefonunuzda-olmasi-gereken-deprem-uygulamalari-1351824))
- **TÜBİTAK MAM:**
  - **ATEAS:** GSM ağı çökmüşken çalışan, kurban ve kurtarıcı tarafı Android uygulamaları.
  - **AkuSTECTS:** jeofon ve akustik sensörlerle çalışan bir sistem. ([TÜBİTAK](https://mam.tubitak.gov.tr/en/tubitak-levels-up-in-earthquake-studies/))
- **İTÜ:** internetsiz enkaz dinleme uygulaması. ([ShiftDelete](https://shiftdelete.net/itu-enkaz-dinleme-uygulamasi-gelistirdi?amp=1))
- **Tokyo Üniversitesi (Takada, 2025 ASA bildirisi):** Ters yönde çalışıyor. Kurtarıcılar iki kaynaktan ses yayıyor, kurbanın telefonu dinleyip konumunu radyo ile bildiriyor. Eğitim enkazında ~5° açı hatası raporlanmış. ([acoustics.org](https://acoustics.org/using-smartphones-to-improve-disaster-search-and-rescue/))

**Sonuç:** "Telefondan yüksek ses çalmak" bir ürün değil, zaten var olan bir özellik. Savunulabilir fark şu dört şeyin **birlikte** olması:
1. Kurtarıcının telefonunun gürültü içinde çok daha uzaktan algılayabileceği, **tasarlanmış ve veri taşıyan bir sinyal** (kaç kişi, yaralı var mı, son dokunuş zamanı)
2. Uygulama kapansa bile süren **kritik bildirim zinciri**
3. **72 saat ve üzeri pil bütçesi**
4. Kurtarıcıya **yön ve bölge gösteren** iOS aracı

[Tahmin] TÜBİTAK MAM rakipten çok potansiyel bir ortak. F0'da temas kurulmalı.

### 0.4 En büyük risk teknik değil: yanlış güven.
İnsanlar "uygulamam var" deyip düdük almayı bırakabilir. Uygulama sesi kısık telefonda sessiz kalabilir. Boş bir binadaki telefon, kurtarıcıyı yanlış yere çekebilir. Bu yüzden şunlar ürünün **zorunlu parçası**:
- Hazırlık ekranında düdük önerisi
- Ses düzeyi kontrolü
- "Son dokunuş" alanı (§3.3)
- Mağaza metninde "hayat kurtarır" iddiasının olmaması

### 0.5 Asıl kanıt sahada üretilir, kodda değil.
Telefon hoparlörünün moloz içinden duyulup duyulmadığı, pilin 72 saat dayanıp dayanmadığı, kurtarıcıların aracı gerçekten kullanıp kullanmayacağı ancak sahada ölçülür. **F0 bitmeden uygulama arayüzü yazılmaz.** İstanbul'daki kentsel dönüşüm yıkım alanları (izinle) ve arama kurtarma eğitim enkazları test ortamı olarak kullanılacak.

### 0.6 AFAD/AKUT işbirliği "sonra bakarız" konusu değil, kritik yolun parçası.
- [Kesin] Kritik Uyarı (Critical Alerts) yetkisini Apple ayrıca onaylıyor.
- [Muhtemel] Bir kamu güvenliği kuruluşu veya ciddi bir arama kurtarma ekibiyle ortaklık, bu onayı da kurtarıcıların aracı benimsemesini de belirgin şekilde kolaylaştırır.
- [Muhtemel] Görüşmelerde kapıyı açacak şey F0 saha verisidir. Veri olmadan yapılan sunum zaman kaybı olur.

---

## 1. Ürün tanımı

### 1.1 İki mod, tek uygulama
| Mod | Kim | Ne yapar |
|---|---|---|
| **Hazırlık / İşaret** (herkes) | Herkes | Önceden hazırlık yapar. Enkaz altında tek hareketle işareti başlatır. İşaret günlerce periyodik olarak çalar, kurtarıcının sorgusuna yanıt verir. |
| **Dinle / Kurtarıcı** (herkes, uyarıyla) | Profesyonel ekipler, gönüllüler, komşular | İşaretleri algılar, kodunu çözer (ID, kişi sayısı, yaralı, son dokunuş), sıcak-soğuk yönlendirme yapar, AR'da olası bölgeyi gösterir. |

**Kurtarıcı modu neden kilitli değil?** [Muhtemel] Büyük depremlerin ilk saatlerinde kurtarmaların önemli bir kısmını profesyonel ekipler değil, komşular ve gönüllüler yapar. Bu yüzden mod açık kalıyor, ama ilk kullanımda zorunlu bir güvenlik ekranı ve ekip lideri koordinasyonu uyarısı gösteriliyor.

### 1.2 Kurban tarafı kullanıcı hikâyeleri
- Enkaz altındayım, karanlık, panikteyim. Tek hareketle (Eylem Düğmesi, kilit ekranı kontrolü veya Siri) işareti başlatabilmeliyim, ekrana bakmam gerekmemeli.
- Telefonum uzanabileceğim yerde değil, ama gece şarjdaydı ve Gece Nöbeti açıktı. Sallantıdan sonra cevap vermezsem işaret kendiliğinden başlamalı.
- Uygulama kapanırsa veya sistem onu sonlandırırsa sinyal yine de sürmeli.
- Kaç kişi olduğumuzu ve yaralı olup olmadığını büyük düğmelerle bildirebilmeliyim.
- Pilim bitmesin, işaret en az 3 gün çalsın.

### 1.3 Kurtarıcı tarafı kullanıcı hikâyeleri
- Enkazın başındayım. "Sessizlik" anında telefonum yakındaki işaretleri listelemeli.
- Hangi işaretin canlı birinden geldiğini (son dokunuş) ve kaç kişi olduğunu görmeliyim.
- Telefonu molozun üzerinde gezdirerek sinyalin nerede güçlendiğini görmeliyim.
- Kayıtlarımı koordinatöre AirDrop veya mesajla gönderebilmeliyim.

### 1.4 MVP kapsamı (v1.0)
- Kurban tarafı:
  - Katman 1 canlı işaret (§3.2)
  - Katman 2 kritik bildirim zinciri (Apple onay verirse, vermezse normal bildirim zinciri)
  - Tetikleyiciler: uygulama içi düğme, Eylem Düğmesi, Kontrol Merkezi ve kilit ekranı kontrolü, Siri/Kestirmeler
  - Panik dostu işaret ekranı
  - Live Activity ve Dynamic Island: kilit ekranında "Sinyal veriliyor · sonraki ıslık 7 sn" ve "Buradayım" düğmesi. Kilit açmadan yaşam belirtisi vermeyi sağlar ve ActivityKit + App Intent ile yapılır.
- Hazırlık ekranı: ses düzeyi, izinler, kısayol kurulumu, Tıbbi Kimlik yönlendirmesi, düdük önerisi, "Sinyali dene" testi
- Kurtarıcı tarafı:
  - Akustik algılama ve kod çözme
  - BLE ile yakındaki işaretlerin listesi
  - Sıcak-soğuk ölçer
  - ARKit ile güç haritası
  - Kayıt dışa aktarma
- Dil: TR ve EN. Sunucu yok, hesap yok, kişisel veri yok.

### 1.5 Bilinçli olarak MVP dışında
| Özellik | Sürüm | Neden ertelendi |
|---|---|---|
| İki yönlü akustik mesafe ölçümü + AR'da olası bölge | v1.1 (deneysel etiketiyle) | F0'da doğrulanması gerekiyor |
| Gece Nöbeti (otomatik tetikleme) | v1.1 | F0 spike'ının App Review ve pil sonucuna bağlı |
| Sunucudan kritik uyarı (Katman 3) + "Güvendeyim" yoklaması | v2 | Sunucu, konum verisi ve KVKK yükü getiriyor |
| Apple Watch'tan tetikleme | v2 | |
| Arapça (RTL) | v1.2 | [Muhtemel] İstanbul'da büyük bir Arapça konuşan nüfus var |
| Çoklu telefonla TDOA | Araştırma | §0.2 |

---

## 2. Gereksinimler

### 2.1 İşlevsel
- **K1:** İşaret, kilitli ekrandan en fazla 2 hareketle başlar (Eylem Düğmesi: 1, kilit ekranı kontrolü: 2).
- **K2:** İşaret, uygulama sistem tarafından sonlandırılsa bile en az 24 saat sürer (Katman 2).
- **K3:** Canlı işaret 72 saat sürer (§2.2 pil hedefi).
- **K4:** Her işaret çerçevesi, insan kulağının ayırt edebileceği bir giriş deseni ve 32 bitlik veri taşır.
- **K5:** Kurban telefonu, kurtarıcının sorgu sinyalini duyunca 1 sn içinde yanıt verir.
- **K6:** Kurtarıcı uygulaması, aynı anda en az 8 farklı işareti ayırt eder ve listeler.
- **K7:** Durdurma, yanlışlıkla olmasın diye 3 sn basılı tutma ister.

### 2.2 İşlevsel olmayan (F0 sonrası kesinleşecek hedefler)
| Konu | Hedef | Kaynak |
|---|---|---|
| Pil (iPhone 12, %80 başlangıç, Düşük Güç Modu açık, şebeke yok) | ≥ 72 saat canlı işaret | F0-5 tezgâh testi |
| İnsan kulağıyla algılama | Test molozunda ≥ X m, sessizlik anında %90 | F0-4 (X sahada belirlenecek) |
| Uygulamayla algılama menzili | İnsan menzilinin ≥ 2 katı | F0-4 |
| Yanlış alarm (kurtarıcı tarafı) | Saatte ≤ 1, şantiye gürültüsünde | F0-4 |
| Sıcak-soğuk tepe noktası hatası | Test molozunda denemelerin %80'inde ≤ 1,5 m | F2 kapısı |
| Başlatma süresi (karanlıkta, stres altında, 10 katılımcı) | 9/10 kişi ≤ 10 sn | F0-7 |
| Kulak güvenliği | 10 cm'de tepe ≤ ~95 dB SPL, görev döngüsü ≤ %12 (bkz. §8, R9) | F0-4 |

### 2.3 Kısıtlar
- Tek geliştirici + Claude Code ajanları.
- iOS 17 minimum. `AudioPlaybackIntent` ve etkileşimli widget'lar bunu gerektiriyor. Kilit ekranı ve Kontrol Merkezi kontrolleri iOS 18 ve üzerinde, iOS 17'de Kestirmeler ile Back Tap yedek yol olarak kullanılıyor.
- MVP'de sunucu yok. Her şey cihazda.

---

## 3. Mimari

### 3.1 Bileşen görünümü
```
┌──────────────────────────────────── iOS Uygulaması ─────────────────────────────────────┐
│ SwiftUI (Features)                                                                      │
│  Hazırlık · İşaret · Gece Nöbeti(v1.1) · Dinle · Sıcak-Soğuk · AR Harita · Ayarlar       │
│        │ @Observable modeller                                                           │
│ ───────┼──────────────────────────────────────────────────────────────────────────────  │
│ BeaconKit            DetectorKit             LocalizationKit        DeviceServices      │
│  ├ SignalSpec (v0)    ├ MatchedFilterBank      ├ SNRFieldMapper        ├ AudioSessionCtl  │
│  ├ FrameEncoder       │   (vDSP FFT)            │   (ARKit poz + SNR)   ├ NotificationChain│
│  ├ ScheduleEngine     ├ FrameDecoder (CSS)      ├ RangeSolver (v1.1)   ├ BLEAdvertiser    │
│  ├ Transponder (v1.1) ├ BeaconTracker           │   Gauss-Newton+Huber  ├ BLEScanner       │
│  └ LifeSignStore      └ NoiseFloorEstimator     └ RegionEstimate        ├ MotionWatch(v1.1)│
│                                                                          ├ BatteryMonitor   │
│ AppIntents: StartBeaconIntent (AudioPlaybackIntent), StopBeacon, ControlWidget, Siri     │
└─────────────────────────────────────────────────────────────────────────────────────────┘
          ▲ akustik çerçeve (hoparlör → mikrofon)        ▲ BLE reklamı (ID, pil, durum)
          └──────────────── kurban cihazı ⇄ kurtarıcı cihazı (internet yok) ─────────┘
```

### 3.2 Kurban tarafı: üç katmanlı işaret

**Katman 1: Canlı işaret (uygulama çalışıyor)**
- `AVAudioSession` kategorisi `.playAndRecord`, `UIBackgroundModes: audio`. İşaret gerçek, duyulabilir ses olduğu için arka planda ses kullanımı meşru. App Review notunda bu açıkça anlatılacak.
- Ses motoru: `AVAudioEngine` + `AVAudioSourceNode`. Çerçeveler sentezlenir, aradaki boşluklar sessizlik olarak çalınır. Böylece oturum kesintisiz kalır.
- Görev döngüsü (taslak, F0'da kalibre edilecek):

| Süre | Çerçeve aralığı |
|---|---|
| 0–6 saat | 10 sn |
| 6–24 saat | 20 sn |
| 24–72 saat | 45 sn |
| 72+ saat | 90 sn |
| Pil < %20 | Aralıklar ×2 |

- **Dinleme penceresi (v1.1, transponder):** 10 saniyede bir 2 sn mikrofon açılır. Kurtarıcının sorgusu 12 sn tekrarlandığı için pencere mutlaka denk gelir. Sorgu duyulursa sabit gecikmeyle yanıt verilir (§3.4.3).
- **BLE reklamı:** `CBPeripheralManager` + `bluetooth-peripheral` arka plan modu. [Muhtemel] Arka planda servis UUID'si "overflow" alanına taşınır ve yalnızca o UUID'yi özellikle tarayan iOS cihazları onu görür. Kurtarıcı uygulaması tam olarak bunu yapar. Ayrıntılı veri (kişi sayısı vb.) bağlantı kurulunca GATT karakteristiğinden okunur.
- **Ses düzeyi:** [Muhtemel] Herkese açık bir API ile sistem ses düzeyi uygulamadan ayarlanamaz. `AVAudioSession.outputVolume` okunabilir. Ses %80'in altındaysa işaret ekranı büyük bir uyarı gösterir. Hazırlık ekranı aynı kontrolü önceden yapar. Kritik bildirimler (Katman 2) ses düzeyini ve sessiz anahtarını yok sayar [Muhtemel]. Bu yüzden Katman 2, sesi kısık telefonlar için de bir sigortadır.

**Katman 2: Kritik bildirim zinciri (uygulama kapalı olsa bile)**
- İşaret başlar başlamaz, uygulama ileriye dönük **yerel bildirimler** planlar. Her bildirimin sesi ≤30 sn'lik bir işaret dosyasıdır [Kesin: 30 sn üzeri ses varsayılan sese düşer].
- `UNNotificationSound.criticalSoundNamed(_:withAudioVolume: 1.0)` kullanılır. **Critical Alerts yetkisi gerekiyor** [Kesin]. Yetki gelmezse normal bildirim sesi kullanılır ve sessiz anahtarına takılır. Bu durumda Katman 2 zayıflar ve kullanıcıya bu açıkça söylenir.
- [Kesin] Bekleyen yerel bildirim sınırı 64. Planlama: ilk 2 saat 5 dk'da bir (24), sonraki 10 saat 15 dk'da bir (40). **Not:** Bu plan yalnız 12 saat kapsıyor, K2 ise 24 saat istiyor. Aday plan `product24` (ADR-0003) F0-2(d)'de ölçülecek. Uygulama her çalıştığında (bildirime dokunma, arka planda canlanma) zincir yeniden doldurulur.
- [Muhtemel] Ses dosyası çalışma anında `Library/Sounds` içine yazılabilir. Bu sayede her etkinleştirmede kişiye özel ID içeren bir dosya üretilir. Bildirimden çalınan çerçevede mod biti = "zincir" olur, yani "yaşam belirtisi güncel değil" anlamına gelir.
- Katman 1 çalışırken Katman 2 bildirimleri gereksiz yere çalmasın diye, canlı işaret her çalışmasından sonra en yakın bildirimi ileri kaydırır.

**Katman 3 (v2): Sunucudan kritik uyarı**
AFAD, EMSC veya USGS akışından bölgede M ≥ eşik bir deprem görülürse, konumunu paylaşmayı seçmiş ve "Güvendeyim" demeyen kullanıcılara periyodik kritik uyarı gönderilir. Şebeke gerektirir. Konum verisi ve KVKK yükü getirdiği için MVP'de yok. **Patent notu:** "uzaktan talimat → istem → yanıtsızlıkta beacon" zinciri US 9 591 466'nın istemine yakın. Avukat görüşü gelene kadar uzaktan uyarı işareti otomatik başlatmaz, yalnız hatırlatır (docs/research/patent-US9591466.md).

**Tetikleyiciler**
| Tetik | Cihaz/iOS | Kilitliyken? | Not |
|---|---|---|---|
| Uygulama içi büyük düğme | Hepsi | Hayır | |
| Eylem Düğmesi → `StartBeaconIntent` | iPhone 15 Pro, 16 serisi ve sonrası | [Muhtemel] Evet | `AudioPlaybackIntent` uygulamayı açmadan ses başlatabilir |
| Kilit ekranı / Kontrol Merkezi kontrolü | iOS 18+ | [Tahmin] Ayara bağlı | F0-2'de doğrulanacak |
| Siri: "Ses Ver'i başlat" | Hepsi | [Tahmin] | İnternetsiz çalışıp çalışmadığı cihaza göre değişir, F0-2 |
| Back Tap → Kestirme | iPhone 8+ | Hayır | Yedek yol |
| Gece Nöbeti otomatik (v1.1) | Hepsi | (ön planda) | Aşağıya bakın |

**Gece Nöbeti (v1.1, F0 spike'ına bağlı)**
[Kesin] 6 Şubat 2023 depremi gece 04:17'de oldu. Gece depremleri en ölümcül senaryo ve insanların çoğu gece telefonunu şarjda bırakıyor.
- **App Review açısından güvenli tasarım:** uygulama ön planda kalır, ekran tamamen siyahtır (OLED'de pikseller kapalı), sadece soluk kehribar renkli bir saat görünür, `isIdleTimerDisabled = true`. Bu mod yalnızca şarjdayken açılır.
- Core Motion, 50 Hz'de STA/LTA ile deprem benzeri sallantı arar. Sallantı bitince sesli olarak "İyi misiniz?" diye sorar ve 90 sn geri sayım başlatır. Ekrana dokunulmazsa ve telefon hareket etmezse işaret başlar.
- Yanlış pozitif kaynakları: kamyon geçişi, telefonun düşmesi, yatağın sallanması. Bunlar için eşik + süre + frekans içeriği kontrolü yapılır. Geri sayım, yanlış tetiklemenin maliyetini düşürür.
- [Tahmin] Güç tüketimi: siyah ekran + ivmeölçer ~0,3–0,5 W, şarjdayken önemsiz. F0-2g'de ölçülecek.

### 3.3 Sinyal tasarımı (SignalSpec v0, taslak)
Amaç üç şeyi aynı anda sağlamak: insan kulağının ayırt edebilmesi, telefonla çok uzaktan algılanabilmesi ve veri taşıyabilmesi.

```
|<-- giriş (insan için) -->|<senk>|<---------- veri (32 bit) ---------->|
 ↗  ↗  ↗                      ↘     8 × CSS sembolü (her biri 4 bit)
 120ms ×3, 80ms aralık       120ms  64ms × 8
 1,8→4,2 kHz yükselen chirp   4,2→1,8 kHz
toplam ≈ 1,2 sn
```

- **Bant 1,8–4,2 kHz.** [Muhtemel] Telefon hoparlörleri 1 kHz altında zayıf. İnsan kulağı en duyarlı bölgesi olan 2–4 kHz'i iyi duyar. Moloz yüksek frekansları daha çok zayıflatır. Bu bant bir uzlaşmadır, F0-3/F0-4'te 1,2–3,0 kHz varyantıyla karşılaştırılacak.
- **İşleme kazancı:** Zaman-bant genişliği çarpımı 2.400 Hz × 0,12 sn = 288. Bu, eşlenik filtrede ~24,6 dB kazanç demek. Üç giriş chirp'inin birleştirilmesi +~4,0 dB daha ekler (F0-3'te ölçüldü; +4,8 dB yalnız tutarlı birleştirmenin üst sınırı). Yani kurtarıcının telefonu, insan kulağının duyamayacağı kadar gürültü altında kalmış sinyali de yakalayabilir [Muhtemel; kesin rakam sahada].
- **Zaman çözünürlüğü:** ~1/B ≈ 0,4 ms, havada yaklaşık 14 cm.
- **Veri (CSS, LoRa benzeri):** Her sembol, 16 olası döngüsel kaydırmadan biri (4 bit). Çok yollu yayılıma ve frekans kaymasına karşı dayanıklı.

| Alan | Bit | Anlam |
|---|---|---|
| `id` | 12 | Her etkinleştirmede rastgele seçilir. Kişisel veri değil. |
| `people` | 2 | 1 / 2 / 3 / 4+ |
| `injured` | 1 | Yaralı var |
| `lifeAge` | 4 | Son dokunuştan beri geçen süre (logaritmik dilimler: <1 dk … >48 sa, 15 = bilinmiyor) |
| `battery` | 3 | 8 seviye |
| `mode` | 2 | 0 canlı · 1 zincir (Katman 2) · 2 Gece Nöbeti otomatik · 3 yanıt |
| `crc` | 8 | CRC-8 |

- **Ritim:** "Üç yükselen ıslık + duraklama". [Tahmin] Bu desen telefon zil sesine ve araç alarmına benzemiyor. F0-6'da arama kurtarmacılara dinletilip seçilecek.
- **Açık protokol:** SignalSpec, CC-BY lisansıyla yayımlanacak. Başka uygulamalar ve ekipmanlar da aynı sinyali kullanabilsin. AFAD/AKUT görüşmelerinde bu bir artı.

### 3.4 Kurtarıcı tarafı

**3.4.1 Algılama hattı**
```
Mikrofon (48 kHz, AVAudioEngine input tap)
 → bant geçiren filtre 1,5–4,5 kHz
 → overlap-save FFT korelasyonu (vDSP), giriş chirp şablonuyla
 → CFAR eşik (gürültü tabanı uyarlamalı)
 → 3 tepe deseni doğrulaması → senk → CSS sembol çözme → CRC kontrolü
 → BeaconTracker: ID'ye göre birleştir, SNR geçmişi, son görülme zamanı
```
- Aynı anda birden çok işaret: ID'lere göre ayrılır. Çerçeveler çakışırsa CRC hatası verir. İşaretler rastgele aralıklarla (±%15 sapma) çaldığı için bir sonraki çerçevede çakışma büyük ihtimalle olmaz.
- **"Sessizlik" düğmesi:** Ekip lideri sessizlik ilan ettiğinde 60 sn'lik odaklı dinleme başlar. Ekranda yalnızca algılamalar gösterilir.
- **BLE taraması:** Belirli bir UUID için ön planda tarama. RSSI eğilimi "yaklaşıyor/uzaklaşıyor" göstergesine ikinci bir girdi sağlar.

**3.4.2 Sıcak-soğuk ve ARKit güç haritası (MVP)**
- Kurtarıcı telefonu molozun üzerinde yavaşça gezdirir. Her algılanan çerçeve için `ARFrame.camera.transform` konumu ve SNR kaydedilir.
- Zemin düzlemine yerleştirilmiş 25 cm'lik ızgarada SNR, ters mesafe ağırlıklı interpolasyonla doldurulur. AR görünümünde ısı karoları ve tepe noktası işareti çizilir.
- Saat senkronu ve mesafe varsayımı gerekmez. Bu yüzden moloz içinde en dayanıklı yöntem budur. [Muhtemel] Profesyonel dinleme cihazları da benzer şekilde, sensörler arası ses gücü karşılaştırmasıyla çalışır.
- **Kısıt:** ARKit'in görsel odometrisi ışık ve doku ister. Gece, projektör ışığı gerekir. LiDAR'lı modeller karanlıkta daha iyidir. Takip kaybolursa harita dondurulur ve kullanıcı uyarılır.

**3.4.3 İki yönlü akustik mesafe ölçümü (v1.1, "Deneysel")**
BeepBeep yöntemiyle saat senkronu gerekmez:
1. Kurtarıcı Q sorgusunu yayar. Kendi mikrofonu da duyar: örnek indeksi `q_r`.
2. Kurban Q'yu `q_v` indeksinde duyar ve yaklaşık 300 ms sonra R yanıtını yayar. Kendi mikrofonu R'yi `r_v` indeksinde duyar. `Δv = r_v − q_v` değeri R'nin içine kodlanır (16 bit, 48 kHz'de ~1,4 sn aralık, 7 mm çözünürlük).
3. Kurtarıcı R'yi `r_r` indeksinde duyar: `Δr = r_r − q_r`.
4. Mesafe `d = c/2 × (Δr − Δv)/fs`. Hoparlör ve mikrofon gecikmeleri iki tarafta da kendiliğinden düşer.

- ARKit ile izlenen, birbirinden ≥ 2 m uzak en az 4 noktadan ölçüm alınır. Gauss-Newton + Huber kaybıyla çok noktalı konum kestirimi yapılır ve kovaryansla güven elipsi çizilir.
- **Dürüst sınır:** Moloz içindeki yol düz çizgiden uzundur, bu yüzden mesafe sistematik olarak fazla çıkar. Sonuç bir "nokta" olarak değil, **olası bölge** olarak gösterilir ve güç haritasıyla birleştirilir. Arayüzde "Deneysel" etiketi kalıcıdır.

### 3.5 Veri ve gizlilik
- **Kurban cihazı:** `SwiftData` içinde etkinleştirme oturumu, son dokunuş zamanları ve hazırlık durumu tutulur. Sunucuya hiçbir şey gitmez.
- **Kurtarıcı cihazı:** algılama kaydı (zaman, ID, SNR, ARKit konumu, çözülen alanlar). Dışa aktarma CSV + JSON olarak, `ShareLink` ile yapılır. Konumlar göreli AR koordinatlarındadır, coğrafi koordinat yoktur.
- Yayınlanan ID her etkinleştirmede rastgele seçilir ve kişiyle eşleştirilemez. Tıbbi bilgi uygulamaya alınmaz. Kullanıcı iOS Sağlık uygulamasındaki **Tıbbi Kimlik**'e yönlendirilir.
- **KVKK:** MVP'de kişisel veri işlenmiyor [Muhtemel]. Mikrofon kaydı cihazda anlık işlenir, saklanmaz (kurtarıcının açıkça başlattığı "ham kayıt" hariç).

### 3.6 Proje yapısı
```
ses-ver/
├─ CLAUDE.md
├─ BLUEPRINT.md
├─ .claude/agents/*.md
├─ docs/
│  ├─ adr/                  # 0001-native-swift, 0002-signal-v0, 0003-layered-beacon …
│  ├─ contracts/            # SignalSpec, BeaconKit API, DetectorKit API
│  ├─ field/                # Saha test protokolleri ve raporlar
│  ├─ safety/               # Kırmızı takım bulguları, App Review notları
│  └─ design/               # Tasarım kararları, token'lar
├─ research/                # Python: sinyal tasarımı, simülasyon, saha verisi analizi
│  ├─ signal/  sim/  field_analysis/  notebooks/
├─ Packages/
│  ├─ BeaconKit/  DetectorKit/  LocalizationKit/  DeviceServices/  DesignSystem/
│  └─ (her biri Swift Testing testleriyle)
├─ App/
│  ├─ SesVer.xcodeproj
│  ├─ SesVer/ (Features/, AppIntents/, Resources/Sounds/, Localizable.xcstrings)
│  ├─ SesVerWidgets/ (ControlWidget, Kilit ekranı)
│  └─ SesVerUITests/
├─ Spikes/                  # F0-2 platform spike'ları, her biri ayrı küçük hedef (XcodeGen)
├─ Tools/
│  ├─ FieldRecorder/        # Saha için ham kayıt + etiketleme yapan iç araç uygulaması
│  └─ BatteryBench/         # Pil tezgâh testi uygulaması
└─ .github/workflows/
```

---

## 4. Teknoloji kararları

| Karar | Seçim | Alternatif | Gerekçe |
|---|---|---|---|
| Dil/çatı | **Swift 6 + SwiftUI** | Flutter | [Kesin] Kritik API'lerin hepsi native: AVAudioEngine, App Intents, ControlWidget, Critical Alerts, CoreBluetooth, ARKit, Core Motion. Flutter'da her biri için eklenti yazmak gerekirdi. |
| Minimum iOS | 17 | 18 | `AudioPlaybackIntent` 17 istiyor. 18 kontrolleri koşullu (`if #available`). |
| DSP | Accelerate / vDSP | Ek bir kütüphane | Sıfır bağımlılık, enerji verimli |
| Prototip DSP | Python (numpy, scipy, pyroomacoustics) | MATLAB | Hızlı tasarım, saha verisi analizi |
| Yerel veri | SwiftData | Core Data, dosya | Az model, basit |
| Test | Swift Testing + XCTest UI | | |
| CI | GitHub Actions (macOS runner) + Fastlane, ya da Xcode Cloud | | Xcode Cloud imzalamayı kolaylaştırır |
| Hata takibi | Yok (MVP), sonra TelemetryDeck | Sentry | Gizlilik önce |
| Sunucu | Yok (MVP) | | §1.5 |

---

## 5. Ajan organizasyonu

### 5.1 Roller ve sahiplik
Ana oturum **Orkestratör**dür. Kod yazmaz, görev brifi yazar, faz kapılarını kanıtla denetler.

| Ajan | Yazdığı dizinler | Model | Rol |
|---|---|---|---|
| `architect` | `docs/adr/`, `docs/contracts/` | opus | Kararlar ve sözleşmeler |
| `dsp-acoustics` | `research/signal`, `research/sim`, `Packages/BeaconKit`, `Packages/DetectorKit` | opus | Sinyal, modem, eşlenik filtre |
| `ios-platform` | `Packages/DeviceServices`, `App/SesVer/AppIntents`, `App/SesVerWidgets`, `Info.plist`, entitlements, `Spikes/` (F0-2) | opus | Arka plan, bildirim, BLE, ses oturumu, pil |
| `localization-ar` | `Packages/LocalizationKit`, AR özellik ekranları | opus | ARKit, güç haritası, çok noktalı konum kestirimi |
| `swiftui-ui` | `Packages/DesignSystem`, `App/SesVer/Features` (AR hariç) | sonnet | Tasarım sistemi ve ekranlar |
| `field-qa` | `*/Tests`, `App/SesVerUITests`, `Tools/`, `docs/field/`, `research/field_analysis` | sonnet | Testler, saha protokolleri, veri analizi |
| `safety-redteam` | yalnızca `docs/safety/` | opus | Yanlış güven, arıza modları, metin, App Review, KVKK |
| `release` | `.github/`, `fastlane/`, `store/` | sonnet | CI, TestFlight, mağaza |

### 5.2 Alt ajan dosyaları (`.claude/agents/`)

`architect.md`
```markdown
---
name: architect
description: Ses Ver mimari kararları (ADR) ve paketler arası sözleşmeler. Yeni modül, sinyal spesifikasyonu değişikliği veya iki ajanı ilgilendiren arayüzlerde kullan.
tools: Read, Grep, Glob, Write, Edit
model: opus
---
Yalnızca docs/adr/ ve docs/contracts/ altına yazarsın.
ADR formatı: Bağlam, Seçenekler (≥2), Karar, Sonuçlar, Yeniden değerlendirme tetikleyicisi.
BLUEPRINT.md §0'daki altı gerçeği ihlal eden öneriyi reddet ve nedenini yaz.
SignalSpec'te her değişiklik sürüm numarası alır (v0, v1…); eski sürümle çözülebilirlik notu zorunlu.
```

`dsp-acoustics.md`
```markdown
---
name: dsp-acoustics
description: Akustik işaret tasarımı, CSS modem, eşlenik filtre, CFAR, simülasyon ve Swift/vDSP uygulaması. Sinyal, algılama, kod çözme veya menzil ile ilgili her işte kullan.
tools: Read, Grep, Glob, Write, Edit, Bash
model: opus
---
Önce Python'da (research/) tasarla ve simüle et, sonra Swift'e taşı. Swift çıktısı Python referansıyla aynı test vektörlerinde bit-bit eşleşmeli (research/signal/vectors/).
Her iddia için tekrar üretilebilir rapor: SNR'a karşı çerçeve hata oranı, yanlış alarm oranı, CPU süresi.
Algılama kodu gerçek zamanlı ses iş parçacığında bellek ayırmaz, kilit almaz.
Kulak güvenliği sınırlarını (BLUEPRINT §2.2) aşan bir parametre önerme.
```

`ios-platform.md`
```markdown
---
name: ios-platform
description: iOS arka plan davranışı, AVAudioSession, App Intents/AudioPlaybackIntent, ControlWidget, yerel ve kritik bildirim zinciri, CoreBluetooth, Core Motion, pil ölçümü, entitlement'lar.
tools: Read, Grep, Glob, Write, Edit, Bash
model: opus
---
Her platform varsayımını gerçek cihazda bir spike ile doğrula; simülatör sonucu kanıt sayılmaz. Sonucu docs/field/spikes/ altına cihaz modeli, iOS sürümü ve tarih ile yaz.
Apple'ın yasakladığı yöntemler (sessiz ses çalarak canlı kalmak, özel API, ses düzeyini MPVolumeView ile zorlamak) kullanılmaz.
Kesinti senaryoları zorunlu test: telefon araması, Siri, başka uygulamanın sesi, kulaklık takılması, Düşük Güç Modu, termal kısıtlama, bellek uyarısı.
```

`localization-ar.md`
```markdown
---
name: localization-ar
description: ARKit poz takibi, SNR alan haritası, iki yönlü mesafe çözücü, güven bölgesi hesaplama ve AR görselleştirme.
tools: Read, Grep, Glob, Write, Edit, Bash
model: opus
---
Sonuçları nokta değil olası bölge olarak üret; kovaryans/güven seviyesi her çıktıda bulunur.
Takip kaybında harita donar ve kullanıcı uyarılır; asla eski poza yanlış veri yazılmaz.
Çözücü için sentetik senaryo testleri: düz yol, uzun yol önyargısı, aykırı değerler, kötü geometri (noktalar tek çizgide).
```

`swiftui-ui.md`
```markdown
---
name: swiftui-ui
description: DesignSystem paketi (token, bileşen) ve SwiftUI ekranları. docs/design/ ve Claude Design çıktısını referans alır.
tools: Read, Grep, Glob, Write, Edit, Bash
model: sonnet
---
Sabit renk/ölçü yazma; DesignSystem token'larını kullan.
Kurban ekranları: OLED siyah zemin, Dinamik Yazı AX5'te taşmasız, VoiceOver ile tamamen kullanılabilir, her eylem ≥ 60 pt.
Kurtarıcı ekranları: eldivenle kullanılabilir (≥ 56 pt hedef), güneş altında okunur kontrast, tek elle kullanım.
Metinler yalnızca Localizable.xcstrings'ten gelir; "hayat kurtarır", "garanti" gibi ifadeler yasak (safety-redteam onayı olmadan metin birleşmez).
```

`field-qa.md`
```markdown
---
name: field-qa
description: Birim/UI testleri, saha test protokolleri, FieldRecorder ve BatteryBench araçları, saha verisi analizi ve faz kapısı kanıt raporları.
tools: Read, Grep, Glob, Write, Edit, Bash
model: sonnet
---
Üretim koduna dokunmazsın; hata bulursan yeniden üretme adımlarıyla raporlarsın.
Saha protokolü her denemede şunları kaydeder: cihaz, iOS, ses düzeyi, kılıf, konum (gerçek), moloz tipi, ortam gürültüsü dB(A), sonuç.
Başarısız sonucu silmez, yumuşatmazsın; kapı raporunda olduğu gibi yer alır.
```

`safety-redteam.md`
```markdown
---
name: safety-redteam
description: Yanlış güven, arıza modları, kullanıcı metinleri, App Review uyumu, KVKK ve kulak güvenliği incelemesi. Kurban tarafına ve mağaza metinlerine dokunan her değişiklikten sonra kullan.
tools: Read, Grep, Glob, Write
model: opus
---
Yalnızca okursun; bulguları docs/safety/findings-YYYY-MM-DD.md dosyasına önem sırasıyla yazarsın.
Her bulgu: senaryo → kim zarar görür → olasılık/etki → önerilen önlem.
Sorular: Bu ekran panikteki birini yanıltabilir mi? Bu metin aşırı vaat içeriyor mu? Bu özellik insanları düdük/112 gibi temel önlemlerden uzaklaştırır mı? İşaret boş bir binadan geliyorsa kurtarıcı bunu anlayabilir mi?
```

`release.md`
```markdown
---
name: release
description: CI, imzalama, TestFlight, App Store metinleri, gizlilik etiketi, App Review notları ve entitlement başvuruları.
tools: Read, Grep, Glob, Write, Edit, Bash
model: sonnet
---
Gizli anahtarlar yalnızca CI secret. App Review notu: arka plan ses kullanımının gerekçesi, kritik uyarı gerekçesi, demo videosu bağlantısı, test adımları.
Mağaza metni safety-redteam onayı olmadan gönderilmez.
```

### 5.3 `CLAUDE.md`
```markdown
# Ses Ver: ajan kuralları
- Plan: BLUEPRINT.md. Kararlar: docs/adr/. Sözleşmeler: docs/contracts/.
- Dizin sahipliği BLUEPRINT §5.1; alanın dışına yazma, Orkestratör'e talep dön.
- Swift 6 strict concurrency, SwiftLint temiz, Swift Testing.
- Platform varsayımı = gerçek cihaz spike'ı ile kanıt. Simülatör kanıt değildir.
- Kullanıcı metinleri Localizable.xcstrings; yasaklı ifadeler: "hayat kurtarır", "garanti", "kesin bulunursunuz".
- Gerçek zamanlı ses iş parçacığında bellek ayırma, kilit, log yok.
- Entitlement başvurusu, App Store gönderimi, dış kuruma e-posta: önce insan onayı.
```

### 5.4 Çalışma akışı
```
Orkestratör ─ görev brifi
   ├─► architect (sözleşme/ADR gerekiyorsa)
   ├─► sahip ajan (paralel işlerde isolation: worktree, en fazla 3 paralel)
   ├─► field-qa (test + kanıt)
   ├─► safety-redteam (kurban tarafı, metin veya izin değiştiyse ZORUNLU)
   ├─► /code-review high  +  /simplify
   └─► Orkestratör: birleştir, İlerleme tablosu
```
**Brif şablonu:** Görev ID · Sahip · Faz · Bağımlılık · Amaç (1 cümle) · Bağlam (ADR/sözleşme) · Kabul kriterleri (her biri test veya saha ölçümüyle eşleşir) · Kapsam dışı · Teslim (dosyalar + kanıt yolu).

### 5.5 Kullanılacak skill'ler
| Skill | Nerede |
|---|---|
| `engineering:system-design`, `engineering:architecture` | ADR'ler, katmanlı işaret mimarisi |
| `engineering:testing-strategy` | F1 başında test piramidi + saha testi ayrımı |
| `operations:risk-assessment`, `legal:legal-risk-assessment` | §8 risk kaydı, sorumluluk ve kullanım koşulları |
| `design:user-research`, `design:research-synthesis` | F0-6 kurtarıcı görüşmeleri, F0-7 kullanılabilirlik testi |
| `design:accessibility-review`, `design:ux-copy` | Kurban ekranları, panik altında metin |
| `design:design-handoff` | Claude Design çıktısını `swiftui-ui` için spesifikasyona çevirme |
| `/code-review`, `/security-review`, `/simplify` | Her birleştirme |
| `engineering:deploy-checklist` | F5 |

---

## 6. Fazlar ve kapılar

### F0: Gerçeklik testi (4 hafta). Kapı geçilmezse proje yön değiştirir.
| ID | Görev | Sahip | Çıktı / kabul |
|---|---|---|---|
| F0-1 | Literatür ve rakip derinleştirme: Düdüğüm, Real Whistle, ATEAS, AkuSTECTS, İTÜ, Takada 2025, BeepBeep, profesyonel dinleme cihazları | Orkestratör | `docs/research/landscape.md`: her biri için ne yapıyor, ne yapmıyor, işbirliği olasılığı |
| F0-2 | iOS spike'ları (gerçek cihaz): (a) Eylem Düğmesi ile `AudioPlaybackIntent` kilitliyken çalışıyor mu? (b) Kilit ekranı kontrolü + kimlik doğrulama politikası (c) `audio` arka plan modunda 72 saat ekran kapalı oynatma + mikrofon, sistem uygulamayı öldürüyor mu? (d) 64 yerel bildirim zinciri + `Library/Sounds` dosyası (e) Arka planda BLE reklamı, başka bir iPhone'dan tespit (f) `outputVolume` okuma (g) Gece Nöbeti siyah ekran güç tüketimi (h) Siri internetsiz | `ios-platform` | Her spike için evet/hayır + kanıt (video, log) |
| F0-3 | SignalSpec v0 simülasyonu: AWGN + çok yollu yayılım + moloz zayıflama modeli, 2 bant varyantı | `dsp-acoustics` | SNR'a karşı tespit ve çerçeve hata oranı eğrileri |
| F0-4 | Saha akustiği: 6 iPhone modelinde hoparlör SPL'i (kalibre ses ölçer), test molozunda (yıkım alanı / eğitim enkazı) 3 derinlik × 3 moloz tipi; insan dinleyici + FieldRecorder | İnsan + `field-qa` | Menzil tablosu, insan ve makine algılama karşılaştırması |
| F0-5 | Pil tezgâhı: iPhone 12/13/15, %80 başlangıç, Düşük Güç Modu, **metal kutuda** (şebeke arama yükünü taklit eder) | `field-qa` + `ios-platform` | Saat cinsinden süre, %/saat eğrisi |
| F0-6 | Paydaş görüşmeleri: ≥ 5 arama kurtarmacı (AKUT, GEA, UMKE, gönüllü ekipler) + TÜBİTAK MAM teması | İnsan + `design:user-research` | Ritim tercihi, iş akışı, "kullanır mısın" cevabı, işbirliği yolu |
| F0-7 | Başlatma kullanılabilirliği: 10 katılımcı, karanlık oda, zaman baskısı, 3 tetik yolu | İnsan + `field-qa` | Süre ve başarı oranı |
| F0-8 | Critical Alerts entitlement başvurusu (onay süresi uzun olabilir, erken başla) | `release` + insan | Başvuru gönderildi |
| F0-9 | ADR-0001 native Swift, ADR-0002 SignalSpec v0, ADR-0003 katmanlı işaret | `architect` | Birleştirilmiş ADR'ler |

**F0 kapısı (hepsi gerekli):**
1. Hoparlör sesi, test molozunda en az bir gerçekçi derinlikte insan kulağıyla duyuluyor (F0-4).
2. Uygulamayla algılama menzili, insan menziline göre ≥ 2 kat (F0-4).
3. Canlı işaret ≥ 72 saat sürüyor (F0-5) **veya** Katman 2 ile ≥ 24 saat ek kapsama sağlanıyor.
4. F0-2(a) veya (b): kilitliyken en az bir tek hareketli tetik çalışıyor.

**Kapı geçilmezse:**
- Hoparlör duyulmuyor → Ürün "kurtarıcı dinleme aracı"na döner. Geophone benzeri dinleme, insan sesi ve vuruntu algılama. İşaret yan özellik olur.
- Pil yetmiyor → Görev döngüsü uzatılır ve transponder önceliklendirilir (sadece sorulunca yüksek sesle yanıt). Gerekirse Takada yaklaşımı benimsenir: kurban dinler, kurtarıcı yayar.
- Tetik yok → Ürün yalnızca Hazırlık + uygulama içi düğme olarak çıkmaz. Önce Apple'dan resmi yol aranır.

### F1: Kurban tarafı MVP (4 hafta)
| ID | Görev | Sahip |
|---|---|---|
| F1-1 | Xcode projesi, paketler, CI, SwiftLint, xcstrings | `release` + `swiftui-ui` |
| F1-2 | DesignSystem token'ları ve bileşenleri (tasarımdan) | `swiftui-ui` |
| F1-3 | BeaconKit: FrameEncoder, ScheduleEngine, LifeSignStore (+ Python vektör eşleşmesi) | `dsp-acoustics` |
| F1-4 | AudioSessionCtl: kesinti yönetimi, yeniden başlatma, ses düzeyi izleme | `ios-platform` |
| F1-5 | NotificationChain (Katman 2), kritik yetki yoksa yedek yol | `ios-platform` |
| F1-6 | BLEAdvertiser | `ios-platform` |
| F1-7 | App Intents, Eylem Düğmesi, ControlWidget, Siri ifadeleri | `ios-platform` |
| F1-8 | Ekranlar: Hazırlık, Sinyali dene, İşaret aktif, Durdur (basılı tut) | `swiftui-ui` |
| F1-9 | Kırmızı takım incelemesi: kurban akışı ve metinler | `safety-redteam` |

**Kapı:** 3 cihazda kilitliyken başlatma çalışıyor. Uygulama zorla kapatılınca Katman 2 çalmaya devam ediyor. 24 saatlik gerçek cihaz testi geçti. Kırmızı takımda kritik bulgu yok.

### F2: Kurtarıcı tarafı MVP (4 hafta)
F2-1 DetectorKit (eşlenik filtre bankası, CFAR, CSS çözme, BeaconTracker) · F2-2 BLEScanner · F2-3 Dinle listesi + Sessizlik modu · F2-4 Sıcak-soğuk ölçer · F2-5 ARKit güç haritası (`localization-ar`) · F2-6 Kayıt dışa aktarma · F2-7 Güvenlik ekranı ve metinler (`safety-redteam`).
**Kapı:** Test molozunda 3 eşzamanlı işaret doğru ayrılıyor. Güç haritası tepesi denemelerin %80'inde ≤ 1,5 m. Şantiye gürültüsü kaydında saatte ≤ 1 yanlış alarm.

### F3: Deneysel konum kestirimi + Gece Nöbeti (4 hafta)
F3-1 Transponder (kurban) · F3-2 iki yönlü mesafe ölçümü (kurtarıcı) · F3-3 RangeSolver + güven bölgesi · F3-4 AR'da bölge gösterimi · F3-5 Gece Nöbeti (F0-2g olumluysa) · F3-6 STA/LTA eşik kalibrasyonu (sallantı masası veya kayıtlı deprem ivme verisiyle oynatma).
**Kapı:** Açık alanda ±30 cm, test molozunda raporlanan güven bölgesi gerçeği denemelerin ≥ %80'inde kapsıyor. Kapsamıyorsa özellik kapalı kalır.

### F4: Saha doğrulama ve ekip eğitimi (3 hafta)
Bir arama kurtarma ekibiyle 2 tatbikat. Eğitim materyali (1 sayfa + 3 dk video). Geri bildirim döngüsü ve düzeltmeler.

### F5: Beta ve yayın (2–3 hafta)
TestFlight (ekipler + 50 sivil). App Review notları, gizlilik etiketi ("Veri toplanmıyor" hedefleniyor), mağaza metni (kırmızı takım onaylı), `engineering:deploy-checklist`.

**Toplam:** [Tahmin] 21–24 hafta. En büyük belirsizlik F0-4 ve Critical Alerts onay süresi.

---

## 7. Test stratejisi
| Katman | Yöntem |
|---|---|
| Sinyal | Python ↔ Swift bit eşleşmesi, SNR taraması, rastgele gecikme ve frekans kayması |
| Algılama | Kayıtlı saha sesleri (şantiye, rüzgâr, kalabalık, jeneratör) üzerinde yanlış alarm testi |
| Platform | Gerçek cihazda kesinti matrisi (§5.2 ios-platform), 24/72 saatlik dayanıklılık |
| Konum | Sentetik geometri testleri + saha denemeleri (gerçek konum şerit metreyle ölçülür) |
| UI | Snapshot (AX5 Dinamik Yazı, VoiceOver etiketleri), XCUITest başlatma akışı |
| İnsan | Karanlık oda başlatma testi, kurtarıcı tatbikatı |

---

## 8. Risk kaydı
| # | Risk | Olasılık | Etki | Önlem |
|---|---|---|---|---|
| R1 | Hoparlör sesi molozdan geçmiyor | Orta | Çok yüksek | F0 kapısı, yön değiştirme planı |
| R2 | Yanlış güven, insanların düdük almayı bırakması | Yüksek | Çok yüksek | Hazırlık ekranında düdük önerisi, metin denetimi, mağazada iddia yok |
| R3 | Critical Alerts onayı gelmiyor | Orta | Yüksek | Normal bildirim yedeği + açık uyarı, kurumsal ortaklıkla yeniden başvuru |
| R4 | App Review arka plan ses kullanımını reddediyor | Düşük–Orta | Yüksek | Gerçek ses, ayrıntılı not, video |
| R5 | Ses düzeyi kısık telefon | Yüksek | Yüksek | Hazırlık kontrolü, işaret ekranı uyarısı, Katman 2 kritik ses |
| R6 | Boş binadan gelen işaret kurtarıcıyı yanıltıyor | Orta | Yüksek | `lifeAge` ve `mode` alanları, arayüzde "son dokunuş" önceliği |
| R7 | Çok sayıda işaret karışıklık yaratıyor | Orta | Orta | ID ile ayırma, aralık sapması, liste + harita |
| R8 | Kurtarıcının uygulamayı kullanmaması | Yüksek | Yüksek | F0-6 görüşmeleri, açık protokol, ekip eğitimi, insan kulağı için tasarlanmış ritim (uygulama olmadan da işe yarar) |
| R9 | Kapalı boşlukta kulağa yakın yüksek ses: işitme ve psikolojik stres | Orta | Orta | Görev döngüsü ≤ %12, "telefonu bir kol boyu uzağa, açıklığa doğru koy" yönergesi, 5 dk sessize alma (otomatik geri döner) |
| R10 | Sivil kurtarıcının enkaza tırmanıp yaralanması | Orta | Yüksek | İlk kullanımda güvenlik ekranı, "ekip lideriyle koordine olun" uyarısı |
| R11 | Soğukta pil kapasitesinin düşmesi | Orta | Orta | Kış koşulu tezgâh testi (buzdolabında), görev döngüsünün uyarlanması |
| R12 | Sorumluluk ve hukuk | Düşük | Çok yüksek | Kullanım koşulları, avukat incelemesi (`legal:legal-risk-assessment`), ücretsiz ürün |

---

## 9. İş modeli ve sürdürülebilirlik
- **Ücretsiz, reklamsız, hesapsız.** [Muhtemel] Hayati bir araçta ödeme duvarı hem etik değil hem de yaygınlaşmayı öldürür.
- **Finansman seçenekleri:** TÜBİTAK BiGG/1512 [Muhtemel, uygunluğu kontrol edilmeli], belediye (İBB) ve sigorta sektörü sponsorluğu, AB sivil koruma programları.
- **Maliyet:** MVP'de sunucu yok. Tek sabit gider Apple Developer üyeliği.
- **Açık protokol + kapalı uygulama** dengesi: SignalSpec açık, kod (en azından ilk başta) kapalı. Kodun açılması, kurumsal güven için ileride düşünülebilir.

---

## 10. Senin vermen gereken kararlar
1. "Ses Ver" adı kalsın mı?
2. F0 kapısı geçilemezse "kurtarıcı dinleme aracı"na dönmeyi kabul ediyor musun?
3. TÜBİTAK MAM'a rakip olarak mı, ortak olarak mı yaklaşacaksın? Benim önerim ortak.
4. Kurtarıcı modu herkese açık mı kalsın? Benim önerim açık + güvenlik ekranı.
5. SignalSpec açık lisansla yayımlansın mı? Benim önerim evet.
6. Yıkım alanı ve eğitim enkazı erişimi için kimi tanıyorsun? F0-4'ün kritik yolu bu.
7. SignalSpec v0 hiç yayımlanmasın, ilk açık protokol v1 olsun mu? Benim önerim evet (ADR-0004: sahada v0/v1 karışıklığını sıfır maliyetle önler).

---

## 11. Orkestratör başlatma istemi
```text
Sen Ses Ver projesinin Orkestratörüsün. BLUEPRINT.md'yi baştan sona oku; §0 ve §5 bağlayıcıdır.
Kod yazma; işi .claude/agents/ altındaki alt ajanlara §5.4'teki brif şablonuyla dağıt.
F0'dan başla:
1) F0-1'i kendin yap (WebSearch), docs/research/landscape.md'ye yaz.
2) architect'e ADR-0002 SignalSpec v0 taslağını ve docs/contracts/signal-v0.md'yi yazdır.
3) dsp-acoustics'e research/signal altında chirp + CSS üretici, eşlenik filtre ve SNR taraması simülasyonunu kurdur.
4) ios-platform'a F0-2(a)–(h) spike planını yazdır; her biri ayrı küçük bir hedef (target) olsun.
5) Bana F0-4 saha akustiği protokolünü (ekipman listesi, ölçüm matrisi, form) ve F0-6 görüşme rehberini tek sayfa olarak hazırla.
Kanıt olmadan faz kapısını geçme; geçemiyorsak sayılarla birlikte söyle ve §6'daki yön değiştirme planını öner.
```

---

## Kaynaklar (ilk tarama)
- [Düdüğüm (tamindir)](https://www.tamindir.com/indir/dudugum/)
- [Mutlaka telefonunuzda olması gereken deprem uygulamaları (Vatan)](https://www.gazetevatan.com/gundem/mutlaka-telefonunuzda-olmasi-gereken-deprem-uygulamalari-1351824)
- [İTÜ enkaz dinleme uygulaması (ShiftDelete)](https://shiftdelete.net/itu-enkaz-dinleme-uygulamasi-gelistirdi?amp=1)
- [TÜBİTAK MAM: ATEAS ve AkuSTECTS](https://mam.tubitak.gov.tr/en/tubitak-levels-up-in-earthquake-studies/)
- [Using smartphones to improve disaster search and rescue (ASA)](https://acoustics.org/using-smartphones-to-improve-disaster-search-and-rescue/)
- [Smartphone microphones used for disaster search and rescue (Critical Comms)](https://www.criticalcomms.com.au/content/research/news/smartphone-microphones-used-for-disaster-search-and-rescue-706460394)

## İlerleme
| ID | Durum | Kanıt |
|---|---|---|
| İskelet | ✅ Dizinler, CLAUDE.md, `.claude/agents/` (8 ajan), .gitignore. `.claude/` ve `CLAUDE.md` yerel, depoya girmez. | §3.6 |
| F0-1 | 🟡 Masa taraması bitti. Delsar bandı doğrulandı (200–3 000 Hz). Patent ön okuması yapıldı. Açık: cihazda deneme (F0-1b), TÜBİTAK teması (F0-1d), avukat görüşü (F0-1e). | `docs/research/landscape.md`, `docs/research/patent-US9591466.md` |
| F0-2 | 🟡 Plan ve 9 spike iskeleti (a–i, yeni: AlarmKit) hazır, typecheck geçti. **Gerçek cihazda henüz koşulmadı.** | `docs/field/spikes/F0-2-plan.md`, `Spikes/` |
| F0-3 | 🟡 Python referansı, 55 vektör, Pd/FER, yanlış alarm, kazanç. Şantiye yanlış alarmı 1,33/sa > hedef, sözleşme r2'de iki çerçeve kuralıyla ele alındı. **F0-3b:** v1 adayları ölçüldü (42/42 test). Öneri: B1 + RS t=1 + P1, 96 ms chirp; alıcıda E0+E4 (+3,7 dB). Moloz modeli [Tahmin]. Sıradaki: F0-3c. | `research/sim/reports/F0-3-report.md`, `F0-3b-report.md`, ADR-0004 |
| F0-4 | ⬜ Protokol, CSV formları ve FieldRecorder aracı hazır. Saha erişimi bekleniyor (§10/6). | `docs/field/F0-4_F0-6_saha-rehberi.md`, `docs/field/forms/`, `Tools/FieldRecorder/` |
| F0-5 | ⬜ Protokol ve form hazır. Cihaz + metal kutu gerekli, spike (c) ile birlikte. | `docs/field/F0-5_pil-tezgahi.md` |
| F0-6 | ⬜ Görüşme rehberi, onam formu ve 3 ritim WAV'ı hazır. Katılımcı bekleniyor. | `docs/field/F0-4_F0-6_saha-rehberi.md`, `docs/field/F0-6_F0-7_onam.md`, `research/signal/rhythms/` |
| F0-7 | ⬜ Protokol, onam ve form hazır. Katılımcı ve cihaz bekleniyor. | `docs/field/F0-7_baslatma-kullanilabilirligi.md` |
| F0-8 | ⬜ Başvuru metni (EN) hazır, **gönderilmedi**. İnsan onayı ve kanıt ekleri bekleniyor. | `store/entitlements/critical-alerts-request.md` |
| F0-9 | 🟡 ADR-0001 kabul. ADR-0002 ve ADR-0003 önerildi. ADR-0004 (v1 adayları) taslak. Sözleşme signal-v0 r2. | `docs/adr/`, `docs/contracts/signal-v0.md` |
| Güvenlik | 🟡 Tasarım v0 + sözleşme incelendi: 2 kritik, 7 yüksek bulgu. Önlemler metin kataloğuna ve tasarım v2 istemine taşındı. Tasarım v1 gelince yeniden inceleme. | `docs/safety/findings-2026-10-20.md` |
| Tasarım | 🟡 v0: 7 ekran. v1 istemi hazır (10 düzeltme + 17 yeni ekran/durum). Metin kataloğu TR/EN (19 ekran), token'lar, devir belgesi hazır. Claude Design'da üretim bekleniyor. | `docs/design/` |
| F0 kapısı | ⬜ Kanıt yok. Dört maddenin hepsi saha veya cihaz verisi istiyor. | — |
