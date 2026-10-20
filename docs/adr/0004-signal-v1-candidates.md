# ADR-0004: SignalSpec v1 adayları — bant, hata düzeltme, yük düzeni

- Durum: **Taslak / araştırma**. Karar, F0-3b simülasyonu + F0-4 saha verisinden sonra verilir.
- Tarih: 2026-10-20
- Sahip: `architect` · Uygulayan: `dsp-acoustics` (F0-3b)
- İlgili: ADR-0002 (F0-3 sonucu, tetikleyici ateşlendi), signal-v0 r2, `docs/safety/findings-2026-10-20.md` S7, `docs/research/landscape.md` §2/3

## Bağlam
v0 üç zayıflık gösterdi:
1. **Veri bölümü darboğaz.** Çözme (FER 0,1), tespitten (Pd 0,9) 5,5–7 dB daha yüksek SNR istiyor (F0-3). Tespit edilip çözülemeyen bir işaret kurtarıcıya ID ve durum vermiyor.
2. **Bant uyumu.**
   - Profesyonel dinleme cihazlarının akustik sensörü 200–3 000 Hz [Kesin: Savox LD3 datasheet]. v0 (1,8–4,2 kHz) bandının ~yarısı bu bandın dışında.
   - [Tahmin] moloz modelinde 1,2–3,0 kHz, 3–10 dB önde.
   - Ancak telefon hoparlörünün 1,2 kHz'teki verimi ölçülmedi.
3. **Yük alanları.**
   - `people` alanında "belirtilmedi" kodu yok (S7).
   - CRC-8'in yanlış kabul oranı ≈ 1/256. Şimdilik iki çerçeve kuralıyla telafi ediliyor.

Kısıtlar değişmedi:
- Görev döngüsü 60 sn'lik kayan pencerede ≤ %12 (en kısa aralık 8,6 sn'de `Ton` ≤ 1,03 sn).
- İnsan için tanınabilir ritim.
- vDSP ile gerçek zamanlı çözme.
- v0 alıcısı v1 çerçevesini yanlış çözmemeli.

## Seçenekler

### Bant
| Kod | Bant | B | BT (120 ms chirp) | Not |
|---|---|---|---|---|
| B0 | 1,8–4,2 kHz | 2 400 Hz | 288 | v0 |
| B1 | 1,2–3,0 kHz | 1 800 Hz | 216 | Delsar ile uyumlu. Eşlenik filtre kazancı −1,25 dB. |
| B2 | 1,0–2,8 kHz | 1 800 Hz | 216 | Hoparlör verimi daha belirsiz |

