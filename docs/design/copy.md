# Ses Ver: metin kataloğu (TR / EN) v0.1

> F1'de `App/SesVer/Localizable.xcstrings`'e taşınacak. Anahtar adları kalıcıdır, metinler değişebilir.
> Metin değişikliği `safety-redteam` onayı olmadan birleşmez (CLAUDE.md). Bu sürüm `docs/safety/findings-2026-10-20.md` bulgularını (S1–S17) içeriyor.

## Ses ve ton
- **Kurban:** Kısa, sakin, emir kipinde ama kibar. Cümle ≤ 8 kelime, ekran başına ≤ 3 cümle. "Siz" hitabı. Ünlem yok.
- **Kurtarıcı:** Alet dili. Sayı + birim + tek kelimelik durum. Hitap yok.
- **Belirsizlik açıkça yazılır:** "olası bölge", "±1,2 m", "Deneysel", "2–5 dk önce", "≥ 1 kişi".
- **Yasak:** "hayat kurtarır", "garanti", "kesin bulunursunuz", "bulunacaksınız", "güvendesiniz", "yakın" (mesafe iddiası olarak), "tam yer".
- **Terim sözlüğü** (tek terim, tek anlam):

| TR | EN | Anlam |
|---|---|---|
| işaret | signal | Ses Ver'in çaldığı çerçeve dizisi (kullanıcıya görünen ad) |
| ıslık | whistle | Tek bir çerçeve (kullanıcıya görünen ad) |
| yedek zincir | backup chain | Katman 2 bildirimleri |
| son dokunuş | last touch | Son "Buradayım" dokunuşu |
| Sessizlik | Silence | Kurtarıcının 60 sn odaklı dinlemesi |
| olası bölge | likely area | AR / güç haritası çıktısı |
| doğrulanıyor | confirming | Tek çerçeveyle duyulmuş işaret |

**Yerelleştirme notları:**
- EN metin TR'den ~%15 kısa, AR metinler ileride ~%25 uzun olabilir. Düğmeler iki satıra izin verir.
- Sayılar yerel biçimde yazılır: TR `+17,4 dB`, EN `+17.4 dB`.
- "112" EN'de de "112" kalır (Avrupa acil numarası). Ülke tespiti v1.2'de.

---

## A. Hazırlık ve kurulum

### 1. Karşılama
| Anahtar | TR | EN |
|---|---|---|
| `onb.1.title` | Enkaz altında telefonunuz sizin yerinize ses verir. | Under rubble, your phone can make sound for you. |
| `onb.1.body` | Islık deseni çalar. Kurtarıcıların telefonu onu gürültü içinde duyabilir. | It plays a whistle pattern that rescuers' phones can pick out of noise. |
| `onb.1.cta` | Devam | Continue |
| `onb.2.title` | Bu bir düdüğün ya da 112'nin yerini tutmaz. | This doesn't replace a whistle or 112. |
| `onb.2.body` | Yanınızda gerçek bir düdük bulundurun. Şebeke varsa önce 112'yi arayın. | Keep a real whistle with you. If there's signal, call 112 first. |
| `onb.2.cta` | Anladım | I understand |

### 2. İzinler (sistem penceresinden önce)
| Anahtar | TR | EN |
|---|---|---|
| `perm.notif.title` | Bildirimler | Notifications |
| `perm.notif.body` | Uygulama kapanırsa işaret bildirimlerle sürer. | If the app closes, the signal continues through notifications. |
| `perm.critical.title` | Kritik uyarılar | Critical alerts |
| `perm.critical.body` | Sessiz modda ve Odak açıkken de çalmasını sağlar. Yalnız işaret için kullanılır. | Lets the signal sound even in silent mode or Focus. Used only for the signal. |
| `perm.mic.title` | Mikrofon | Microphone |
| `perm.mic.body` | Yalnız Dinle modunda ve kurtarıcıya yanıt verirken kullanılır. Kayıt saklanmaz. | Used only in Listen mode and to answer a rescuer. Nothing is stored. |
| `perm.ble.title` | Bluetooth | Bluetooth |
| `perm.ble.body` | Yakındaki kurtarıcı telefonları işareti Bluetooth ile de görebilir. | Nearby rescuer phones can also see the signal over Bluetooth. |
| `perm.cta.allow` | İzin ver | Allow |
| `perm.cta.later` | Şimdi değil | Not now |

