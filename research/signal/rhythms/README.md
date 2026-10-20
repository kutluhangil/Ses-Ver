# F0-6 aday ritimleri

Arama kurtarmacılarla yapılacak görüşmelerde (F0-6) dinletilecek üç aday ritim.
Her dosya ~30 sn, 48 kHz, 16 bit PCM, mono. Çerçeveler gerçek zamanlama kuralıyla
yerleştirildi: nominal 10 sn × U(0,85; 1,15) (sözleşme §5), sabit tohum 6006.
Yük: `id = 0x7F2` (K-7F2), 2 kişi, yaralı var, son dokunuş 2–5 dk, pil kodu 6.

| Dosya | Ritim | Bant | Çerçeve | Açık süre (Ton) | Görev döngüsü (10 sn / en kötü 8,5 sn) |
|---|---|---|---|---|---|
| `ritim_A_v0.wav` | 3 × 120 ms yükselen ıslık, 80 ms boşluklar, alçalan senk + 8 × 64 ms veri cıvıltısı | 1,8–4,2 kHz | 1 232 ms | 992 ms | %9,9 / %11,7 |
| `ritim_B_v0L.wav` | A ile aynı ritim | 1,2–3,0 kHz | 1 232 ms | 992 ms | %9,9 / %11,7 |
| `ritim_C_alt2uzun.wav` | 2 × 180 ms yükselen ıslık, 120 ms boşluk, 80 ms duraklama, alçalan senk + 8 × 64 ms veri | 1,8–4,2 kHz | 1 192 ms | 992 ms | %9,9 / %11,7 |

Notlar:

- A ve B, SignalSpec v0 / v0-L çerçevesinin birebir aynısıdır; referans alıcı ikisini de çözer.
- C bir **öneridir**. Sözleşmede yoktur ve v0 alıcısı onu çözmez (giriş deseni farklı).
  Açık süresi v0 ile eşit tutuldu, böylece kulak güvenliği bütçesi (görev döngüsü ≤ %12) değişmez.
  Seçilirse yeni sürüm (v1) gerekir. v0 alıcısı C dosyasında CRC öncesi aday üretir ama CRC geçmez (ölçüldü: 3 aday, 3 `crc_fail`).
- Genlik dijital −1 dBFS'tir. Bu dosyalar **ses basıncı düzeyini temsil etmez**. Görüşmede
  orta düzeyde bir hoparlörden çalın. Kulaklıkla ya da kulağa yakın, en yüksek seste çalmayın.
- Yeniden üretme: `research/.venv/bin/python research/signal/rhythms/make_rhythms.py`
  (çerçeve başlangıç zamanları `rhythms.json` içinde).
