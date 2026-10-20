# Claude Design istemi: Ses Ver (iOS)

> Aşağıdaki çizginin altını Claude Design'a yapıştır.
> Hazır bir başlangıç noktası var: 7 ekranlık tasarım tuvali (tasarım sistemi + kurban ve kurtarıcı ekranları). Claude Design'dan bu yönü **geliştirmesini** istemek, sıfırdan başlatmaktan daha tutarlı sonuç verir. İstersen tuvaldeki ekranların görüntülerini isteme ekle.
> Önce yalnızca "Tasarım sistemi + İşaret aktif + Dinle" ekranlarını iste. Yön oturunca kalan ekranlara geç.

---

## Görev
**Ses Ver** adlı, yalnızca iPhone için (iOS 17+) bir uygulamanın tasarım sistemini ve ekranlarını tasarla. Uygulama SwiftUI ile yazılacak. Apple'ın Human Interface Guidelines'ına uy: SF Pro / SF Mono, sistem gezinme kalıpları, Dinamik Yazı, VoiceOver.

## Ürün
Ses Ver, deprem sonrası enkaz altında kalan birinin telefonunu **akustik bir işarete** dönüştürür. Telefon belirli aralıklarla, insan kulağının ayırt edebileceği ve veri taşıyan bir ıslık deseni çalar: üç yükselen ıslık, ardından kısa bir veri bölümü. Kurtarıcıların telefonundaki aynı uygulama bu sesi gürültü içinden yakalar, kodunu çözer (kaç kişi, yaralı var mı, son ne zaman dokunuldu) ve kurtarıcıyı sesin en güçlü duyulduğu bölgeye yönlendirir.

Uygulamanın iki modu var:
1. **İşaret (kurban tarafı):** hazırlık + enkaz altında tek hareketle başlatılan işaret
2. **Dinle (kurtarıcı tarafı):** algılama, sıcak-soğuk yönlendirme, AR güç haritası

## Kullanıcılar ve bağlam
- **Kurban:** Karanlıkta, toz içinde, belki yaralı, panikte. Ekrana zor bakıyor, eli titriyor, pili azalıyor. Saatlerce, belki günlerce bekleyecek.
- **Kurtarıcı:** Profesyonel ekip üyesi, gönüllü veya komşu. Eldivenli, gün ışığında veya projektör altında, gürültülü ve yorgun. Tek eliyle kullanıyor.
- **Hazırlanan kişi:** Sakin bir günde, deprem öncesi kurulum yapıyor.