### 3. Hazırlık (ana ekran)
| Anahtar | TR | EN | Not |
|---|---|---|---|
| `prep.title` | Hazırlık | Ready check | |
| `prep.counter` | %d / %d hazır | %d / %d ready | |
| `prep.card.body` | İşareti tek dokunuşla başlatın. Eylem Düğmesi'ne basılı tutmak da başlatır. | Start the signal with one tap. Holding the Action button also starts it. | S6: "yeter" kaldırıldı |
| `prep.card.cta` | İşareti başlat | Start signal | |
| `prep.whistle.title` | Gerçek bir düdük | A real whistle | S6: listede 2. sıra |
| `prep.whistle.sub` | Bu uygulama düdüğün yerini tutmaz. | This app doesn't replace a whistle. | |
| `prep.volume.title` | Ses düzeyi | Volume | |
| `prep.volume.ok` | %%%d | %d%% | |
| `prep.volume.low` | %%%d · Sonuna kadar açın | %d%% · Turn it all the way up | |
| `prep.alarmvol.title` | Alarm ses düzeyi | Alarm volume | S15, yalnız AlarmKit yolu açıksa |
| `prep.critical.title` | Kritik uyarı izni | Critical alert permission | |
| `prep.critical.off` | Kapalı. Uygulama kapanırsa sessiz modda duyulmaz. | Off. If the app closes, it won't sound in silent mode. | |
| `prep.critical.cta` | Aç | Turn on | |
| `prep.action.title` | Eylem Düğmesi | Action button | |
| `prep.action.on` | Basılı tutun, işaret başlar | Hold it to start the signal | |
| `prep.lock.title` | Kilit ekranı kontrolü | Lock Screen control | |
| `prep.medical.title` | Tıbbi Kimlik | Medical ID | |
| `prep.medical.sub` | Sağlık uygulamasında doldurun | Fill it in the Health app | |
| `prep.test.cta` | Sinyali 5 sn dene | Test the signal for 5 s | |

### 4. Eylem Düğmesi / kilit ekranı rehberi
| Anahtar | TR | EN |
|---|---|---|
| `guide.title` | Tek hareketle başlatın | Start with one move |
| `guide.step1` | Ayarlar'ı açın, Eylem Düğmesi'ne girin. | Open Settings, then Action Button. |
| `guide.step2` | Kestirme'yi seçin, "Ses Ver'i başlat"ı seçin. | Choose Shortcut, then "Start Ses Ver". |
| `guide.step3` | Deneyin: düğmeye basılı tutun. | Try it: hold the button. |
| `guide.lock.step1` | Kilit ekranına basılı tutun, Özelleştir'e dokunun. | Touch and hold the Lock Screen, tap Customize. |
| `guide.lock.step2` | Bir kontrolü kaldırın, "Ses Ver"i ekleyin. | Remove a control, add "Ses Ver". |
| `guide.fallback` | Eylem Düğmesi yoksa: Ayarlar › Erişilebilirlik › Dokunma › Arkaya Dokunma. | No Action button? Settings › Accessibility › Touch › Back Tap. |
| `guide.done` | Bitti | Done |

### 5. Sinyali dene
| Anahtar | TR | EN |
|---|---|---|
| `test.title` | Sinyal deneniyor | Testing the signal |
| `test.countdown` | %d sn | %d s |
| `test.question` | Duydunuz mu? | Did you hear it? |
| `test.yes` | Evet, duydum | Yes, I heard it |
| `test.no` | Hayır | No |
| `test.no.help` | Ses düzeyini sonuna kadar açın, hoparlörün önünü açın, tekrar deneyin. | Turn the volume all the way up, uncover the speaker, try again. |
| `test.again` | Tekrar dene | Try again |

---

## B. İşaret (kriz anı)

