# ADR-0001: Yalnızca iOS, native Swift 6 + SwiftUI

- Durum: Kabul edildi (F0)
- Tarih: 2026-10-20
- Sahip: `architect`
- İlgili: BLUEPRINT §0.1, §2.3, §4

## Bağlam
Ürünün çekirdeği platformun en dar köşelerinde çalışıyor:
- Arka planda gerçek ses çalma ve mikrofon (`AVAudioEngine`, `UIBackgroundModes: audio`)
- Uygulamayı açmadan ses başlatma (`AudioPlaybackIntent`, Eylem Düğmesi, `ControlWidget`)
- Kritik bildirim zinciri (Critical Alerts) ve yerel bildirim planlama
- Arka planda BLE reklamı (`CBPeripheralManager`)
- ARKit poz takibi, Core Motion, Live Activity

Kaynak: tek geliştirici + Claude Code ajanları. Gerçek zamanlı DSP, ses iş parçacığında bellek ayırmadan çalışmalı.

## Seçenekler
1. **Native Swift 6 + SwiftUI, yalnızca iOS.**
2. **Flutter (iOS + Android).** Her kritik API için platform kanalı veya eklenti gerekir. Ses render döngüsü ve App Intents native kalır. Pratikte iki kod tabanı + köprü bakımı.
3. **React Native / Expo.** Seçenek 2 ile aynı sorun. Gerçek zamanlı ses yolu JS köprüsünden geçemez.
4. **Native iOS + native Android (paralel).** Kapsam iki katına çıkar. F0 kanıtı gelmeden ikinci platforma yatırım erken.

## Karar
Seçenek 1. Swift 6 (strict concurrency), SwiftUI, minimum iOS 17. iOS 18+ özellikleri (`ControlWidget`) `if #available` ile koşullu. DSP: Accelerate/vDSP, sıfır üçüncü taraf bağımlılık. Paketler: BeaconKit, DetectorKit, LocalizationKit, DeviceServices, DesignSystem (Swift Package, Swift Testing).

## Sonuçlar
- Olumlu: Tüm kritik API'lere doğrudan erişim. Enerji verimli DSP. Tek dil. App Review notunda davranış açıkça gerekçelendirilebilir.
- Olumsuz: Android kullanıcıları (Türkiye'de çoğunluk [Muhtemel]) MVP'de yok. Bu, kapsama açığıdır.
- Hafifletme: SignalSpec açık protokol (ADR-0002). Android uygulamaları ve ekipmanlar aynı sinyali uygulayabilir. TÜBİTAK MAM ATEAS gibi Android çalışmalarıyla birlikte çalışabilirlik F0-1/F0-6'da konuşulur.

## Yeniden değerlendirme tetikleyicisi
- F0 kapısı geçilir ve bir kurum ortaklığı Android'i şart koşarsa.
- Android'de eşdeğer bir "uygulamayı açmadan ses başlat" yolu kanıtlanırsa ve ekip büyürse.
- F0-2 spike'ları native avantajın varsayılan kritik API'lerde gerçekleşmediğini gösterirse.
