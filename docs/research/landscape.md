# F0-1: Rakip ve literatür taraması

- Tarih: 2026-10-20 · Hazırlayan: Orkestratör · Yöntem: web taraması (kaynaklar her satırda)
- Etiketler BLUEPRINT ile aynı: [Kesin] birincil kaynak · [Muhtemel] ikincil kaynak/basın · [Tahmin] çıkarım
- **Sınır:** Bu tarama basın ve mağaza sayfalarına dayanıyor. Hiçbir uygulama cihazda denenmedi. "Ne yapmıyor" sütunu, kaynakta **bahsedilmeyen** özellikleri gösterir, kanıtlanmış yokluğu değil. Cihazda doğrulama F0-1b olarak açık.

## 1. Özet tablo

| # | Çalışma | Tür | Ne yapıyor | Ne yapmıyor (kaynakta yok) | Ses Ver'e etkisi | İşbirliği |
|---|---|---|---|---|---|---|
| 1 | **Düdüğüm** | Android/iOS uygulama (TR) | Düdük, fener, 112, iki kişiye konum SMS'i, açılınca sesi en yükseğe çıkarma, güvendeyim/değilim [Muhtemel] | Veri taşıyan sinyal, kurtarıcı tarafı, kilitliyken başlatma, pil bütçesi | Rakip. Sesi otomatik yükseltme Android'de mümkün, iOS'ta herkese açık API yok (BLUEPRINT §3.2). | Düşük |
| 2 | **Deprem Düdüğü (Whistle)** | Android uygulama | Reklamsız, internetsiz, ekran kapalıyken düdük [Muhtemel] | Aynı | Rakip | Düşük |
| 3 | **"Real Whistle"** | iOS | Bu adla iOS uygulaması **bulunamadı**. En yakın: *Whistle for Sport & SOS* (ExaMobile), döngüsel SOS düdüğü [Muhtemel] | Aynı | BLUEPRINT §0.3'teki ad düzeltilmeli | Düşük |
| 4 | **AFAD Acil Çağrı** | Resmi uygulama | 112'ye sesli/mesajlı çağrı, hazır durum cümleleri, toplanma alanları. Şebeke ve internet gerektirir [Muhtemel] | İnternetsiz çalışma, akustik işaret | Tamamlayıcı. Ses Ver şebeke yokken devreye girer. Hazırlık ekranı AFAD Acil'i önerebilir. | Orta (kurumsal kapı) |
| 5 | **Acil İzmir** (İzmir BB) | Belediye uygulaması | "Enkaz altındayım" düğmesi, konumla yardım çağrısı, **Bluetooth yayını**, sesli yönlendirme [Muhtemel] | Akustik veri sinyali, kurtarıcı aracı (kaynakta yok) | **En yakın yerel benzer.** BLE yayın biçimi öğrenilmeli. Ortak BLE UUID'si veya birlikte çalışabilirlik konuşulabilir. | **Yüksek** |
| 6 | **TÜBİTAK MAM ATEAS** (IMDAT + YARASA) | Ar-Ge, 2 Android uygulama | Kurban (IMDAT) ve kurtarıcı (YARASA) uygulamaları. GSM çökmüşken durum ve konum tespiti hedefleniyor [Kesin: TÜBİTAK MAM] | iOS (kaynakta yok). Olgunluk ve saha kullanımı bilinmiyor. İletişim kanalı (BLE/Wi-Fi/akustik) belirtilmemiş. | Kavram olarak en yakın. **Rakip değil, ortak adayı** (BLUEPRINT §0.3). iOS tarafını Ses Ver tamamlayabilir. | **Yüksek** |
| 7 | **TÜBİTAK MAM AkuSTECTS** | Donanım prototipi | 3 jeofon + akustik sensör + kulaklık + operatör paneli, kablosuz kit. Sismik bileşen yabancı muadilinden hassas bulunmuş. AFAD ile seri üretim görüşmesi [Kesin: TÜBİTAK] | Kurban tarafı işareti | Kurtarıcı tarafında profesyonel alternatif. Ses Ver sinyali AkuSTECTS'in akustik kanalında da algılanabilir mi? [Tahmin] Bant 3 kHz üstüne çıkıyorsa belirsiz. | **Yüksek** |
| 8 | **İTÜ MİAM Enkaz Dinleme** | Web uygulaması (2023) | Telefon mikrofonundan 350–5 000 Hz bant filtre + kazanç. İnternetsiz çalışır, kayıt cihaz dışına çıkmaz. Yarım günde yazılmış. Bazı iOS cihazlarda çalışmadığı bildirilmiş [Muhtemel] | Sinyal çözme, işaret tanıma, yer kestirimi | Kurtarıcıların telefonu "dinleme aracı" olarak kullanmaya **istekli** olduğunun kanıtı. F0 kapısı geçilmezse varılacak "kurtarıcı dinleme aracı" (BLUEPRINT §6) ile örtüşür. | Orta (akademik, Dr. Ozan Sarıer) |
| 9 | **Takada, Tokyo Üniv. (ASA/ASJ, Aralık 2025)** | Akademik bildiri | Ters yön: kurtarıcı iki dipol (+ moloz için monopol) ses yayar, kurbanın telefonu dinler ve konumu radyo ile iletir. Eğitim enkazında 10 m² alanda 5,04° açı hatası. Kurbanın yanıt vermesi gerekmiyor [Muhtemel: basın bülteni] | Kurbanın telefonunda dinleyen bir uygulama gerekir. Radyo bağlantısı gerekir. Hakemli makale bulunamadı. | Pil yetmezse BLUEPRINT §6'daki B planı. Monopol + dipol fikri v1.1 transponder tasarımına girdi. | Orta (akademik) |
| 10 | **BeepBeep (Peng vd., SenSys 2007; TECS 2012)** | Akademik yöntem | İki yönlü algılama + kendi kaydını dinleme + örnek sayma ile saat senkronsuz mesafe. Açık alanda ~1–2 cm, >10 m menzil [Kesin: makale] | Moloz, çok yollu yayılım, düşük SNR. Ayrıca taraflar arası veri kanalı varsayar. | BLUEPRINT §3.4.3'ün temeli. Ses Ver'de Δv akustik yanıtın içine kodlanır, ayrı veri kanalı gerekmez (bu bir tasarım farkı). | — |
| 11 | **Tai & Yu, Sensors 2022** | Akademik | Kurbanın telefonu BLE işareti/otomatik yanıt verir. Ahşap ve kiremit altında ~2 m hata [Muhtemel: PMC özeti] | Akustik | BLE kanalının (BLUEPRINT §3.2) moloz altında da işe yarayabildiğine dair destek | — |
| 12 | **Telefon mikrofonuyla nefes/kalp atışı algılama (2023 poster)** | Akademik | Derin öğrenmeyle cihazda canlılık belirtisi algılama [Muhtemel] | — | Uzak backlog: kurtarıcı tarafında "vuruntu/ses" algılama (B planı) | — |
| 13 | **Profesyonel dinleme cihazları (Delsar LifeDetector LD3, Mini)** | Ticari donanım | Sismik + akustik sensörler, çok sensörlü güç karşılaştırması. Mini: 2 sismik + 1 akustik, 1 Hz–3 kHz, ~10 sa pil, IP67 [Muhtemel: satıcı] | Kurban tarafı işareti, veri | Sıcak-soğuk yöntemimiz (§3.4.2) aynı ilkeyle (sensörler arası güç karşılaştırması) çalışır. Delsar bandı ~3 kHz'te bitiyor. v0 bandının (1,8–4,2 kHz) üst yarısı bu cihazlarla duyulmayabilir [Tahmin]. | Düşük (ticari) |
| 14 | **ABD patenti 9 591 466** "emergency beacon signal" etkinleştirme | Patent | Enkaz altındaki akıllı telefonun işaret sinyali vermesi | — | **FTO (serbest kullanım) incelemesi gerekli.** Kapsamı okunmadı. → `legal:legal-risk-assessment`, R12 | — |