### 6. İşaret aktif
| Anahtar | TR | EN | Not |
|---|---|---|---|
| `beacon.title` | Sinyal veriliyor | Signal is on | |
| `beacon.next` | sonraki ıslık: %d sn | next whistle: %d s | |
| `beacon.chip.volume` | Ses %%%d | Volume %d%% | |
| `beacon.chip.battery` | Pil %%%d | Battery %d%% | S4: saat yok |
| `beacon.chip.battery.measured` | Pil ~%d–%d sa | Battery ~%d–%d h | S4: yalnız ölçülmüş modelde |
| `beacon.chip.chain` | Yedek · %d sa | Backup · %d h | S3 |
| `beacon.chip.chain.weak` | Yedek · sessizde çalmaz | Backup · silent in silent mode | S3 |
| `beacon.here.title` | Buradayım | I'm here | |
| `beacon.here.body` | Ara sıra dokunun. Uygulaması olan kurtarıcılar uyanık olduğunuzu görebilir. | Tap now and then. Rescuers with the app can see you're awake. | S5 |
| `beacon.here.last` | son dokunuş: %@ | last touch: %@ | |
| `beacon.here.now` | şimdi | just now | |
| `beacon.people.title` | Kaç kişisiniz? | How many of you? | S7: başta seçim yok |
| `beacon.injured` | Yaralı var | Someone is hurt | |
| `beacon.call112` | 112'yi ara | Call 112 | |
| `beacon.call112.sub` | Şebeke varsa | If there's signal | S17 |
| `beacon.placement` | Telefonu ekranı yukarı bakacak şekilde, açıklığa doğru ve bir kol boyu uzağa koyun. | Place the phone face up, toward an opening, an arm's length away. | R9 |
| `beacon.mute5` | 5 dk sessize al | Mute for 5 min | S10 |
| `beacon.muted` | Sessizde · %d:%02d sonra yeniden çalar | Muted · resumes in %d:%02d | S10 |
| `beacon.stop` | Durdurmak için 3 sn basılı tutun | Hold 3 s to stop | |

VoiceOver:
- `beacon.here.title`: "Buradayım düğmesi. Ara sıra çift dokunun."
- `beacon.stop`: "Durdur. Üç saniye basılı tutun."

### 7. Ses kısık uyarısı
| Anahtar | TR | EN |
|---|---|---|
| `beacon.lowvol.title` | Ses düzeyi %%%d | Volume is %d%% |
| `beacon.lowvol.body` | Yan taraftaki ses tuşuna basarak sonuna kadar açın. | Press the volume button on the side until it's all the way up. |

### 8. Düşük pil
| Anahtar | TR | EN |
|---|---|---|
| `beacon.lowbat.title` | Pil %%%d | Battery %d%% |
| `beacon.lowbat.body` | Islık aralığı %d sn'ye çıkarıldı. | Whistle interval raised to %d s. |
| `beacon.lowbat.tip` | Ekran parlaklığını kısın. Feneri kapalı tutun. | Lower screen brightness. Keep the flashlight off. |

### 9. Live Activity / Dynamic Island
| Anahtar | TR | EN |
|---|---|---|
| `la.compact` | %d sn | %d s |
| `la.expanded.title` | Sinyal veriliyor · %d sn | Signal on · %d s |
| `la.here` | Buradayım | I'm here |
| `la.last` | son dokunuş %@ | last touch %@ |

### 10. Kontrol Merkezi / kilit ekranı kontrolü
| Anahtar | TR | EN |
|---|---|---|
| `control.title` | Ses Ver | Ses Ver |
| `control.off` | İşareti başlat | Start signal |
| `control.on` | Sinyal veriliyor | Signal on |

### 11. Gece Nöbeti: bekleme
| Anahtar | TR | EN |
|---|---|---|
| `watch.label` | Nöbette · şarjda | On watch · charging |
| `watch.unplugged` | Şarj kablosu çıktı. Nöbet duraklatıldı. | Charger unplugged. Watch paused. |
| `watch.exit` | Çıkmak için iki kez dokunun | Double-tap to exit |

### 12. Gece Nöbeti: sallantı algılandı
| Anahtar | TR | EN | Not |
|---|---|---|---|
| `watch.shake.title` | Sallantı algılandı. İyi misiniz? | Shaking detected. Are you OK? | |
| `watch.shake.body` | Cevap vermezseniz işaret kendiliğinden başlar. Bu soru sesli olarak da tekrarlanıyor. | If you don't answer, the signal starts on its own. This question is also spoken aloud. | |
| `watch.shake.unit` | saniye | seconds | |
| `watch.shake.ok` | İyiyim | I'm OK | |
| `watch.shake.trapped` | Mahsur kaldım, şimdi başlat | I'm trapped, start now | |
| `watch.shake.undo` | İptal edildi · Geri al (%d) | Cancelled · Undo (%d) | S9 |

