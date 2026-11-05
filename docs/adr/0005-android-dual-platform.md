# ADR-0005: Çift Platform Stratejisi — iOS ve Android Birebir Uyumluluğu

- Durum: Kabul edildi
- Tarih: 2026-11-05
- Sahip: `architect`
- İlgili: ADR-0001, ADR-0002, docs/contracts/signal-v1.md

## Bağlam
ADR-0001 kapsamında başlangıçta tek platform (yalnızca iOS) seçilmişti. Ancak Türkiye ve deprem bölgelerindeki mobil kullanıcıların büyük çoğunluğunun Android cihaz kullandığı gerçeği göz önüne alındığında, hayat kurtarma amacı taşıyan bir akustik işaret sisteminin yalnızca iOS üzerinde kalması kabul edilemez bir kapsama açığı yaratır.

Kullanıcı gereksinimi: Ses-Ver hem iOS hem de Android üzerinde birebir uyumlu ve kusursuz şekilde çalışmalıdır.

## Karar
Ses-Ver, hem iOS hem de Android için yerel (native) dillerde (Swift 6 ve Kotlin 2.x) geliştirilen, aynı açık sinyal standardını (`docs/contracts/signal-v1.md`) ve protokolü harfiyen uygulayan çift platformlu bir mimariye geçirilmiştir.

### 1. Parite Garantileri
1. **Akustik Sinyal Paritesi**:
   - Bant: 1 200 – 3 000 Hz ($B = 1 800\text{ Hz}$), $f_s = 48 000\text{ Hz}$.
   - Çerçeve: 3 yükselen öncül chirp (96 ms) + 1 alçalan senk (96 ms) + 80 ms sessizlik + 10 CSS sembolü (her biri 64 ms). Toplam aktif süre $T_{\text{on}} = 1 024\text{ ms} \le 12\%$ görev çevrimi.
   - Hata Düzeltme: Reed-Solomon RS(10,6) GF(16) $p(x) = x^4 + x + 1$, $t_{\max} = 1$ sembol düzeltme, Gray kodlama.
   - Doğrulama: `research/signal/vectors/v1/` altındaki 55 altın vektör hem Swift hem de Kotlin test paketlerinde bit-bit doğrulanır.

2. **BLE Keşif Paritesi**:
   - UUID: `A6E00001-5E50-4E10-9E10-5E5056455201`.
   - Üretici verisi: 16 bit ID + 4 bit pil + 4 bit canlılık yaşı.

3. **72 Saat Kesintisiz Arka Plan Ses Döngüsü**:
   - iOS: `AVAudioEngine` / `AVAudioSourceNode` + `UIBackgroundModes: audio`.
   - Android: `AudioTrack` (Float / 48 kHz mono) + `FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK` + `PARTIAL_WAKE_LOCK`.

4. **Sessiz Mod ve Rahatsız Etmeyin (DND) Delme**:
   - iOS: Apple Critical Alerts (`UNAuthorizationOptions.criticalAlert`).
   - Android: `AudioAttributes.USAGE_ALARM` / `STREAM_ALARM`. Android mimarisinde alarm ses akışı, sistemin sessiz modunu ve DND filtrelerini doğrudan deler.

5. **Tek Dokunuşla Hızlı Başlatma (Donanım/Kilit Ekranı)**:
   - iOS: Eylem Düğmesi (Action Button), Kilit Ekranı Denetimi (`ControlWidget`), App Intents (`StartBeaconIntent`).
   - Android: Hızlı Ayarlar Karosu (`SesVerTileService`), Kilit Ekranı Kısayolu ve Ana Ekran Widget'ı (`AppWidgetProvider`).

6. **Kurtarıcı Modu (Rescuer Parity)**:
   - Eşlenik filtre bankası (Matched Filter Bank), CFAR dedektörü, analitik I/Q CSS çözücü ve çoklu işaret takipçisi (`BeaconTracker`) iki platformda da aynı algoritmik temeli kullanır.

## Sonuçlar
- Olumlu: Platform bağımsız tam ekosistem uyumu. Enkaz altındaki kurbanın telefonu Android, arayan kurtarıcının telefonu iOS (veya tersi) olduğunda bile akustik ve BLE işaretler kusursuz yakalanır.
- Mimari: `Packages/` (Swift 6) ve `android/` (Kotlin) aynı matematiksel çekirdeğe sadık kalarak bağımsız ve yüksek performanslı native yürütme sağlar.