## 2. Çıkarımlar

1. **Savunulabilir fark tutarlı.** Hiçbir kaynakta şu dört şey birlikte yok (BLUEPRINT §0.3):
   - Veri taşıyan ve işleme kazancı olan sinyal
   - Uygulama kapalıyken süren zincir
   - 72 saat pil bütçesi
   - iOS kurtarıcı aracı
2. **Yerelde en yakın iki aktör ATEAS ve Acil İzmir.** İkisi de rakip olmaktan çok birlikte çalışabilirlik ortağı. Ortak bir BLE UUID'si ve açık SignalSpec, "her uygulama kendi sinyalini çalar" parçalanmasını önler.
3. **Bant uyumu sorusu yeni.** Profesyonel dinleme cihazları ~3 kHz'te bitiyor [Muhtemel]. Uygulamasız kurtarıcının **cihazla** da duyabilmesi için v0-L (1,2–3,0 kHz) varyantı yalnız moloz için değil, ekipman uyumu için de değerlendirilmeli. → ADR-0002 yeniden değerlendirme tetikleyicisine eklendi (F0-3/F0-4 karşılaştırması).
4. **Takada yaklaşımı B planı olarak somut.** Ancak kurban tarafında dinleyen uygulama ve radyo yolu gerektirir. Pil açısından avantajı F0-5'e göre değerlendirilmeli.
5. **İTÜ örneği talebi gösteriyor.** Kurtarıcılar sahada telefonla dinlemeye zaten başvurmuş. Kurtarıcı aracının benimsenme riski (R8) bu kanıtla biraz azalıyor [Tahmin].
6. **Patent riski açık.** FTO incelemesi F1'den önce yapılmalı.

