# Sözleşme: SignalSpec v1

> Durum: **Taslak, revizyon 1** (ADR-0004 ve F0-3b simülasyon bulgularına dayalı; F0-4 saha ölçümüyle kesinleşecek).
> Sahip: `architect` · Uygulayanlar: `dsp-acoustics` (Python referans, BeaconKit, DetectorKit)
> Karar kaydı: [ADR-0004](../adr/0004-signal-v1-candidates.md) · Kaynak: BLUEPRINT §3.3
> Lisans niyeti: CC-BY 4.0 (yayın kararı BLUEPRINT §10/5'e bağlı)

Bu belge **normatiftir**. "MUST/ZORUNLU" ifadeleri uyumlu her verici ve alıcı için bağlayıcıdır. "Bilgi" başlıklı bölümler normatif değildir.

---

## 1. Sabitler

| Sembol | Değer | Örnek (fs = 48 kHz) |
|---|---|---|
| `fs` | 48 000 Hz (verici ve referans). Alıcı başka fs kullanırsa yeniden örnekler. | — |
| `fL` | 1 200 Hz (B1 bandı; Delsar ve profesyonel jeofonlarla uyumlu) | — |
| `fH` | 3 000 Hz | — |
| `B` | `fH − fL` = 1 800 Hz | — |
| `Tp` | Giriş/senk chirp süresi, 96 ms (görev döngüsü bütçesi için 120 ms'den indirildi) | 4 608 |
| `Tg` | Giriş chirp'leri arası boşluk, 80 ms | 3 840 |
| `Ts` | Veri sembolü süresi, 64 ms | 3 072 |
| `M` | Sembol alfabesi, 16 (4 bit) | — |
| `Nsym` | Çerçevedeki veri sembolü sayısı, 10 (6 veri + 4 RS eşlik) | — |
| `Tf` | Toplam çerçeve süresi, 1 264 ms | 60 672 |
| `Ton` | Akustik açık kalma süresi (boşluklar hariç), 1 024 ms | 49 152 |

---

## 2. Çerçeve düzeni

Örnek indeksleri çerçeve başlangıcına (ilk giriş chirp'inin ilk örneği, `n = 0`) göredir.

| Öğe | Başlangıç | Bitiş (hariç) | Süre (örnek / ms) | İçerik |
|---|---|---|---|---|
| U1 | 0 | 4 608 | 4 608 / 96 ms | Yükselen chirp |
| G1 | 4 608 | 8 448 | 3 840 / 80 ms | Sessizlik |
| U2 | 8 448 | 13 056 | 4 608 / 96 ms | Yükselen chirp |
| G2 | 13 056 | 16 896 | 3 840 / 80 ms | Sessizlik |
| U3 | 16 896 | 21 504 | 4 608 / 96 ms | Yükselen chirp |
| G3 | 21 504 | 25 344 | 3 840 / 80 ms | Sessizlik |
| D | 25 344 | 29 952 | 4 608 / 96 ms | Alçalan senk chirp'i |
| S0…S9 | 29 952 + i·3 072 | 29 952 + (i+1)·3 072 | 30 720 / 640 ms | 10 CSS veri sembolü, boşluksuz |

Ritim (insan kulağı için): "üç yükselen ıslık, kısa duraklama, alçalan ıslık + cıvıltı".

---

## 3. Dalga biçimi

Tüm öğeler gerçek değerli, `x[n] = A · w[n] · sin(φ[n])`, `t = n / fs`, `n = 0 … N−1`. Her öğe kendi yerel zamanında `φ(0) = 0` ile başlar.

### 3.1 Yükselen chirp (U1–U3)
$$\phi(t) = 2\pi \cdot \left(f_L \cdot t + \frac{B}{2 \cdot T_p} \cdot t^2\right)$$

### 3.2 Alçalan senk chirp'i (D)
$$\phi(t) = 2\pi \cdot \left(f_H \cdot t - \frac{B}{2 \cdot T_p} \cdot t^2\right)$$

### 3.3 Veri sembolü (CSS, döngüsel kaydırmalı yükselen chirp)
Kaydırma `s ∈ {0…15}`. Chirp hızı `k = B / Ts`. Sarma anı `tw = Ts · (1 − s/M)`. Örnek indeksinde: `n < 3 072 − 192·s` ilk bölüm, kalan örnekler ikinci bölüm.

* `0 ≤ t < tw`: $\phi(t) = 2\pi \cdot \left((f_L + s \cdot B / M) \cdot t + (k / 2) \cdot t^2\right)$
* `tw ≤ t < Ts`: $\phi(t) = \phi(tw) + 2\pi \cdot \left(f_L \cdot (t - tw) + (k / 2) \cdot (t - tw)^2\right)$

Anlık frekans `fL + ((s·B/M + k·t) mod B)`. Sembol içinde faz süreklidir. `s = 0` için sarma yoktur.

### 3.4 Pencere (`w[n]`)
* U, D: başta ve sonda 5 ms (240 örnek) yarım-Hann rampa.
* Veri sembolü: başta ve sonda 2 ms (96 örnek) yarım-Hann rampa.
* Yarım-Hann giriş rampası: $w[n] = 0.5 \cdot (1 - \cos(\pi \cdot n / R))$, $n = 0 \dots R-1$, $R$ rampa uzunluğu.
* Çıkış rampası: $w[N - 1 - n] = 0.5 \cdot (1 - \cos(\pi \cdot n / R))$, $n = 0 \dots R-1$. Aradaki örneklerde $w = 1$.

### 3.5 Genlik ve kulak güvenliği
* Dijital tepe $A = 10^{-1/20} \approx 0,891$ (−1 dBFS). Tüm öğeler aynı genlikte.
* Akustik çıkış `outputGain ∈ (0, 1]` ile çarpılır.
* **Zorunlu sınır:** 10 cm'de tepe ses basıncı $\le 95\text{ dB SPL}$ ve 60 saniyelik kayan pencerede görev döngüsü $\le \%12$.

---

## 4. Yük düzeni (P1)

P1 yükü 24 bitlik sözcük $W$, en anlamlı bit önce (MSB first).

| Alan | Bit aralığı (W içinde) | Genişlik | Kodlama |
|---|---|---|---|
| `id` | 23…12 | 12 | Her etkinleştirmede rastgele. `0x000` ve `0xFFF` ayrılmış, kullanılmaz. Gösterim: `K-` + 3 hane büyük harf hex (ör. `K-7F2`). |
| `people` | 11…9 | 3 | 0: belirtilmedi · 1…6: 1…6 kişi · 7: 7 ve üzeri kişi |
| `injured` | 8 | 1 | 1 = yaralı var · 0 = yaralı yok veya bilinmiyor |
| `lifeAge` | 7…4 | 4 | Son "Buradayım" dokunuşundan beri geçen süre (§4.1) |
| `battery` | 3…2 | 2 | `min(3, floor(yüzde / 25))` → 0 (%0–25) … 3 (%75–100) |
| `mode` | 1…0 | 2 | 0: canlı · 1: zincir (Katman 2) · 2: Gece Nöbeti otomatik · 3: yanıt |

### 4.1 `lifeAge` dilimleri
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

---

## 5. Hata düzeltme kodlaması: RS(10,6) GF(16)

v1 protokolünde CRC yerine Reed-Solomon RS(10,6) kullanılır.

* **Galois Alanı:** $\text{GF}(2^4) = \text{GF}(16)$.
* **İlkel Polinom (Primitive Polynomial):** $p(x) = x^4 + x + 1$ (`0x13`).
* **Jeneratör Polinomu:**
  $$g(x) = \prod_{i=1}^{4} (x - \alpha^i) = x^4 + \alpha^{13} x^3 + \alpha^6 x^2 + \alpha^3 x + \alpha^{10}$$
* **Veri blokları:** 24 bitlik veri 6 adet 4-bitlik sembole (nibble) ayrılır: $d_0, d_1, d_2, d_3, d_4, d_5$.
* **Eşlik blokları:** 4 adet eşlik sembolü $p_0, p_1, p_2, p_3$ hesaplanır.
* **Gönderim dizisi (10 sembol):** $d_0, d_1, d_2, d_3, d_4, d_5, p_0, p_1, p_2, p_3$.
* **Sembol haritalama:** Her sembol Gray kodu tersiyle (`gray_inv`) CSS kaydırmasına $s \in \{0\dots15\}$ dönüştürülür.
* **ZORUNLU KURAL (Hata düzeltme sınırı):** Alıcı en fazla 1 sembol hatasını düzeltmelidir ($t_{\max} = 1$). $t \ge 2$ düzeltmeye izin verilmesi sahte alarm oranını saatte 38 kabul seviyesine fırlatır (ADR-0004). $t > 1$ sendromlu paketler **atılmalıdır**.

---

## 6. Görev döngüsü ve aralıklar

$T_{\text{on}} = 1 024\text{ ms}$. 60 saniyelik kayan pencerede görev döngüsü $\le \%12$ olmalıdır.

* İzin verilen en küçük aralık: $I_{\min} = 1 024 / 0,12 \approx 8 533\text{ ms}$ (güvenlik payıyla $\ge 8,6\text{ sn}$).
* **Canlı işaret aralıkları:**
  * 0–6 saat: 10 sn (görev döngüsü %10,2)
  * 6–24 saat: 20 sn (görev döngüsü %5,1)
  * 24–72 saat: 45 sn (görev döngüsü %2,3)
  * 72+ saat: 90 sn (görev döngüsü %1,1)
  * Pil < %20: aralıklar $\times 2$.
  * Çakışmayı önlemek için her aralığa $\pm \%15$ rastgele sapma (jitter) eklenir.

---

## 7. Alıcı gereksinimleri (DetectorKit)

1. **Giriş Filtresi:** $0,9 - 3,3\text{ kHz}$ bant geçiren filtre.
2. **Eşlenik Filtre:** U1, U2, U3 yükselen chirp'leri için overlap-save vDSP korelasyonu.
3. **E0 Tutarlı Karar:** 16 sembol şablonuyla tutarlı faz/enerji metrik karşılaştırması.
4. **E4 İki Çerçeve Kuralı:** Peş peşe iki çerçevede aynı ID doğrulanmadan kurtarıcı ekranına onaylı canlı işaret olarak yansıtılmaz.
5. **Yanlış Alarm Hedefi:** Şantiye ve yıkım alanı gürültüsünde saatte $\le 1$ sahte kabul.
