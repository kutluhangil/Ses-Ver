# F0-4 Saha akustiği protokolü + F0-6 Görüşme rehberi

> Tek sayfa, sahaya basılı götürülür. Sürüm 0.1 · 2026-10-20 · Sahip: Orkestratör → `field-qa`
> Kapı: F0 kapısı #1 (insan kulağı moloz içinden duyuyor), #2 (uygulama menzili ≥ 2× insan), kulak güvenliği (≤ 95 dB SPL / 10 cm).
> Kural: Başarısız sonuç silinmez, yumuşatılmaz.

---

## A. F0-4 Saha akustiği

### A1. Ekipman
| Kalem | Adet | Not |
|---|---|---|
| Ses seviye ölçer, IEC 61672 Sınıf 1 (olmazsa Sınıf 2) + akustik kalibratör (94 dB, 1 kHz) | 1 + 1 | LAFmax, LCpeak, LAeq. Her oturum başı ve sonu kalibrasyon. |
| Ölçüm mikrofonu + kaydedici (48 kHz / 24 bit, AGC kapalı) | 1 | Referans kayıt. Kalibre ton ile seviye bağlanır. |
| Verici iPhone'lar | 6 model | Örn. SE (3. nesil), 12, 13, 14, 15 Pro, 16. Her biri kılıflı ve kılıfsız. Ses %100, Düşük Güç Modu açık. |
| Alıcı iPhone'lar (FieldRecorder) | 2 | `Tools/FieldRecorder`: `measurement` modu, 48 kHz, deneme formu, CSV + JSON yan dosya. Cihazda doğrulanmadıysa sahadan önce bir tezgâh denemesi yapılır. |
| Test sesi | — | `research/signal/vectors/` + v0 ve v0-L çerçevelerini karışık sırayla çalan liste (A3). |
| Telefon kafesi (delikli metal), ip/tasma, 5 cm PVC boru | 6 | Telefonun kaybolmaması ve ezilmemesi için. Kapalı poşet **kullanılmaz** (ses zayıflar). |
| Şerit metre 30 m, lazer metre, işaret bayrakları | — | Gerçek konum. Fotoğrafla birlikte kaydedilir. |
| Termometre/nem ölçer, rüzgârölçer | 1 | Rüzgâr > 5 m/sn ise ölçüm ertelenir. |
| Kalibre "boşluk kutusu" 50×50×50 cm (beton/tahta) | 1 | Kulak güvenliği: kapalı boşlukta SPL birikimi. |
| KKD: baret, çelik burun bot, eldiven, FFP2, gözlük | Kişi başı | Saha güvenlik sorumlusu onayı olmadan enkaza çıkılmaz. |

### A2. Ölçüm matrisi
**Bölüm 1, tezgâh (açık alan veya sessiz oda, 1 gün):**
6 model × {kılıflı, kılıfsız} × {hoparlör yukarı, ekran aşağı zeminde, kutu içinde}. Mesafe 10 cm ve 1 m. Ölçülenler:
- LCpeak ve LAFmax (10 cm). → Model başına `outputGain` üst sınırı (≤ 95 dB SPL tepe).
- 1 m'de LAeq. → Kaynak seviyesi.
- 0,5–8 kHz log sweep kaydı. → Hoparlör frekans yanıtı (v0 ve v0-L bantları).

