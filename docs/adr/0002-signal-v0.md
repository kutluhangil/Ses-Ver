# ADR-0002: SignalSpec v0 — chirp girişi + CSS veri, 1,8–4,2 kHz

- Durum: Önerildi (F0-3 simülasyonu ve F0-4 saha ölçümü sonrası "Kabul" veya "v1 ile değiştirildi" olur)
- Tarih: 2026-10-20
- Sahip: `architect` · Uygulayan: `dsp-acoustics`
- Sözleşme: [docs/contracts/signal-v0.md](../contracts/signal-v0.md)
- İlgili: BLUEPRINT §0.2, §0.3, §2.1 K4/K6, §2.2, §3.3, R1, R6, R8, R9

## Bağlam
İşaret aynı anda üç işi yapmalı:
1. İnsan kulağı ayırt etsin (uygulamasız kurtarıcı için, R8).
2. Kurtarıcının telefonu, kulağın duyamayacağı gürültü altında da yakalasın (menzil ≥ 2× insan, F0 kapısı #2).
3. Veri taşısın: kim (ID), kaç kişi, yaralı, son dokunuş, pil, mod (K4, R6).

Kısıtlar:
- Telefon hoparlörü 1 kHz altında zayıf [Muhtemel].
- Moloz yüksek frekansı daha çok zayıflatır [Muhtemel].
- Kulak güvenliği: 10 cm'de tepe ≤ ~95 dB SPL, görev döngüsü ≤ %12.
- Saat senkronu yok (§0.2).
- Aynı alanda en az 8 işaret ayrılmalı (K6).

## Seçenekler
1. **Sabit ton / düdük benzeri ses (rakiplerdeki gibi).** İnsan için iyi. İşleme kazancı yok, veri yok, çoklu işaret ayrımı yok.
2. **FSK/DTMF benzeri tonlar.** Basit. Çok yollu yayılımda (moloz, oda yankısı) frekans seçici sönüm sembol hatası üretir. Kazanç düşük.
3. **Chirp girişi + CSS (LoRa benzeri) veri, 1,8–4,2 kHz.** Eşlenik filtre kazancı yüksek (BT = 288 → ~24,6 dB). Çok yollu ve frekans kaymasına dayanıklı. Yükselen ıslık insan için tanınabilir bir ritim.
4. **Geniş bant PN dizisi (DSSS).** Kazanç yüksek ama kulağa beyaz gürültü gibi gelir. İnsan için tanınmaz, R8 çözülmez.
5. **Ultrason (> 18 kHz).** İnsan duyamaz. Moloz ve hoparlör yanıtı çok zayıf. Reddedildi.

## Karar
Seçenek 3. Ayrıntılar sözleşmede:
- Giriş: 3 × yükselen chirp (120 ms, 1,8→4,2 kHz, 80 ms boşluk).
- Senk: alçalan chirp (120 ms).
- Veri: 8 × 64 ms CSS sembolü (her biri 4 bit, Gray), toplam 32 bit, CRC-8/AUTOSAR.
- Çerçeve 1 232 ms. Akustik açık kalma süresi 992 ms.
- Aralık: 10/20/45/90 sn, ±%15 rastgele sapma.

Mimari kararlar:
- **Görev döngüsü `Ton / I` ile hesaplanır.** Blueprint'teki 10 sn aralık ve ~1,2 sn çerçeve `Tf / I` = %12,3 verir, bu sınırı aşar. Boşluklar sessiz olduğundan doğru ölçü `Ton / I`'dır: nominal %9,9, en kötü sapmada %11,7. Sınır korunur, aralık tablosu değişmez.
- **CRC başlangıç değeri sıfırdan farklı.** Böylece tamamen sıfır (sessizlik/gürültü kaynaklı) çerçeve geçerli sayılmaz. `0x000` ve `0xFFF` ID'leri ayrılmıştır.
- **Gray eşlemesi.** Komşu kaydırma hatası tek bit hatasına dönüşür. CRC yine yakalar, ama ileride hata düzeltme eklenirse bu eşleme işe yarar.
- **`mode = 3` ve CRC konumu sabit.** v1.1 transponder yanıtları farklı yük taşıyacak. v0 alıcısı onları yine de doğrulayıp sınıflandırabilir.
- **v0-L (1,2–3,0 kHz) yalnızca karşılaştırma varyantı.** Ürüne giremez. Seçilirse v1 olur.

## Sonuçlar
- Olumlu: Tek dalga biçimi hem insana hem makineye hizmet eder. Açık protokol (CC-BY) olarak başka uygulamalar ve ekipmanlar benimseyebilir. Swift tarafı yalnızca vDSP FFT ile uygulanabilir.
- Olumsuz:
  - 32 bit kısıtlı. `people` alanında "belirtilmedi" yok.
  - 12 bit ID ile 8 işarette ≈ %0,7 çakışma olasılığı.
  - Hata düzeltme yok: tek sembol hatası çerçeveyi kaybettirir. Bir sonraki çerçeve 10–90 sn sonra gelir.
- Riskler: İşleme kazancı rakamları [Muhtemel]. Moloz içi yayılım havadaki modelden çok farklı olabilir (R1). F0-3 ve F0-4 bunu ölçer.

## F0-3 sonucu (2026-10-20)
Kaynak: `research/sim/reports/F0-3-report.md`. Etiket: simülasyon, saha değil.
- Eşlenik filtre kazancı ölçüldü: 24,59 dB, teoriyle aynı. Üç chirp birleştirme +4,0 dB (tutarlı olmayan). Blueprint'teki +4,8 dB yalnız üst sınır.
- AWGN'de gereken SNR: tespit (Pd 0,9) −16,2 dB, çözme (FER 0,1) −10,7 dB. **Darboğaz veri bölümü.** Fark, kanala göre 5,5–7 dB.
- Şantiye benzeri sentetik gürültüde tek çerçeve bazında 1,33 sahte çerçeve/saat ölçüldü (hedef ≤ 1). Sözleşme r2'de alıcıya iki çerçeve doğrulaması ZORUNLU yapıldı.
- [Tahmin] moloz modelinde v0-L, aynı hoparlör seviyesinde 3,2–10,1 dB önde. Ancak hoparlörün 1,2 kHz'teki verimi modellenmedi.

**Karar:** v0 F0-4 saha testine bu haliyle girer. Saha testinde v0-L ile karşılaştırılır. Aşağıdaki ilk tetikleyici ateşlendi. Bu yüzden v1 çalışması açıldı (`dsp-acoustics`): sembol düzeyinde hata düzeltme, tutarlı CSS karar kuralı (+1,4–1,5 dB) ve 16 bit CRC seçenekleri. v1, F0-4 verisi gelmeden kesinleşmez.

## Yeniden değerlendirme tetikleyicisi
- F0-3'te FER = 0,1 için gereken SNR, Pd = 0,9 için gerekenden belirgin yüksekse: veri bölümü darboğazdır. Hata düzeltme (ör. Hamming(8,4) sembol düzeyinde) veya daha uzun sembol değerlendirilir. Bu v1 olur.
- F0-4'te v0-L moloz içinde v0'dan ≥ 3 dB iyi çıkarsa.
- Profesyonel dinleme cihazlarının (Delsar, AkuSTECTS) akustik bandı ~3 kHz'te bitiyorsa ve ekipler bu cihazla da duyabilmeyi isterse (docs/research/landscape.md §2/3).
- F0-6'da kurtarıcılar ritmi araç alarmı veya zil sesiyle karıştırırsa.
- Kulak güvenliği ölçümü (F0-4), ≤ 95 dB SPL sınırında menzilin F0 kapısını karşılamadığını gösterirse.