## 3. Açık işler

| ID | İş | Sahip |
|---|---|---|
| F0-1b | Düdüğüm, Whistle for Sport & SOS, Acil İzmir ve AFAD Acil'i iPhone'a kurup gerçek davranışı not etmek: kilitliyken başlatma, arka planda süre, ses düzeyi davranışı | İnsan + `field-qa` |
| F0-1c | Acil İzmir'in Bluetooth yayın biçimi (UUID, içerik) | `ios-platform` (BLE tarayıcı spike'ı ile) |
| F0-1d | ATEAS (IMDAT/YARASA) iletişim kanalı ve durumu: TÜBİTAK MAM'a temas (**insan onayı gerekli**, CLAUDE.md) | İnsan |
| F0-1e | ABD 9 591 466 ve benzeri patentlerin kapsam okuması | `legal:legal-risk-assessment` + avukat |
| F0-1f | Delsar/AkuSTECTS akustik sensör frekans yanıtı (datasheet) | Orkestratör |
| F0-1g | Takada ASA bildirisinin özetini veya makalesini bulmak | Orkestratör |
| — | BLUEPRINT §0.3'te "Real Whistle" adı düzeltilmeli | Orkestratör |

## Kaynaklar
- [Düdüğüm (tamindir)](https://www.tamindir.com/indir/dudugum/) · [Afet sonrası uygulamalar (CNN Türk)](https://www.cnnturk.com/video/turkiye/afet-sonrasi-hayat-kurtaran-uygulamalar-1894348) · [Onedio derlemesi](https://onedio.com/haber/aci-tecrubelerle-ogrendigimiz-depremin-etkilerine-karsi-telefonunuzda-mutlaka-olmasi-gereken-10-uygulama-1128525)
- [Deprem Düdüğü (BlueStacks)](https://www.bluestacks.com/tr/apps/tools/earthquake-whistle-on-pc.html)
- [Whistle for Sport & SOS (App Store)](https://apps.apple.com/app/id835828411)
- [AFAD Acil Çağrı (Gazete Vatan)](https://www.gazetevatan.com/galeri/afad-uygulamasi-nedir-afad-acil-cagri-uygulamasi-mobil-sistem-nasil-indirilir-afad-uygulamasi-enkaz-altindayim-internetsiz-calisir-mi-nasil-kullanilir-2081538) · [Vali açıklaması (DonanımHaber)](https://www.donanimhaber.com/vali-den-afad-in-acil-cagri-uygulamasi-hakkinda-aciklama--150613)
- [Acil İzmir (tamindir)](https://www.tamindir.com/indir/acil-izmir/amp/)
- [TÜBİTAK MAM: ATEAS ve AkuSTECTS](https://mam.tubitak.gov.tr/en/tubitak-levels-up-in-earthquake-studies/) · [TÜBİTAK haber](https://tubitak.gov.tr/en/node/16643)
- [İTÜ enkaz dinleme (ShiftDelete)](https://shiftdelete.net/itu-enkaz-dinleme-uygulamasi-gelistirdi?amp=1) · [C4Defence](https://www.c4defence.com/en/itu-miam-implemented-debris-listening-practice/)
- [Takada: Using smartphones to improve disaster search and rescue (acoustics.org)](https://acoustics.org/using-smartphones-to-improve-disaster-search-and-rescue/) · [Critical Comms](https://www.criticalcomms.com.au/content/research/news/smartphone-microphones-used-for-disaster-search-and-rescue-706460394)
- [BeepBeep SenSys 2007 (PDF)](https://www.cs.purdue.edu/homes/chunyi/pubs/sensys106-beepbeep.pdf) · [BeepBeep TECS 2012 (PDF)](https://www.cs.purdue.edu/homes/chunyi/pubs/peng-tecs12.pdf)
- [Using Smartphones to Locate Trapped Victims in Disasters (Sensors 2022, PMC)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9572018/)
- [Delsar LD3 (satıcı)](https://img0.hospitalityhub.com.au/delsar-lifedetector-ld3-seismic-and-acoustic-listening-device/p/234201) · [Delsar Mini](https://www.allsafeindustries.com/Delsar-Mini-2-Sensor-Seismic-Acoustic-Listening-System.aspx)
- [US 9 591 466 (USPTO PDF)](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9591466)