**Bölüm 2, moloz (yıkım alanı / eğitim enkazı, 2 gün):**
3 moloz tipi × 3 derinlik × 2 model (Bölüm 1'deki en yüksek ve en düşük sesli) × 6 dinleyici noktası.
- Moloz tipleri: M1 iri beton blok, boşluklu · M2 tuğla/duvar, ince moloz · M3 karışık (sıva tozu, ahşap, toprak).
- Derinlik (yüzeyden düz çizgi): D1 0,5 m · D2 1,5 m · D3 3 m. Erişilemiyorsa ulaşılan en büyük derinlik yazılır.
- Dinleyici noktaları (yüzeyde, telefonun izdüşümünden yatay): 0 · 2 · 5 · 10 · 15 · 20 m.
- Her noktada ~2 dk: v0 ve v0-L çerçeveleri karışık, 5 sn aralıkla, her birinden 10 çerçeve. Çerçevelerin %20'si boş (yakalama denemesi).
- Toplam ≈ 18 yapılandırma × 6 nokta × 2 dk ≈ 3,6 saat net ölçüm.
- Gürültü: Kayıtlar **sessizlik anında** alınır. Şantiye, jeneratör ve kalabalık gürültüsü ayrı kaydedilir ve SNR kontrolü için çevrimdışı karıştırılır (`research/field_analysis`). İnsan dinleyici yalnız sessizlik koşulunda test edilir.

### A3. İnsan dinleyici
- 3 dinleyici, normal işitme (beyan). Kör deneme: dinleyici sinyalin ne zaman çalacağını bilmez.
- Her 5 sn'lik pencere için "duydum / duymadım" + yön (8 yön) işaretler.
- Ölçüt: sessizlik anında %90 doğru algılama. Yanlış "duydum" oranı da raporlanır.

### A4. Deneme kaydı (her satır bir nokta)
Boş CSV şablonları: `forms/F0-4_deneme.csv` (moloz) ve `forms/F0-4_tezgah.csv` (tezgâh). FieldRecorder moloz formunu otomatik doldurur.

| Alan | Örnek |
|---|---|
| Tarih/saat, oturum, operatör | 2026-11-12 10:40, S2, Op-A |
| Verici: model, iOS, ses %, kılıf, yönelim, `outputGain` | iPhone 13, 26.x, 100, silikon, ekran aşağı, 1,0 |
| Konum (gerçek): moloz tipi, derinlik m, foto no | M2, 1,5, IMG_0412 |
| Dinleyici noktası: yatay m, yükseklik m | 10, 0 |
| Ortam: gürültü dB(A) LAeq 30 sn, sıcaklık, nem, rüzgâr | 41, 14 °C, %60, 1 m/sn |
| İnsan sonucu: doğru/yanlış/kaçırılan, yön | 8/10, 1 yanlış, K |
| Makine sonucu (çevrimdışı): tespit, CRC geçen, SNR dB | sonradan doldurulur |
| Kayıt dosyaları | `raw/S2/P10_M2_D15_13.wav` |
| Not | "Boşluk büyük, yankı var" |

### A5. Çıktı
- Menzil tablosu: moloz × derinlik × model → insan için ve uygulama için en büyük algılama mesafesi.
- `outputGain` tablosu (model başına).
- Kapı #1 ve #2 için evet/hayır ve sayılar. Geçilmezse BLUEPRINT §6'daki yön değiştirme planı uygulanır.

### A6. Güvenlik
- Saha sahibinin yazılı izni ve saha güvenlik sorumlusu zorunlu.
- Telefonlar enkaza boru veya ip ile indirilir. Kimse enkaz boşluğuna girmez.
- Kulak güvenliği: kutu içi ölçümde kulak koruyucu takılır.

---

## B. F0-6 Paydaş görüşme rehberi

- **Katılımcılar:** ≥ 5 kişi (AKUT, GEA, UMKE, gönüllü ekipler; en az biri ekip lideri). Ayrıca TÜBİTAK MAM teması.
- **Format:** Yarı yapılandırılmış, 45 dk, yüz yüze veya görüntülü. Analiz `design:research-synthesis` ile.
- **Onam:** Görüşme öncesi KVKK aydınlatma metni ve yazılı onam alınır: `F0-6_F0-7_onam.md`. Kayıt yalnız onayla yapılır. Depoya yalnız takma ad (P1…P5) ve not girer, ham kayıt girmez.
- **Kural:** Yönlendirici soru yok. "Kullanır mısınız?" yerine geçmiş davranış sorulur.

### B1. Akış
1. **Isınma (5 dk):** Rolünüz, kaç yıl, hangi operasyonlar (ör. 6 Şubat 2023)?
2. **Bugünkü pratik (10 dk):**
   - Son operasyonda canlı birini nasıl buldunuz? Adım adım anlatın.
   - "Sessizlik" nasıl ilan ediliyor? Ne kadar sürüyor? Kim karar veriyor?
   - Hangi dinleme cihazlarını kullandınız? Nerede yetersiz kaldılar?
   - Enkaz altından telefon sesi, alarm veya düdük duyduğunuz oldu mu? Ne yaptınız? Sizi yanlış yere götürdüğü oldu mu?
   - Sahada telefonu dinleme aracı olarak kullandınız mı? (Örn. İTÜ uygulaması)
3. **Ritim testi (10 dk):** 3 aday ritmi rastgele sırayla dinletin (v0, v0-L, alternatif ritim, `research/signal` üretir). Ardından araç alarmı ve zil sesi de çalınır.
   - Hangisi "enkaz altında biri" gibi geliyor? Hangisi başka bir şeyle karışır?
   - 1–5 ölçeğinde ayırt edilebilirlik.
4. **Araç akışı (10 dk):** Kâğıt prototip (Dinle listesi, Sıcak-soğuk ekranı).
   - Telefonu kim tutar? Eldivenle kullanılabilir mi?
   - Ekip lideriyle nasıl koordine edilir?
   - Hangi bilgi sıralamayı değiştirir: kişi sayısı, yaralı, son dokunuş? Bunları sıralayın.
   - "Otomatik yedek zincir · canlılık bilgisi yok" kartını nasıl yorumlarsınız?
5. **Güven ve risk (5 dk):** Bu araç yanlış yere yönlendirirse ne olur? Boş binadan gelen işaret? Sivillerin enkaza çıkması?
6. **Benimseme ve işbirliği (5 dk):**
   - Ekibinize yeni bir araç nasıl girer? Kim onaylar, nasıl eğitim verilir?
   - Açık bir sinyal protokolü sizin için değerli mi? Mevcut ekipmanınızla (Delsar vb.) duyulması önemli mi?
   - Kimle konuşmalıyız?

### B2. Çıktı (görüşme başına 1 sayfa)
Ritim tercihi + puanlar · Mevcut iş akışı (adımlar) · Alan önceliği sırası · Davranışa dayalı benimseme işaretleri · İşbirliği yolu ve kişi · Alıntılar (takma adla) · Sürprizler.
Beş görüşme sonunda sentez: `docs/field/F0-6-sentez.md`.