---

## C. Dinle (kurtarıcı)

### 13. İlk kullanım güvenlik ekranı (S14)
| Anahtar | TR | EN |
|---|---|---|
| `safety.title` | Enkaza çıkmadan önce | Before you climb |
| `safety.rule1` | Ekip lideriyle koordine olun. Tek başınıza enkaza çıkmayın. | Coordinate with a team leader. Don't go on rubble alone. |
| `safety.rule2` | Uygulama bir bölge gösterir, kişinin tam yerini göstermez. | The app shows an area, not a person's exact spot. |
| `safety.rule3` | İşaret boş bir yerden de gelebilir. Son dokunuş bilgisine bakın. | A signal can come from an empty place. Check the last-touch info. |
| `safety.cta` | Anladım | I understand |
| `safety.cta.wait` | Anladım (%d) | I understand (%d) |

### 14. Dinle (liste)
| Anahtar | TR | EN | Not |
|---|---|---|---|
| `listen.title` | Dinle | Listen | |
| `listen.status` | Dinleniyor · gürültü %d dB(A) | Listening · noise %d dB(A) | |
| `listen.silence.cta` | Sessizlik | Silence | |
| `listen.silence.sub` | 60 sn odaklı dinleme | 60 s focused listening | |
| `listen.nearby` | Duyulan işaretler | Signals heard | S11: "yakındaki" kaldırıldı |
| `listen.empty` | Henüz işaret yok. Sessizlik ilan edildiğinde tekrar dinleyin. | No signals yet. Listen again during a silence. | |
| `card.people` | %d kişi | %d people | |
| `card.people.atleast1` | ≥ 1 kişi | ≥ 1 person | S7: kod 0 |
| `card.people.4plus` | 4+ kişi | 4+ people | |
| `card.injured` | Yaralı var | Injured | |
| `card.lastTouch.range` | Son dokunuş %@ önce | Last touch %@ ago | S1: %@ = "2–5 dk" |
| `card.lastTouch.unknown` | Son dokunuş bilinmiyor | Last touch unknown | |
| `card.heard` | %d sn önce duyuldu | heard %d s ago | |
| `card.ble.strong` | BLE: güçlü | BLE: strong | S11 |
| `card.ble.weak` | BLE: zayıf | BLE: weak | S11 |
| `card.ble.none` | BLE: yok | BLE: none | |
| `card.battery` | pil %%%d–%d | battery %d–%d%% | 3 bitlik dilim |
| `card.chain` | Otomatik yedek zincir. Canlılık bilgisi yok, telefon kendi kendine çalıyor. | Automatic backup chain. No sign of life; the phone is playing on its own. | |
| `card.auto` | Otomatik başladı · dokunuş yok | Started automatically · no touch | S8 |
| `card.confirming` | Doğrulanıyor… | Confirming… | S2 |
| `card.confirming.sub` | Bir ıslık duyuldu. İkinci ıslık bekleniyor. | One whistle heard. Waiting for a second. | S2 |
| `card.collision` | Olası ID çakışması | Possible ID clash | |

### 15. Sessizlik modu
| Anahtar | TR | EN |
|---|---|---|
| `silence.title` | Sessizlik | Silence |
| `silence.countdown` | %d sn | %d s |
| `silence.heard` | %d ıslık duyuldu | %d whistles heard |
| `silence.none` | Bu sürede ıslık duyulmadı. | No whistles in this window. |
| `silence.end` | Bitir | End |

### 16. Sıcak-soğuk
| Anahtar | TR | EN | Not |
|---|---|---|---|
| `hc.strength` | Sinyal gücü | Signal strength | |
| `hc.unit` | dB SNR | dB SNR | |
| `hc.up` | Güçleniyor | Getting stronger | |
| `hc.down` | Zayıflıyor | Getting weaker | |
| `hc.flat` | Sabit | Steady | |
| `hc.unsure` | Belirsiz | Unclear | S12 |
| `hc.delta` | son %d ıslıkta %@ dB (±%@) | over last %d whistles %@ dB (±%@) | S12 |
| `hc.last12` | Son %d ıslık | Last %d whistles | |
| `hc.next` | sonraki ~%d sn | next ~%d s | |
| `hc.hint` | Telefonu yüzeye yakın tutup yavaşça gezdirin. Islık gelirken 2 saniye sabit durun. | Hold the phone close to the surface and move slowly. Stay still for 2 s when a whistle comes. | |
| `hc.ar` | AR haritasında göster | Show on AR map | |