### Veri bölümünü güçlendirme
| Kod | Yöntem | Format değişir mi | `Ton` etkisi | Beklenen kazanç [Tahmin] |
|---|---|---|---|---|
| E0 | 16 şablonla tutarlı CSS kararı | Hayır (yalnız alıcı) | 0 | +1,4–1,5 dB (F0-3'te ölçüldü) |
| E1 | Kısaltılmış RS(10,6), GF(16): 6 veri + 4 eşlik nibble'ı, 2 sembol hatası düzeltir. CRC yok, RS sendromu doğrular. | Evet | +128 ms | Ölçülecek |
| E2 | RS(12,8), GF(16): 6 veri + 2 CRC-8 nibble'ı + 4 eşlik nibble'ı | Evet | +256 ms → bütçe aşılır, giriş 2 chirp'e iner | Ölçülecek |
| E3 | Sembol süresi 64 → 96 ms (8 sembol) | Evet | +256 ms | +1,8 dB sembol enerjisi |
| E4 | Yumuşak karar + sembol düzeyinde ardışık iki çerçeveyi birleştirme | Hayır (yalnız alıcı) | 0 | İkinci çerçevede +~3 dB, gecikme bir aralık |

### Yük düzeni
| Kod | Değişiklik |
|---|---|
| P0 | v0 düzeni |
| P1 | `people` 3 bit (0 belirtilmedi, 1–6, 7 = 7+), `battery` 2 bit (4 dilim). Toplam aynı. |

### Sürüm ayrımı
| Kod | Yöntem |
|---|---|
| V-a | Bant değişirse (B1/B2) v0 alıcısının eşlenik filtresi v1 girişini zaten zayıf eşler. Ek senk chirp'i `Ton`'u 120 ms artıracağı için kullanılmaz. F0-3b, v0 alıcısının v1 çerçevelerinde CRC'yi geçen sahte çözüm üretip üretmediğini ölçer. |
| V-b | CRC/RS başlangıç değeri farkı. v0 alıcısı v1 çerçevesini CRC hatası olarak atar. |

## Öneri (ölçüm öncesi, değişebilir)
- **Hemen, v0 içinde:** E0 ve E4 alıcıda uygulanır. Format değişmez, F1'de DetectorKit'e girer.
- **v1 adayı:** B1 + E1 + P1 + V-a.
  - `Ton` ≈ 0,992 + 0,128 = 1,12 sn. En kısa aralık 8,6 sn'de görev döngüsü %13,0, bütçeyi aşıyor.
  - Bu yüzden ya giriş chirp'leri 120 → 100 ms'ye iner (−80 ms) ya da nominal aralık 10 → 11 sn olur. F0-3b ikisini de ölçer.

## F0-3b deney planı (`dsp-acoustics`)
1. E0, E4 alıcı değişikliklerinin v0 üzerindeki kazancı (AWGN + çok yollu + moloz R1–R3).
2. B1 + {E1, E3} kombinasyonlarının Pd/FER eğrileri. Kanallar ve SNR tanımı F0-3 ile aynı.
3. Her aday için yanlış kabul oranı (sentetik şantiye gürültüsü, ≥ 3 sa). İki çerçeve kuralıyla birlikte ve kuralsız.
4. Her aday için `Ton`, en kötü 60 sn görev döngüsü ve CPU.
5. Çıktı: `research/sim/reports/F0-3b-report.md`. Karar tablosu: aday × {FER 0,1 için gereken SNR, yanlış kabul/sa, görev döngüsü, CPU}.

## F0-3b sonucu (2026-10-20)
Kaynak: `research/sim/reports/F0-3b-report.md`, 42/42 test. Eksen SNR_wb, yani aynı hoparlör genliği ve aynı gürültü yoğunluğu. Simülasyon, saha değil.

| Aday | FER 0,1 AWGN | FER 0,1 DRR −6 | FER 0,1 moloz R2 [Tahmin] | Sahte kabul/sa (tek çerçeve) | `Ton` | En kötü 60 sn |
|---|---|---|---|---|---|---|
| v0 | −19,6 | −10,6 | +6,0 | 0,89 | 0,992 | %11,57 |
| v0 + E0 + E4 | −23,3 | −15,3 | +2,1 | 1,28 | 0,992 | %11,57 |
| **B1 + E1 (t=1) + P1 + E4** | **−24,4** | **−16,3** | **−5,1** | **0,61** | 1,120 | %13,07 ✗ |
| B1 + E1 (t=2) | −23,3 | −15,1 | −4,1 | **38,5** ✗ | 1,120 | %13,07 ✗ |
| B1 + E3 + P1 + E4 | −24,6 | −16,8 | −5,6 | 1,06 | 1,248 | %14,56 ✗ |

İki çerçeve kuralıyla sahte kabul her adayda 0 gözlendi (%95 üst sınır 0,20/sa).

**Bulgular:**
1. **E0 + E4, v0 formatını değiştirmeden 3,7 dB (AWGN), 4,7 dB (DRR −6) kazandırıyor.** Bunlar DetectorKit'e girer, sözleşme §6.1'e eklendi.
2. **RS kod çözücüsü en çok 1 sembol düzeltmeli (`t_max = 1`).** `t = 2` rastgele adayların %15,7'sini kabul ediyor. Bu kural sözleşmede ZORUNLU yazılmalı.
3. **Önerilen görev döngüsü telafileri yetmiyor.** 100 ms chirp ile %12,13, 11 sn aralık ile %13,07. Bütçeye sığmanın iki yolu:
   - `Ton` ≤ 1,028 sn olmalı. Örneğin giriş/senk chirp'leri 96 ms olursa `Ton` = 1,024 sn.
   - Ya da nominal aralık ≥ 11,6 sn olmalı.
4. **Yalnız bant farkı (V-a) sürüm ayrımı için yetmiyor.**
   - v0 alıcısı, v1 çerçevelerinin %0,2–1,0'ında CRC'yi geçen sahte çözüm üretiyor.
   - Aynı ID ≈ %4 tekrarlanıyor; bu, iki çerçeve kuralını zayıflatıyor.

**Karar önerisi (onay bekliyor):**
- **v0 hiç yayımlanmaz, ilk yayımlanan protokol v1 olur.** Sahada v0 alıcısı olmayacağı için 4. bulgu ortadan kalkar. Bu, en ucuz çözüm. v0, F0-4 saha karşılaştırması için araştırma formatı olarak kalır.
- v1 = B1 + E1 (`t_max = 1`) + P1, giriş/senk chirp'leri 96 ms. Alıcıda E0 + E4.
- Bant (B1) kararı F0-4 hoparlör ölçümüne bağlı. B1 elenirse aynı yapı B0 bandında kurulur.
- **F0-3c (sonraki simülasyon):** 96 ms chirp ile tespit eşiğinin yeniden kalibrasyonu ve Pd/FER. Ayrıca pembe ve şantiye gürültüsü altında Pd/FER, gerçek işaretin iki çerçeve kuralıyla doğrulanma süresi ve RS silme (erasure) çözme.

## Sonuçlar
- E0/E4 format değiştirmez, risksizdir.
- v1 formatı açık protokol olarak yayımlanmadan önce kesinleşmeli. Yayından sonra değişiklik, sahadaki cihazları böler.
- Bant değişikliği hoparlör ölçümüne (F0-4 Bölüm 1, 0,5–8 kHz sweep) bağlı. Ölçüm gelmeden B1 seçilmez.

## Yeniden değerlendirme tetikleyicisi
- F0-4 sweep'inde iPhone hoparlörünün 1,2–1,8 kHz verimi, 1,8–4,2 kHz ortalamasından ≥ 6 dB düşükse B1 elenir.
- F0-6'da kurtarıcılar v0-L ritmini (ritim_B) zil sesiyle karıştırırsa.
