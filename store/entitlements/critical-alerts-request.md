# F0-8: Critical Alerts entitlement başvuru taslağı

> **GÖNDERİLMEDİ.** Göndermek için insan onayı gerekir (CLAUDE.md).
> Sahip: `release`. Metin `safety-redteam` kontrolünden geçti (2026-10-20): yasaklı ifade yok, vaat yok.
> Form: Apple Developer › Contact › "Critical Alerts Entitlement Request" (form alanları değişebilir; göndermeden önce güncel formu kontrol et).
> Kaynak: `docs/field/spikes/F0-2-plan.md` §6, ADR-0003.

## Göndermeden önce doldurulacaklar
- [ ] Team ID, App Bundle ID (`com.<team>.sesver`), uygulama adı
- [ ] Kurumsal destek mektubu (AFAD / AKUT / TÜBİTAK MAM). Varsa başvuruyu belirgin şekilde güçlendirir [Muhtemel]. F0-6 temasına bağlı.
- [ ] Demo videosu bağlantısı (spike (d) cihaz kaydı: kilitli, sessiz anahtar açık, uygulama kapatılmış, işaret çalıyor)
- [ ] F0-2 (c)/(d) spike sonuç dosyaları (özet)
- [ ] F0-4 saha akustiği özeti (hazırsa)

---

## Form metni (EN)

**App name:** Ses Ver

**Category:** Public safety / emergency

**Describe your app and how it will use Critical Alerts:**

Ses Ver turns a phone trapped under earthquake rubble into an acoustic beacon. After the user explicitly starts the signal (in-app button, Action button, Lock Screen control or Siri), the phone periodically plays a short whistle pattern (about 1 second every 10–90 seconds). Human rescuers can hear it, and rescuers' phones running the same app can detect and decode it from noise.

While the app is running, the signal is played by the app's own audio engine. Critical Alerts are needed only for the fallback case: if the system terminates the app (memory pressure, crash, battery protection), a chain of pre-scheduled local notifications continues the signal. Each notification sound is a whistle file under 30 seconds.

A person trapped under rubble often cannot reach the phone to change the ringer switch or the volume. With a normal notification sound, a phone left in silent mode stays silent, and the fallback signal is lost. That is why the fallback chain needs `criticalSoundNamed(_:withAudioVolume:)`.

**Scope and limits:**
- Critical alerts are scheduled only after the user explicitly starts the signal, and only as local notifications. There is no server, no remote push and no marketing or general notification.
- Stopping the signal (a 3-second hold) cancels the whole chain immediately.
- At most 64 pending notifications at a time, each sound under 30 seconds. The audible duty cycle is kept at or below 12% for hearing safety.
- The app reschedules the chain only while the signal is active.

**User control:**
- A pre-permission screen explains why critical alerts are requested before the system prompt.
- The user can turn critical alerts off in Settings at any time. The app then warns the user that the fallback signal will not sound in silent mode.

**Why alternatives are not enough:**
- Time Sensitive notifications do not override the ringer switch.
- AlarmKit (iOS 26+) is under evaluation as an additional path. Apple has stated that alarms are not a replacement for critical alerts.
- Keeping the app alive with silent audio is not acceptable, and we do not do it. The live signal is real, audible sound.

**Privacy:** No account, no server, no data collection. Location is never sent anywhere.

**Evidence:** Demo video: `<link>`. Device test summary: `<link>`. Field acoustic test summary: `<link>`. Letter of support: `<attachment>`.

---

## Notlar (göndermeyen için)
- Metindeki "about 1 second every 10–90 seconds" signal-v0 §5'e dayanıyor. v1 kararı (ADR-0004) aralığı değiştirirse güncelle.
- "Saves lives", "guaranteed", "will be found" gibi ifadeler bilinçli olarak yok. Ekleme.
- Ret gelirse (R3): kurumsal ortaklıkla yeniden başvuru. Bu arada normal bildirim yedeği + açık uyarı ve AlarmKit spike (i) sonucu kullanılır.
