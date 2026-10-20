import AVFoundation
import MediaPlayer
import SwiftUI

/// Spike (f): `AVAudioSession.outputVolume` okuma. Oturum etkin/etkin değil, sessiz anahtarı,
/// kulaklık, Bluetooth ve iOS 27'deki ayrı ses düzeyi kaydırıcıları (zil/alarm/bildirim) altında
/// değerin neyi yansıttığı ölçülür.
///
/// [Kesin] Değer salt okunurdur; sistem ses düzeyini yalnızca kullanıcı değiştirir.
/// Kaynak: developer.apple.com/documentation/avfaudio/avaudiosession/outputvolume
/// `MPVolumeView` yalnızca KULLANICININ oynattığı kaydırıcı olarak gösterilir; programatik olarak
/// ses düzeyi değiştirilmez (yasak yöntem).
@main
struct SpikeFApp: App {
    init() {
        MainActor.assumeIsolated {
            SystemObservers.install()
            RunMarker.markLaunch()
        }
    }

    var body: some Scene {
        WindowGroup {
            SpikeHarnessView(title: "Spike F · Ses düzeyi") {
                VolumeSection()
            }
        }
    }
}

@MainActor
final class VolumeWatcher {
    static let shared = VolumeWatcher()
    private var observation: NSKeyValueObservation?

    func startKVO() {
        observation = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.initial, .new]) { _, change in
            let v = change.newValue ?? -1
            Task { @MainActor in
                SpikeLog.shared.log("output_volume_kvo", [("value", String(format: "%.3f", v)),
                                                          ("route", ChirpEngine.routeDescription())])
            }
        }
        SpikeLog.shared.log("output_volume_kvo_started")
    }

    func setSessionActive(_ active: Bool) {
        do {
            if active {
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)
            } else {
                try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            }
            SpikeLog.shared.log("session_active_set", [("active", "\(active)"), ("outputVolume", "\(AVAudioSession.sharedInstance().outputVolume)")])
        } catch {
            SpikeLog.shared.log("session_active_failed", [("active", "\(active)"), ("error", "\(error)")])
        }
    }

    func readOnce(label: String) {
        SpikeLog.shared.log("output_volume_read", [("label", label),
                                                   ("value", String(format: "%.3f", AVAudioSession.sharedInstance().outputVolume)),
                                                   ("route", ChirpEngine.routeDescription())])
    }
}

struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView { MPVolumeView(frame: .zero) }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

struct VolumeSection: View {
    @State private var label = "durum-1"

    var body: some View {
        Section("outputVolume") {
            Button("KVO başlat") { VolumeWatcher.shared.startKVO() }
            Button("Oturumu etkinleştir (.playback)") { VolumeWatcher.shared.setSessionActive(true) }
            Button("Oturumu kapat") { VolumeWatcher.shared.setSessionActive(false) }
            TextField("Etiket (ör. sessiz-anahtar-açık)", text: $label)
            Button("Şimdi oku ve etiketle") { VolumeWatcher.shared.readOnce(label: label) }
        }
        Section("Kullanıcı kaydırıcısı (MPVolumeView, yalnızca kullanıcı oynatır)") {
            SystemVolumeSlider().frame(height: 40)
        }
    }
}
