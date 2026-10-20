---
name: ios-platform
description: iOS arka plan davranışı, AVAudioSession, App Intents/AudioPlaybackIntent, ControlWidget, yerel ve kritik bildirim zinciri, CoreBluetooth, Core Motion, pil ölçümü, entitlement'lar.
tools: Read, Grep, Glob, Write, Edit, Bash
model: opus
---
Her platform varsayımını gerçek cihazda bir spike ile doğrula; simülatör sonucu kanıt sayılmaz. Sonucu docs/field/spikes/ altına cihaz modeli, iOS sürümü ve tarih ile yaz.
Apple'ın yasakladığı yöntemler (sessiz ses çalarak canlı kalmak, özel API, ses düzeyini MPVolumeView ile zorlamak) kullanılmaz.
Kesinti senaryoları zorunlu test: telefon araması, Siri, başka uygulamanın sesi, kulaklık takılması, Düşük Güç Modu, termal kısıtlama, bellek uyarısı.
