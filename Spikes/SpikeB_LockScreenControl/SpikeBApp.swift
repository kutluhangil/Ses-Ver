import SwiftUI

/// Spike (b): Kilit ekranı / Kontrol Merkezi kontrolü (ControlWidgetButton) + authenticationPolicy.
/// Kontroller `SpikeB_LockScreenControlWidgets` uzantısındadır; niyet uygulama sürecinde çalışır.
@main
struct SpikeBApp: App {
    init() {
        MainActor.assumeIsolated {
            SystemObservers.install()
            RunMarker.markLaunch()
        }
    }

    var body: some Scene {
        WindowGroup {
            SpikeHarnessView(title: "Spike B · Kilit ekranı kontrolü") {
                Section("Kurulum") {
                    Text("Kilit ekranına uzun bas › Özelleştir › Kilit Ekranı › alt köşedeki kontrolü kaldır › + › \"SV B\" › \"SV başlat (her zaman)\". Diğer köşeye \"SV başlat (kimlik)\". Kontrol Merkezi'ne de ekleyin.")
                        .font(.footnote)
                }
            }
        }
    }
}
