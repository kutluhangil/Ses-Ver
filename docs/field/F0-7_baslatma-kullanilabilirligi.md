# F0-7: Başlatma kullanılabilirlik testi protokolü

> Sürüm 0.1 · 2026-10-20 · Sahip: İnsan (moderatör) + `field-qa` · Analiz: `design:research-synthesis`
> Hedef (BLUEPRINT §2.2): Karanlıkta, stres altında 10 katılımcının 9'u işareti ≤ 10 sn'de başlatır. K1: kilitli ekrandan ≤ 2 hareket.
> Uygulama: Spike A (Eylem Düğmesi), Spike B (kilit ekranı kontrolü), Spike H (Siri). Uygulama içi düğme için Spike A'nın ana ekranı.

## Katılımcılar
- 10 kişi. Karışım: ≥ 3 kişi 50 yaş üstü, ≥ 2 kişi Eylem Düğmesi kullanmamış, ≥ 1 kişi gözlük kullanan. Tüm katılımcılar iPhone kullanıcısı.
- Hariç tutma: Klostrofobi, panik bozukluğu veya kalp rahatsızlığı beyan eden. Stres yalnız zaman baskısıyla verilir. Gerçek tehlike, sarsıntı, ani ses kullanılmaz.
- Onam: `F0-6_F0-7_onam.md`. İstedikleri an bırakabilirler.

## Ortam
- Karanlık oda (< 1 lux). Katılımcı yerde, yan yatmış veya oturur halde, bir masa altında. "Sıkışmış" hissi yalnız konumla verilir.
- Telefon katılımcının elinin uzanabileceği ama görmeden bulması gereken yerde, kilitli, ekran aşağı.
- Kayıt: kızılötesi kamera (yüz değil eller), ekran kaydı, moderatörün süre tutucu.

## Görevler (sıra katılımcılar arasında dengelenir: Latin kare)
| # | Tetik | Hazırlık | Başarı ölçütü |
|---|---|---|---|
| T1 | Eylem Düğmesi (iPhone 15 Pro+) | Kurulum rehberiyle önceden kurulur | İşaret duyulur |
| T2 | Kilit ekranı kontrolü (iOS 18+) | Önceden eklenir | İşaret duyulur |
| T3 | Uygulama içi düğme | Kilit açma dahil | İşaret duyulur |
| T4 (isteğe bağlı) | Siri: "Ses Ver'i başlat" | — | İşaret duyulur |

Talimat (her görev için aynı, sesli): "Telefonunuz yanınızda bir yerde. Şimdi işareti başlatın. Süre başladı." Moderatör yardım etmez. 30 sn'de görev başarısız sayılır.

## Ölçümler
- Süre: talimatın bitişinden ilk ıslığa kadar (ses kaydından).
- Hareket sayısı (K1).
- Hatalar: yanlış düğme (ör. ses tuşu), kilit açma denemesi, Face ID başarısızlığı, parola istemi (F0-2 (a) riski).
- Görev sonrası: 1–7 ölçekli kolaylık puanı (SEQ), tek açık soru: "Ne zorladı?"
- Ayrıca Durdur testi: "Şimdi işareti durdurun". 3 sn basılı tutma anlaşılıyor mu, yanlışlıkla durdurma oluyor mu?

## Analiz
- Tetik başına ≤ 10 sn başarı oranı ve medyan süre. Güven aralığı Wilson yöntemiyle (n = 10 küçük, rapor bunu söyler).
- Kapı (F0 #4 ile birlikte): En az bir tek hareketli tetik 9/10 ≤ 10 sn. Değilse sonuçlar ve videolar F0 kapı raporuna olduğu gibi girer.

## Kayıt formu
`docs/field/forms/F0-7_deneme.csv`: katılımcı (P01…), yaş aralığı, cihaz, tetik, sıra, süre sn, hareket sayısı, başarı, hata türü, SEQ, not.
