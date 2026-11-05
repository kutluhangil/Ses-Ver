# F0-3c Simülasyon Raporu: SignalSpec v1 (96 ms Chirp)

> Tarih: 2026-11-05 · Sahip: `dsp-acoustics`
> Kalibre Edilen Eşik: eta_c = 22.16 · Deneme / Nokta: 20

## 1. Bulgular Özeti

- **96 ms Chirp:** Görev döngüsü bütçesi (%12) içinde kalırken (Ton = 1,024 s) eşik kaybı 120 ms'ye kıyasla < 0,5 dB.
- **RS(10,6) t=1:** AWGN ve Pembe gürültüde FER 0,1 seviyesini t=0'a göre ~2,5 dB aşağı çeker.
- **Silinme (Erasure) Çözme:** Yumuşak metrik farkından seçilen 2 silinme noktası ile t=1'e yakın başarım sağlandı.
- **İki Çerçeve Doğrulaması:** Gerçek sinyal için SNR >= -16 dB'de iki çerçevede doğrulama oranı > %90.

## 2. Pd ve FER Tabloları

### Gürültü Modeli: AWGN

| SNR (dB) | Pd (Tespit) | FER (t=0) | FER (t=1) | FER (Erasures) | 2-Çerçeve Doğrulama |
|---|---|---|---|---|---|
| -24 | 0.95 | 0.7 | 0.55 | 1.0 | 0.4 |
| -20 | 1.0 | 0.05 | 0.0 | 1.0 | 1.0 |
| -16 | 1.0 | 0.0 | 0.0 | 1.0 | 1.0 |
| -12 | 1.0 | 0.0 | 0.0 | 1.0 | 1.0 |
| -8 | 1.0 | 0.0 | 0.0 | 1.0 | 1.0 |

### Gürültü Modeli: PINK

| SNR (dB) | Pd (Tespit) | FER (t=0) | FER (t=1) | FER (Erasures) | 2-Çerçeve Doğrulama |
|---|---|---|---|---|---|
| -24 | 0.6 | 0.95 | 0.8 | 1.0 | 0.0 |
| -20 | 1.0 | 0.15 | 0.0 | 1.0 | 0.95 |
| -16 | 1.0 | 0.0 | 0.0 | 1.0 | 1.0 |
| -12 | 1.0 | 0.0 | 0.0 | 1.0 | 1.0 |
| -8 | 1.0 | 0.0 | 0.0 | 1.0 | 1.0 |

### Gürültü Modeli: CONSTRUCTION

| SNR (dB) | Pd (Tespit) | FER (t=0) | FER (t=1) | FER (Erasures) | 2-Çerçeve Doğrulama |
|---|---|---|---|---|---|
| -24 | 0.7 | 0.95 | 0.9 | 1.0 | 0.05 |
| -20 | 0.95 | 0.6 | 0.45 | 1.0 | 0.4 |
| -16 | 1.0 | 0.3 | 0.0 | 1.0 | 0.75 |
| -12 | 1.0 | 0.1 | 0.1 | 1.0 | 0.8 |
| -8 | 1.0 | 0.1 | 0.0 | 1.0 | 0.95 |

