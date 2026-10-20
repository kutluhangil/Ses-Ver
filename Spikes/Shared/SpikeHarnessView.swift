import AVFoundation
import SwiftUI

/// Spike'ların ortak deney arayüzü (ürün arayüzü DEĞİL; F0 kapısı kuralı ürün UI'ı içindir).
/// Ses varyantı/aralık/kazanç seçimi, başlat/durdur, canlı sayaçlar ve log paylaşımı.
struct SpikeHarnessView<Extra: View>: View {
    let title: String
    let showEngineControls: Bool
    @ViewBuilder var extra: () -> Extra

    @State private var variant = SpikeSettings.current.variant
    @State private var interval = SpikeSettings.current.intervalSeconds
    @State private var gain = Double(SpikeSettings.current.gain)
    @State private var lastError: String?

    init(title: String, showEngineControls: Bool = true, @ViewBuilder extra: @escaping () -> Extra) {
        self.title = title
        self.showEngineControls = showEngineControls
        self.extra = extra
    }

    var body: some View {
        NavigationStack {
            Form {
                if showEngineControls {
                    Section("İşaret sesi") {
                        Picker("Oturum", selection: $variant) {
                            ForEach(SessionVariant.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        // Alt sınır 10 s: Ton/I ≤ %12 (signal-v0 §5 kulak güvenliği).
                        Stepper("Aralık: \(Int(interval)) s", value: $interval, in: 10...120, step: 5)
                        VStack(alignment: .leading) {
                            Text("Kazanç: \(gain, specifier: "%.2f") (kulağa yakın tutmayın)")
                            Slider(value: $gain, in: 0.05...1.0)
                        }
                        Button("Ayarları kaydet (niyetler de bunu kullanır)") { persist() }
                        HStack {
                            Button("Başlat") {
                                persist()
                                do { try ChirpEngine.shared.start(reason: "ui") } catch {
                                    lastError = "\(error)"
                                    SpikeLog.shared.log("engine_start_failed", [("error", "\(error)")])
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            Spacer()
                            Button("Durdur", role: .destructive) { ChirpEngine.shared.stop(reason: "ui") }
                        }
                        if variant == .playAndRecord {
                            Button("Mikrofon izni iste") {
                                AVAudioApplication.requestRecordPermission { ok in
                                    SpikeLog.shared.log("mic_permission", [("granted", "\(ok)")])
                                }
                            }
                        }
                    }
                }
                extra()
                Section("Durum") {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let e = ChirpEngine.shared
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Çalışıyor: \(e.isRunning ? "evet" : "hayır") · çerçeve: \(e.framesEmitted) · yeniden başlatma: \(e.restartCount)")
                            Text("Ses düzeyi (outputVolume): \(AVAudioSession.sharedInstance().outputVolume, specifier: "%.2f")")
                            Text("Çıkış: \(ChirpEngine.routeDescription())")
                        }
                        .font(.footnote.monospaced())
                    }
                    if let lastError { Text(lastError).foregroundStyle(.red).font(.footnote) }
                }
                Section("Log") {
                    Text(SpikeLog.shared.fileURL.lastPathComponent).font(.caption.monospaced())
                    ShareLink("Bu çalıştırmanın logunu paylaş", item: SpikeLog.shared.fileURL)
                    Button("Kalp atışı yaz") { Heartbeat.beat() }
                }
            }
            .navigationTitle(title)
        }
    }

    private func persist() {
        SpikeSettings(variant: variant, intervalSeconds: interval, gain: Float(gain)).save()
        SpikeLog.shared.log("settings_saved", [("variant", variant.rawValue), ("interval", "\(interval)"), ("gain", "\(gain)")])
    }
}

extension SpikeHarnessView where Extra == EmptyView {
    init(title: String, showEngineControls: Bool = true) {
        self.init(title: title, showEngineControls: showEngineControls) { EmptyView() }
    }
}
