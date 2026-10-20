# Sözleşme: SignalSpec v0

> Durum: **Taslak, revizyon 2** (F0-3 bulguları işlendi, F0-4 saha ölçümüyle kalibre edilecek). Değişiklikler §10'da.
> Sahip: `architect` · Uygulayanlar: `dsp-acoustics` (Python referans, BeaconKit, DetectorKit)
> Karar kaydı: [ADR-0002](../adr/0002-signal-v0.md) · Kaynak: BLUEPRINT §3.3
> Lisans niyeti: CC-BY 4.0 (yayın kararı BLUEPRINT §10/5'e bağlı)

Bu belge **normatiftir**. "MUST/ZORUNLU" ifadeleri uyumlu her verici ve alıcı için bağlayıcıdır. "Bilgi" başlıklı bölümler normatif değildir.

---

## 1. Sabitler

| Sembol | Değer | Örnek (fs = 48 kHz) |
|---|---|---|
| `fs` | 48 000 Hz (verici ve referans). Alıcı başka fs kullanırsa yeniden örnekler. | — |
| `fL` | 1 800 Hz | — |
| `fH` | 4 200 Hz | — |
| `B` | `fH − fL` = 2 400 Hz | — |
| `Tp` | Giriş/senk chirp süresi, 120 ms | 5 760 |
| `Tg` | Giriş chirp'leri arası boşluk, 80 ms | 3 840 |
| `Ts` | Veri sembolü süresi, 64 ms | 3 072 |
| `M` | Sembol alfabesi, 16 (4 bit) | — |
| `Nsym` | Çerçevedeki veri sembolü sayısı, 8 | — |
| `Tf` | Çerçeve süresi, 1 232 ms | 59 136 |
| `Ton` | Akustik açık kalma süresi (boşluklar hariç), 992 ms | 47 616 |

Bant varyantı **v0-L** (1,2–3,0 kHz, `B` = 1 800 Hz) yalnızca F0-3/F0-4 karşılaştırması içindir. Ürüne giremez; seçilirse v1 olur.

## 2. Çerçeve düzeni

Örnek indeksleri çerçeve başlangıcına (ilk giriş chirp'inin ilk örneği, `n = 0`) göredir.

| Öğe | Başlangıç | Bitiş (hariç) | İçerik |
|---|---|---|---|
| U1 | 0 | 5 760 | Yükselen chirp |
| G1 | 5 760 | 9 600 | Sessizlik |
| U2 | 9 600 | 15 360 | Yükselen chirp |
| G2 | 15 360 | 19 200 | Sessizlik |
| U3 | 19 200 | 24 960 | Yükselen chirp |
| G3 | 24 960 | 28 800 | Sessizlik |
| D | 28 800 | 34 560 | Alçalan senk chirp'i |
| S0…S7 | 34 560 + i·3 072 | 34 560 + (i+1)·3 072 | Veri sembolleri, boşluksuz |

Ritim (insan için): "üç yükselen ıslık, kısa duraklama, alçalan ıslık + cıvıltı".

## 3. Dalga biçimi

Tüm öğeler gerçek değerli, `x[n] = A · w[n] · sin(φ[n])`, `t = n / fs`, `n = 0 … N−1`. Her öğe kendi yerel zamanında `φ(0) = 0` ile başlar.

### 3.1 Yükselen chirp (U1–U3)
`φ(t) = 2π · (fL·t + (B / (2·Tp)) · t²)`

### 3.2 Alçalan senk chirp'i (D)
`φ(t) = 2π · (fH·t − (B / (2·Tp)) · t²)`

### 3.3 Veri sembolü (CSS, döngüsel kaydırmalı yükselen chirp)
Kaydırma `s ∈ {0…15}`. Chirp hızı `k = B / Ts`. Sarma anı `tw = Ts · (1 − s/M)`. Örnek indeksinde: `n < 3 072 − 192·s` ilk bölüm, kalan örnekler ikinci bölüm.

- `0 ≤ t < tw`: `φ(t) = 2π · ((fL + s·B/M)·t + (k/2)·t²)`
- `tw ≤ t < Ts`: `φ(t) = φ(tw) + 2π · (fL·(t − tw) + (k/2)·(t − tw)²)`

Anlık frekans `fL + ((s·B/M + k·t) mod B)`. Sembol içinde faz süreklidir. `s = 0` için sarma yoktur.

### 3.4 Pencere (`w[n]`)
- U, D: başta ve sonda 5 ms (240 örnek) yarım-Hann rampa.
- Veri sembolü: başta ve sonda 2 ms (96 örnek) yarım-Hann rampa.
- Yarım-Hann giriş rampası: `w[n] = 0.5 · (1 − cos(π · n / R))`, `n = 0 … R−1`, `R` rampa uzunluğu.
- Çıkış rampası: `w[N − 1 − n] = 0.5 · (1 − cos(π · n / R))`, `n = 0 … R−1`. Aradaki örneklerde `w = 1`.

### 3.5 Genlik
- Dijital tepe `A = 10^(−1/20)` ≈ 0,891 (−1 dBFS). Tüm öğeler aynı genlikte.
- Akustik çıkış `outputGain ∈ (0, 1]` ile çarpılır. `outputGain` üst sınırı her cihaz modeli için F0-4'te ölçülür ve **10 cm'de tepe ≤ 95 dB SPL** koşulunu (BLUEPRINT §2.2, R9) sağlayacak şekilde sabitlenir. Ölçülmemiş modelde varsayılan 1,0 kullanılır ve bu durum `docs/safety/` altında açık risk olarak kalır.

## 4. Yük (payload)

32 bitlik sözcük `W`, en anlamlı bit önce (MSB first). Alanlar tablo sırasıyla yerleşir.

| Alan | Bit aralığı (W içinde) | Genişlik | Kodlama |
|---|---|---|---|
| `id` | 31…20 | 12 | Her etkinleştirmede rastgele. `0x000` ve `0xFFF` ayrılmış, kullanılmaz. Gösterim: `K-` + 3 hane büyük harf hex (ör. `K-7F2`). |
| `people` | 19…18 | 2 | 0 → 1 · 1 → 2 · 2 → 3 · 3 → 4+ |
| `injured` | 17 | 1 | 1 = yaralı var |
| `lifeAge` | 16…13 | 4 | §4.1 |
| `battery` | 12…10 | 3 | `min(7, floor(yüzde / 12,5))` → 0 (%0–12) … 7 (≥ %87,5) |
| `mode` | 9…8 | 2 | 0 canlı · 1 zincir (Katman 2) · 2 Gece Nöbeti otomatik · 3 yanıt (v0'da ayrılmış) |
| `crc` | 7…0 | 8 | §4.2 |

### 4.1 `lifeAge` dilimleri (son "Buradayım" dokunuşundan beri)
| Kod | Dilim | Kod | Dilim |
|---|---|---|---|
| 0 | < 1 dk | 8 | 2–4 sa |
| 1 | 1–2 dk | 9 | 4–8 sa |
| 2 | 2–5 dk | 10 | 8–12 sa |
| 3 | 5–10 dk | 11 | 12–24 sa |
| 4 | 10–20 dk | 12 | 24–36 sa |
| 5 | 20–30 dk | 13 | 36–48 sa |
| 6 | 30–60 dk | 14 | > 48 sa |
| 7 | 1–2 sa | 15 | bilinmiyor |

Alt sınır dahil, üst sınır hariç. `mode = 1` (zincir) çerçevelerinde `lifeAge`, zincir planlandığı andaki değerle sabitlenir. Alıcı bu çerçevelerde **canlılık bilgisi yok** göstermelidir.

### 4.2 CRC
- CRC-8/AUTOSAR: polinom `0x2F`, başlangıç `0xFF`, yansıtma yok, çıkış XOR `0xFF`. Kontrol değeri: ASCII `"123456789"` → `0xDF`.
- Girdi: `W >> 8` sayısının 3 baytı, büyük uçlu (big-endian) sırada.
- Gerekçe: sıfırdan farklı başlangıç, tamamen sıfır bir çerçevenin geçerli sayılmasını önler. 24 bit veride Hamming mesafesi 4 [Muhtemel, Koopman tablolarına göre; `dsp-acoustics` doğrulayacak].

### 4.3 Sembol eşlemesi
- Dörtlü (nibble) `n_i = (W >> (28 − 4·i)) & 0xF`, `i = 0 … 7` (en anlamlı dörtlü önce).
- Verici kaydırması `s_i = G⁻¹(n_i)`, alıcı `n̂_i = G(ŝ_i)`. Burada `G(x) = x ⊕ (x >> 1)` (Gray kodu).
- Gerekçe: komşu kaydırma hatası (`s ± 1`, 15↔0 dahil) tek bit hatasına dönüşür.

## 5. Zamanlama (verici)

| Etkinleştirmeden beri | Nominal aralık `I` |
|---|---|
| 0–6 sa | 10 sn |
| 6–24 sa | 20 sn |
| 24–72 sa | 45 sn |
| 72+ sa | 90 sn |
| Pil < %20 | Aralık × 2 |

- Gerçek aralık `I · U(0,86; 1,15)`, her çerçevede bağımsız. Çakışan işaretlerin ayrışması için ZORUNLU.
- Aralık, çerçeve başlangıçları arasındaki süredir.
- **Görev döngüsü (bilgi):** `Ton / I`. Nominal 10 sn'de %9,9. `Tf / I` (%12,3) değil `Ton / I` esas alınır, çünkü boşluklar sessizdir.
- Kulak güvenliği gereği hiçbir mod, 60 sn'lik herhangi bir kayan pencerede görev döngüsünü %12'nin üstüne çıkaramaz. Transponder yanıtları (v1.1) bu bütçeye dahildir.
- Sapma alt sınırı 0,86 olunca en kötü 60 sn penceresi %11,57 olur (F0-3'te ölçüldü). 0,85'te bu değer %12,41'di ve sınırı aşıyordu. Verici ayrıca her çerçeveden önce son 60 sn'lik açık kalma süresini kontrol eder. Sınır aşılacaksa çerçeveyi erteler.

## 6. Alıcı gereksinimleri

- Saat farkı toleransı: vericiyle alıcı arasında ±100 ppm (çerçeve boyunca ≤ 6 örnek kayma; sembol kaydırma adımı 192 örnek).
- Çerçeve ancak CRC doğruysa raporlanır. `id ∈ {0x000, 0xFFF}` olan çerçeve reddedilir.
- **İki çerçeve doğrulaması (ZORUNLU).** CRC-8, yanlış çözülen adayların ≈ 1/256'sını geçirir. F0-3'te sentetik şantiye gürültüsünde tek çerçeve bazında 1,33 sahte çerçeve/saat ölçüldü (hedef ≤ 1). Bu yüzden:
  - Tek CRC'li çerçeve "doğrulanmamış" durumundadır. Arayüz bunu soluk gösterir ve sesli/titreşimli uyarı vermez.
  - Bir işaret, aynı `id` ile ikinci bir geçerli çerçeve geldiğinde "doğrulanmış" olur. Koşullar: iki çerçeve arası süre `[0,86·10 sn, 1,15·180 sn]` aralığında olmalı. `people` ve `injured` alanları aynı olmalı. `lifeAge` geri gitmemeli, ancak "Buradayım" dokunuşuyla sıfırlanabilir.
  - Doğrulanmamış kayıt 10 dk içinde ikinci çerçeve gelmezse listeden düşer, ama dışa aktarılan kayıtta kalır.
- Alıcı bandı: v0 için 1,5–4,5 kHz. v0-L için 0,9–3,3 kHz.
- **SNR tanımı** (raporlama ve kabul testleri için): alıcı bandı içindeki işaret gücünün aynı banttaki gürültü gücüne oranı, `Ton` süresi üzerinden. Yankı enerjisi işaretin parçası sayılır.
- `mode = 3` olan çerçeve v0 alıcısında "yanıt çerçevesi" olarak sınıflandırılır. Diğer alanları yorumlanmaz.
- Aynı `id` en az 8 farklı işaret için ayrı izlenir (K6).

### 6.1 Önerilen alıcı hattı (bilgi)
1. 1,5–4,5 kHz bant geçiren filtre.
2. Yükselen chirp şablonuyla eşlenik filtre (overlap-save FFT korelasyonu).
3. CFAR eşiği. Üç tepe, 9 600 örnek aralıkla (± birkaç örnek) doğrulanır. Tutarlı olmayan birleştirme ≈ +4,0 dB kazanç sağlar (F0-3'te ölçüldü). +4,8 dB yalnızca tutarlı birleştirmenin üst sınırıdır.
4. Alçalan senk chirp'i ile ince zamanlama. Yükselen ve alçalan chirp birlikte, zaman-frekans belirsizliğini çözer.
5. Her sembolde analitik sinyal × eşlenik taban chirp'i (dechirp), FFT. Kaydırma `s`, `s·B/M` ve `s·B/M − B` frekanslarındaki enerjilerin toplamıyla seçilir. Bunun nedeni, aşırı örneklenmiş CSS'de sarma sonrası bölümün ayrı bir frekansa düşmesidir. Alternatif: 16 şablonla tutarlı korelasyon. F0-3'te 1,4–1,5 dB daha iyi çıktı, CPU maliyeti daha yüksek. Swift uygulamasında seçim CPU ölçümüne göre yapılır.

Ölçülen gereken SNR (F0-3, AWGN, v0): tespit Pd = 0,9 için −16,2 dB, çözme FER = 0,1 için −10,7 dB. Sınırlayan halka veri çözmedir. Ayrıntı: `research/sim/reports/F0-3-report.md`.

## 7. Test vektörleri

- Konum: `research/signal/vectors/v0/`.
- Her vektör: `<ad>.json` (alanlar, `W` hex, CRC, nibble'lar, kaydırmalar) ve `<ad>.f32` (tam çerçeve, küçük uçlu float32, `A` dahil, `outputGain = 1`).
- Eşleşme ölçütü (Python ↔ Swift):
  - Bitler, CRC, nibble'lar ve kaydırmalar: **birebir aynı**.
  - Dalga biçimi: her örnekte `|Δ| ≤ 1e−4`. Trigonometri kütüphaneleri bit düzeyinde aynı sonuç vermez, bu yüzden dalga biçiminde tolerans tanımlanır.
- Asgari vektör kümesi: tüm alanlar en düşük geçerli değerde, tüm alanlar en yüksek değerde, her `mode` değeri, her `lifeAge` kodu, `id = 0x7F2` (tasarım örneği), rastgele 32 vektör (sabit tohum).

## 8. Sürümleme ve uyumluluk

- v0'da sürüm alanı yoktur. Sonraki sürümler, v0 alıcısının yanlış çözmeyeceği şekilde ayırt edilmelidir: farklı senk deseni **veya** CRC başlangıç değeri farkı. Seçim v1 ADR'sinde yazılır.
- v1 yanıt çerçeveleri (`mode = 3`) `mode` (bit 9…8) ve `crc` (bit 7…0) konumlarını korur. Böylece v0 alıcısı onları doğrulayıp sınıflandırabilir.
- Her değişiklik yeni sürüm numarası alır. Değişiklik notu, eski sürümle çözülebilirlik durumunu içermek ZORUNDADIR.

## 9. Bilinen sınırlar (bilgi)

- **ID çakışması:** 12 bit, 4 094 kullanılabilir değer. 8 eşzamanlı işarette en az bir çakışma olasılığı ≈ %0,7. Alıcı, aynı `id`'yi farklı ritim fazıyla görürse "olası çakışma" işaretler.
- **`people` alanı:** "belirtilmedi" ile "1 kişi" ayırt edilemez. Kullanıcı seçim yapmadıysa 0 (1 kişi) gönderilir. Kurtarıcı arayüzü bunu "≥ 1 kişi" diye gösterir. Açık soru: `safety-redteam` v1'de "belirtilmedi" kodu ister mi?
- **Moloz:** Dalga biçimi havada tasarlanmıştır. Moloz içindeki yayılım (BLUEPRINT §0.2) F0-3 modeli ve F0-4 saha verisiyle değerlendirilecektir.
- **CRC uzunluğu:** CRC-8 ile Hamming mesafesi 4 (F0-3'te kaba kuvvetle doğrulandı). Ancak yanlış kabul oranı ≈ 1/256. İki çerçeve doğrulaması (§6) bunu telafi eder. v1'de daha uzun CRC veya hata düzeltme değerlendirilir (ADR-0002).

## 10. Değişiklik günlüğü

| Revizyon | Tarih | Değişiklik | Eski revizyonla çözülebilirlik |
|---|---|---|---|
| r1 | 2026-10-20 | İlk taslak | — |
| r2 | 2026-10-20 | F0-3 bulguları: sapma alt sınırı 0,85 → 0,86 ve vericide 60 sn pencere kontrolü (§5) · iki çerçeve doğrulaması ZORUNLU (§6) · v0-L alıcı bandı, SNR tanımı (§6) · +4,8 → +4,0 dB (§6.1) · sarma indeksi ve çıkış rampası formülü (§3) | **Tam.** Dalga biçimi, yük ve CRC değişmedi. Değişiklikler yalnız zamanlama ve alıcı davranışını etkiliyor. Bu yüzden sürüm v0 olarak kalır. |