## Yön: sakin bir alet
- Bu bir "acil durum" görseli değil, **sakin ve güvenilir bir ölçü aleti**. Panik rengi (sürekli kırmızı, yanıp sönme) yok.
- **Kurban ekranları:** saf OLED siyahı (#000000). Bu bir estetik tercih değil, pil tasarrufu ve karanlıkta göz kamaşmasını önlemek için. Sıcak beyaz metin, tek sinyal rengi.
- **Kurtarıcı ekranları:** koyu antrasit zemin, araç hissi, büyük monospace sayılar, güneş altında okunur kontrast.
- **Tek sinyal rengi:** kehribar #FFB23E, iki modda da aynı. Kırmızı tonu (#FF7A6B) yalnızca "durdur" ve "eksik ayar" için kullanılır.
- **Tipografi:** SF Pro, sayılar ve ID'ler SF Mono. Kurban ekranında gövde en az 21 pt, ana başlık 32–40 pt.
- **Hareket:** Yalnızca işaret halkası çalarken yavaş bir genişleme. "Azaltılmış hareket" açıksa hiç animasyon yok.

## Başlangıç token'ları (iyileştirebilirsin, gerekçesini yaz)
| Token | Kurban | Kurtarıcı |
|---|---|---|
| bg | #000000 | #0E1114 |
| surface | #1F1C18 | #171C21 |
| surface-alt | #14120F | #20262D |
| border | #34302A | #323A44 |
| text | #F4EFE6 | #EEF2F5 |
| text-2 | #B3ADA2 | #A2ADB9 |
| signal | #FFB23E | #FFB23E |
| on-signal | #1A1100 | #1A1100 |
| stop / warn | #FF7A6B | #FF7A6B |
| SNR rampası | — | #20262D → #4A3A16 → #8A631E → #C9862A → #FFB23E → #FFE3AE |

## Kesin kısıtlar
- Kurban ekranında her dokunma hedefi ≥ 60 pt. Kurtarıcı ekranında ≥ 56 pt (eldiven).
- Her ekranda **tek birincil eylem**.
- Durum hiçbir zaman yalnızca renkle verilmez: ikon + kelime + sayı birlikte kullanılır.
- Dinamik Yazı AX5'te taşma olmamalı. Tasarımları hem varsayılan hem AX3 boyutunda göster.
- VoiceOver: her öğe için okunacak etiketi not et.
- **Durdurma her zaman 3 sn basılı tutma ister.** İlerleme dolgusu ile gösterilir.
- **Metin tonu:** kısa, sakin, emir kipinde ama kibar. "Hayat kurtarır", "garanti", "kesin bulunursunuz" gibi ifadeler **yasak**. Belirsizlik açıkça yazılır ("Deneysel", "olası bölge", "±1,2 m").
- Emoji, illüstrasyon karakteri, gradyan, cam efekti yok.

## Yapma
- Kırmızı-siyah "alarm" estetiği, siren ikonları, yanıp sönen öğeler.
- AR ekranında bilim kurgu hissi veren tarama çizgileri ve neon.
- Kişinin "tam yerini" gösteriyormuş gibi tek bir nokta. Her zaman **bölge + belirsizlik** gösterilmeli.

## Ekranlar

### A. Hazırlık ve kurulum (kurban modu, sakin gün)
1. **Karşılama (2 ekran):** Ne yapar ve ne yapmaz. Birinci ekran: "Enkaz altında telefonunuz sizin yerinize ses verir." İkinci ekran: "Bu bir düdüğün ya da 112'nin yerini tutmaz."
2. **İzinler (sistem penceresinden önce gösterilen ekranlar):** Bildirim + **Kritik Uyarı** (neden gerektiği: sessiz modda bile duyulsun), Mikrofon (yalnızca kurtarıcı modu ve yanıt özelliği için), Bluetooth.
3. **Hazırlık (ana ekran):** üstte "İşareti başlat" kartı, altında kontrol listesi: ses düzeyi, kritik uyarı, Eylem Düğmesi, kilit ekranı kontrolü, Tıbbi Kimlik (Sağlık uygulamasına yönlendirir), gerçek bir düdük. "4/6 hazır" sayacı ve "Sinyali 5 sn dene" düğmesi.
4. **Eylem Düğmesi / kilit ekranı kurulum rehberi:** 3 adımlı, görsel destekli.
5. **Sinyali dene:** 5 sn'lik deneme. Ses düzeyi göstergesi ve "Duydunuz mu?" sorusu.

### B. İşaret (kurban modu, kriz anı)
6. **İşaret aktif (en önemli ekran):** "Sinyal veriliyor" + halka göstergesi + "sonraki ıslık: 7 sn". Durum çipleri (ses %, tahmini pil saati, yedek zincir). Ekranın büyük kısmını kaplayan **"Buradayım"** düğmesi (yaşam belirtisi, altında "son dokunuş"). "Kaç kişisiniz?" 1/2/3/4+. "Yaralı var" düğmesi. "112'yi ara". Telefonun nasıl konumlandırılacağına dair tek cümle. En altta "Durdurmak için 3 sn basılı tutun".
7. **İşaret aktif, ses kısık uyarısı:** Ekranın üst yarısını kaplayan uyarı: "Ses düzeyi %30. Yan taraftaki ses tuşuna basarak sonuna kadar açın." Ses tuşlarının telefonun yan tarafındaki konumunu gösteren sade bir çizim.
8. **İşaret aktif, düşük pil modu:** "Pil %18. Islık aralığı 40 sn'ye çıkarıldı." Ekran parlaklığını kısma önerisi.
9. **Kilit ekranı Live Activity ve Dynamic Island:** kompakt, genişletilmiş ve kilit ekranı varyantları. "Sinyal veriliyor · 7 sn", "Buradayım" düğmesi.
10. **Kontrol Merkezi / kilit ekranı kontrolü:** tek düğme "Ses Ver", açık ve kapalı durumları.
11. **Gece Nöbeti, bekleme:** tamamen siyah ekran, soluk kehribar renkli büyük saat, "Nöbette · şarjda", minimum parlaklık.
12. **Gece Nöbeti, sallantı algılandı:** "Sallantı algılandı. İyi misiniz?", 90 sn geri sayım halkası, "İyiyim" (açık renkli, büyük) ve "Mahsur kaldım, şimdi başlat" (sinyal rengi).

### C. Dinle (kurtarıcı modu)
13. **İlk kullanım güvenlik ekranı:** "Enkaza çıkmadan önce ekip lideriyle koordine olun", 3 kural, "Anladım" düğmesi.
14. **Dinle (liste):** Durum ("Dinleniyor · gürültü 62 dB(A)"), büyük "Sessizlik · 60 sn odaklı dinleme" düğmesi, yakındaki işaretlerin kartları. Her kartta ID (K-7F2), SNR (+17 dB), kişi sayısı, yaralı etiketi, son dokunuş, SNR çubuğu, BLE yakınlığı, pil, "3 sn önce duyuldu". Sıralama son dokunuşa göre yapılır. **"Otomatik yedek zincir · canlılık bilgisi yok"** kartı görsel olarak geri planda kalmalı (kesik kenarlık, soluk metin).
15. **Sessizlik modu:** tam ekran, 60 sn geri sayım, canlı spektrogram şeridi, algılanan ıslıklar zaman çizgisinde.
16. **Sıcak-soğuk:** dev SNR sayısı (+17,4 dB), "Güçleniyor / Zayıflıyor / Sabit" (ok + kelime + dB farkı), 10 segmentli rampa, son 12 ıslığın çubuk grafiği, "Islık gelirken 2 sn sabit durun" yönergesi, "AR haritasında göster" düğmesi.
17. **AR güç haritası:** kamera görüntüsü üzerinde zemine yatırılmış ısı karoları, kesik çizgili "olası bölge" elipsi, "En güçlü bölge" etiketi, üstte ID ve "Takip: iyi / zayıf / kayıp" durumu, altta panel: ölçüm sayısı, kapsanan alan, belirsizlik (±1,2 m) ve kalıcı **DENEYSEL** etiketi. Ayrıca "Takip kayboldu, harita donduruldu" durumunu tasarla.
18. **Kayıt / dışa aktarma:** algılama zaman çizelgesi ve "AirDrop / Mesajlar ile koordinatöre gönder".

### D. Ayarlar
19. Dil (TR/EN), işaret ritmini dinle, kritik uyarı durumu, gizlilik özeti ("Hiçbir veri cihazınızdan çıkmaz"), açık sinyal protokolü bağlantısı.

## Teslim edilecekler
- Tasarım sistemi sayfası: token'lar (yukarıdaki tablo ve geliştirmelerin), tipografi ölçeği (varsayılan ve AX3), boşluk, köşe yarıçapı, bileşenler (birincil düğme, basılı tutarak durdur, kontrol satırı, durum çipi, işaret kartı, SNR çubuğu, rampa, sayı göstergesi, alt sekme çubuğu, uyarı bandı) ve tüm durumları.
- Yukarıdaki ekranlar, iPhone 15 Pro (393×852) ölçüsünde.
- Live Activity ve Dynamic Island varyantları.
- Uygulama ikonu için 3 yön: sade, sembolik (ör. ses dalgası + üç yükselen çizgi), küçük boyutta okunabilir, kırmızı olmayan.
- Her ekran için 1–2 cümlelik VoiceOver ve etkileşim notu.

## Teslimden önce kendini kontrol et
- İşaret aktif ekranına karanlıkta, 1 saniyeliğine bakan biri ne olduğunu anlıyor mu?
- "Buradayım" düğmesine bakmadan, el yordamıyla basılabiliyor mu?
- Kurtarıcı, güneş altında, kol boyu uzaklıktan en canlı işareti 2 saniyede seçebiliyor mu?
- AR ekranı kesinlikten çok **olasılık** hissi veriyor mu?
- Hiçbir metin aşırı vaat içeriyor mu?
