# Claude Design istemi v2: Ses Ver (iOS), ikinci tur

> **Kullanım:** Aşağıdaki çizginin altını Claude Design'a yapıştır. Mevcut 7 ekranlık tuvali (docs/design/ses-ver-ios-ekranlari.pdf) ve **docs/design/copy.md** dosyasını ekle. Metinler oradan birebir alınacak.
> **Sıra:** Önce "Düzeltmeler" (bölüm 1). Onaylanınca "Yeni ekranlar" (bölüm 2) iki parti halinde: önce kurban, sonra kurtarıcı + ayarlar.
> **Kaynak:** Güvenlik incelemesi `docs/safety/findings-2026-10-20.md` (S1–S18). İlk istem: `DESIGN_PROMPT.md` (yön, token'lar ve kısıtlar aynen geçerli).

---

## Görev
Ekteki 7 ekranlık Ses Ver tuvalini **aynı yönle** sürdür: sakin alet, OLED siyahı kurban ekranları, antrasit kurtarıcı ekranları, tek sinyal rengi kehribar #FFB23E. İki iş var:
1. Mevcut ekranlardaki 10 düzeltme.
2. Eksik 13 ekran ve 4 durum.

Tüm metinleri ekteki `copy.md`'den birebir al. Metin uydurma. Bir metin sığmıyorsa `copy.md`'deki kısa alternatifi kullan veya not düş.

Tipografi: tuvaldeki IBM Plex yalnız yer tutucu. Ölçüleri SF Pro / SF Mono'ya göre ver.

## 1. Düzeltmeler (mevcut ekranlar)

| # | Ekran | Değişiklik | Neden |
|---|---|---|---|
| D1 | Dinle kartı | Son dokunuş **aralık** olarak: "Son dokunuş 2–5 dk önce", "2–4 sa önce". Tek değer yok. | Sinyal 4 bitlik dilim taşıyor (S1) |
| D2 | Dinle kartı | Yeni durum: **Doğrulanıyor**. Kesik kenar, soluk metin, yalnız ID + "Bir ıslık duyuldu. İkinci ıslık bekleniyor." Kişi/yaralı alanları gizli. Sıcak-soğuk'a girilemez. | Tek çerçeve sahte olabilir (S2) |
| D3 | Dinle kartı | Yeni durum: **Otomatik başladı · dokunuş yok** (Gece Nöbeti). Yedek zincir kartıyla aynı geri plan dili. | Boş evden gelen işaret (S8) |
| D4 | Dinle kartı | Kişi sayısı kod 0 → "≥ 1 kişi". "BLE: yakın" → "BLE: güçlü / zayıf / yok". Pil bir aralık ("pil %62–75"). | S7, S11 |
| D5 | İşaret aktif | Çipler: "Pil %64" (saat yok). "Yedek · 24 sa". Kritik izin yoksa uyarı renginde "Yedek · sessizde çalmaz". | S3, S4 |
| D6 | İşaret aktif | "Buradayım" alt metni `beacon.here.body`. "Kaç kişisiniz?" başlangıçta **hiçbiri seçili değil**. "112'yi ara" altına küçük "Şebeke varsa". | S5, S7, S17 |
| D7 | İşaret aktif | İkincil eylem: **"5 dk sessize al"**. Durdurmanın üstünde, nötr renkte. Sessizdeyken üstte geri sayım bandı: "Sessizde · 4:12 sonra yeniden çalar". | Kulak güvenliği (S10) |
| D8 | Hazırlık | Kart metni `prep.card.body`. "Gerçek bir düdük" maddesi 2. sıraya. Listenin altına **"Sinyali 5 sn dene"** ikincil düğmesi. | S6 |
| D9 | Sıcak-soğuk | Eğilim satırı belirsizlikle: "son 3 ıslıkta +5 dB (±2)". Yetersiz veride "Belirsiz" durumu (ikon: yatay dalga). | S12 |
| D10 | AR | Birincil düğme "Bölgeyi işaretle". "En güçlü bölge" işaretçisi elipsin merkezine bağlanır, ayrı nokta olarak durmaz. | S13 |

## 2. Yeni ekranlar ve durumlar

**Parti 1, kurban:**
1. **Karşılama 1 ve 2** (`onb.*`). Tam ekran OLED, tek cümle başlık, tek düğme. 2. ekranda düdük çizgi ikonu (illüstrasyon karakteri değil).
2. **İzinler** (`perm.*`). Dört kart: Bildirim, Kritik uyarı, Mikrofon, Bluetooth. Her biri neden gerektiğini tek cümlede söyler. Kritik uyarı kartı görsel olarak öne çıkar.
3. **Eylem Düğmesi / kilit ekranı rehberi** (`guide.*`). 3 adım, her adımda telefonun yan profilinden sade çizgi çizim. Alt bağlantı: Arkaya Dokunma yedeği.
4. **Sinyali dene** (`test.*`). 5 sn geri sayım halkası, canlı ses düzeyi çubuğu, ardından "Duydunuz mu?" ve iki düğme. "Hayır" yardım metni.
5. **İşaret aktif, ses kısık** (`beacon.lowvol.*`). Ekranın üst yarısını kaplayan uyarı. Telefonun yan profilinde ses tuşunu gösteren çizim. Alt yarıda normal işaret ekranı sıkıştırılmış.
6. **İşaret aktif, düşük pil** (`beacon.lowbat.*`). Üst bant + parlaklık kısma önerisi.
7. **Live Activity + Dynamic Island**: kompakt, minimal, genişletilmiş ve kilit ekranı varyantları. "Buradayım" düğmesi genişletilmiş ve kilit ekranında.
8. **Kontrol Merkezi / kilit ekranı kontrolü**: açık ve kapalı durumları.
9. **Gece Nöbeti, bekleme** (`watch.*`). Tamamen siyah, soluk kehribar büyük saat (%30 opaklık), alt köşede "Nöbette · şarjda". Şarj çıktı durumu da.
10. **Gece Nöbeti, sallantı + "Geri al" durumu** (`watch.shake.undo`). Mevcut ekrana "İyiyim"den sonraki 10 sn'lik geri alma bandı.

**Parti 2, kurtarıcı + ayarlar:**
11. **İlk kullanım güvenlik ekranı** (`safety.*`). 3 kural, numaralı. "Anladım" 3 sn geri sayımdan sonra etkin.
12. **Dinle, boş durum** (`listen.empty`) ve **Dinle, 5+ kart** (kaydırma, sıralama: doğrulanmış > son dokunuş dilimi > SNR; geri plan kartları en altta).
13. **Sessizlik modu** (`silence.*`). Tam ekran, 60 sn geri sayım, canlı spektrogram şeridi (1,5–4,5 kHz bandı vurgulu), zaman çizgisinde algılanan ıslıklar ID etiketiyle.
14. **AR, takip kayboldu** (`ar.tracking.lost`). Harita donmuş (desatüre), üst durum "Takip: kayıp", ortada yönerge.
15. **AR, karanlık** (`ar.light`).
16. **Kayıt / dışa aktarma** (`log.*`). Algılama zaman çizelgesi (ID başına satır, ıslıklar nokta), "Koordinatöre gönder" (ShareLink).
17. **Ayarlar** (`settings.*`). Gizlilik özeti kartı. Kurtarıcı ekranlarından erişim: Dinle başlığında dişli ikonu, alt sekme sayısı 2'de kalır.

## 3. Teslim edilecekler
- Düzeltilmiş 7 ekran + yukarıdaki 17 kalem, iPhone 15 Pro (393×852).
- Her kurban ekranının **AX3** varyantı ve İşaret aktif'in **AX5** varyantı (taşma yok).
- Her ekran için VoiceOver etiketleri ve odak sırası (kısa liste).
- **Uygulama ikonu, 3 yön:** sade, sembolik (ör. ses dalgası + üç yükselen çizgi), 29 pt'de okunur, kırmızı yok, gradyan yok. Açık / koyu / tinted varyantları.
- Tasarım sistemine eklenen bileşenler: "Doğrulanıyor" kartı, "Otomatik" kartı, sessize alma bandı, geri alma bandı, ±'lı eğilim satırı, takip durumu çipi.

## 4. Kesin kısıtlar (ilk istemden, değişmedi)
- Dokunma hedefi: kurban ≥ 60 pt, kurtarıcı ≥ 56 pt. Ekran başına tek birincil eylem.
- Durum hiçbir zaman yalnız renkle verilmez.
- Durdurma her zaman 3 sn basılı tutma.
- Emoji, illüstrasyon karakteri, gradyan, cam efekti, yanıp sönme, siren ikonu yok.
- Yasak ifadeler: "hayat kurtarır", "garanti", "kesin bulunursunuz", "tam yer".

## 5. Teslimden önce kontrol et
- Dinle listesinde hangi kartın doğrulanmış ve canlı olduğu 2 saniyede anlaşılıyor mu?
- Hiçbir ekranda bir süre, mesafe veya kişi sayısı sinyalin taşıdığından daha kesin görünüyor mu?
- İşaret aktif ekranında "5 dk sessize al" ile "Durdur" karıştırılabilir mi?
- AR ekranı tek bir nokta değil bir bölge mi gösteriyor?