### 17. AR güç haritası
| Anahtar | TR | EN | Not |
|---|---|---|---|
| `ar.tracking.good` | Takip: iyi | Tracking: good | |
| `ar.tracking.weak` | Takip: zayıf | Tracking: weak | |
| `ar.tracking.lost` | Takip kayboldu, harita donduruldu. Kamerayı tanıdık bir yüzeye çevirin. | Tracking lost, map frozen. Point the camera at a familiar surface. | |
| `ar.strongest` | En güçlü bölge | Strongest area | |
| `ar.panel.title` | Olası bölge | Likely area | |
| `ar.experimental` | DENEYSEL | EXPERIMENTAL | |
| `ar.samples` | Ölçüm | Samples | |
| `ar.area` | Alan | Area | |
| `ar.uncertainty` | Belirsizlik | Uncertainty | |
| `ar.disclaimer` | Harita sinyalin en güçlü duyulduğu yüzeyi gösterir, kişinin tam yerini değil. Kazıdan önce ekip lideriyle doğrulayın. | The map shows where the signal is strongest on the surface, not the person's exact spot. Confirm with your team leader before digging. | |
| `ar.mark` | Bölgeyi işaretle | Mark area | S13 |
| `ar.export` | Dışa aktar | Export | |
| `ar.light` | Görüntü çok karanlık. Işık tutun. | Too dark. Add light. | |

### 18. Kayıt / dışa aktarma
| Anahtar | TR | EN |
|---|---|---|
| `log.title` | Kayıt | Log |
| `log.send` | Koordinatöre gönder | Send to coordinator |
| `log.format` | CSV + JSON · konumlar AR'a göreli, harita koordinatı yok | CSV + JSON · positions relative to AR, no map coordinates |
| `log.empty` | Henüz algılama yok. | No detections yet. |

---

## D. Ayarlar

### 19. Ayarlar
| Anahtar | TR | EN |
|---|---|---|
| `settings.title` | Ayarlar | Settings |
| `settings.language` | Dil | Language |
| `settings.rhythm` | İşaret ritmini dinle | Hear the signal rhythm |
| `settings.critical` | Kritik uyarılar | Critical alerts |
| `settings.privacy.title` | Gizlilik | Privacy |
| `settings.privacy.body` | Hiçbir veri cihazınızdan çıkmaz. Hesap yok, sunucu yok. | No data leaves your device. No account, no server. |
| `settings.protocol` | Açık sinyal protokolü (SignalSpec) | Open signal protocol (SignalSpec) |
| `settings.terms` | Kullanım koşulları | Terms of use |

---

## Alternatifler (gerekçeli)

**`beacon.here.body`**
| Seçenek | TR | Ton | Ne zaman |
|---|---|---|---|
| A (seçilen) | Ara sıra dokunun. Uygulaması olan kurtarıcılar uyanık olduğunuzu görebilir. | Sakin, dürüst | Varsayılan |
| B | Ara sıra dokunun. Bu, işarete "uyanığım" bilgisini ekler. | Teknik | Kurtarıcının varlığından hiç söz etmemek istenirse |
| C | Dokunun, işaret güncellensin. | En kısa | AX5'te yer darsa |

**`prep.card.body`**
| Seçenek | TR | Ne zaman |
|---|---|---|
| A (seçilen) | İşareti tek dokunuşla başlatın. Eylem Düğmesi'ne basılı tutmak da başlatır. | Eylem Düğmesi kurulu |
| B | İşareti tek dokunuşla başlatın. | Eylem Düğmesi yok veya kurulmamış |

Gerekçe: Panik anında kullanıcı yalnız ilk 3–4 kelimeyi okur. Bu yüzden fiil başa alındı ("Başlatın", "Dokunun"). Vaat içeren yan cümleler ("yeter", "görür") kaldırıldı, yerine kapasite ifadesi ("görebilir") kondu.
