# F0-1e: US 9 591 466 B2 ön okuma

> **Hukuki görüş değildir.** Mühendislik gözüyle istem karşılaştırmasıdır. Ürün kararı için patent avukatı gerekir (R12, `legal:legal-risk-assessment`).
> Tarih: 2026-10-20 · Kaynak: [Google Patents](https://patents.google.com/patent/US9591466B2/en)

## Künye
| Alan | Değer |
|---|---|
| Başlık | Method and apparatus for activating an emergency beacon signal |
| İlk sahip | BlackBerry Ltd (RIM). Bugünkü sahip: Malikie Innovations Ltd (2023 devri) |
| Rüçhan / başvuru | 2012-07-06 |
| Durum | Google'a göre **aktif, 2033-03-12'de sona eriyor** |
| Coğrafya | ABD. Ailede bir Tayvan kaydı (TW I527481) var. Türkiye/EPO kaydı görülmedi. |

## Bağımsız istem 1 (özet, unsurlar)
Bir taşınabilir iletişim cihazı:
- (a) Bir **RF alıcı-verici**, beacon gönderimini tetikleyen bir **talimat sinyali** alır.
- (b) Talimat alınınca kullanıcıya bir **istem** gösterilir.
- (c) Belirli sürede **yanıt gelmezse**:
  - (c1) **Ses ve veri iletişimi devre dışı** bırakılır.
  - (c2) Beacon sinyali, mobil şebeke bandından **farklı bir RF frekans aralığında**, **beacon başlığı ve cihaz kimliği** ile gönderilir.

Bağımlı istemler: talimat hücre yayını (cell broadcast) veya SMS ile gelebilir. İkinci bir talimatla normal moda dönülür. Beacon düşük güçlü RF olur, güç ve modülasyon uyarlanabilir.

## Ses Ver ile karşılaştırma (ön değerlendirme)

| Ses Ver bileşeni | (a) Uzaktan RF talimatı | (b) İstem | (c) Yanıt yoksa | (c1) Ses/veri kapatma | (c2) Farklı bantta RF beacon + ID | Ön değerlendirme |
|---|---|---|---|---|---|---|
| MVP: kullanıcı başlatır, akustik işaret + BLE reklamı | Yok (kullanıcı tetikler) | Yok | Yok | Yok | BLE: evet (2,4 GHz, kimlik içerir) | (a)–(c1) unsurları yok. **Düşük risk.** |
| v1.1 Gece Nöbeti: ivmeölçer → "İyi misiniz?" → 90 sn → işaret | **Yok** (yerel sensör, RF talimatı değil) | Var | Var | Yok | BLE: evet | (a) ve (c1) yok. **Düşük–orta risk.** Tetik kaynağı RF olmamalı. |
| v2 Katman 3: sunucudan kritik uyarı + "Güvendeyim" yoklaması → yanıt yoksa işaret | **Var olabilir** (push, RF üzerinden gelir) | Var | Var | Yok (tasarım gereği kapatılmamalı) | BLE: evet | Yalnız (c1) eksik. **Avukat incelemesi şart.** |

## Sonuçlar ve tasarım kuralları
1. MVP ve Gece Nöbeti, istem 1'in birden fazla zorunlu unsurunu içermiyor [ön değerlendirme].
2. **v2 Katman 3 tasarım kuralı** (avukat görüşü gelene kadar):
   - Uzaktan bildirim + yanıtsızlık zinciri işareti **otomatik başlatmaz**. Yalnız kullanıcıya hatırlatır.
   - Ses/veri iletişimi hiçbir modda kapatılmaz.
3. Patent yalnız ABD'de geçerli görünüyor. Ürün Türkiye'de dağıtılacak, ama App Store dağıtımı ABD'yi de kapsar. Bu yüzden ABD mağazası için FTO kararı avukata bırakılır.
4. Sona erme 2033. v2 zaman çizelgesi bu tarihle karşılaştırılmalı.

## Açık
- [ ] Patent avukatı görüşü (özellikle v2 Katman 3 ve BLE beacon unsuru)
- [ ] Benzer patent taraması: "acoustic beacon smartphone trapped", "disaster victim sound signal mobile" (Google Patents, EPO, TÜRKPATENT)
