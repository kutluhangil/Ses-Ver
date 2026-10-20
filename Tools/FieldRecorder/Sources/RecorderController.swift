import AVFoundation
import Foundation
import Observation

/// Tap bloğunda çalışan yazıcı.
///
/// Gerçek zamanlı güvenlik notu: `AVAudioEngine.installTap` bloğu HAL'in gerçek zamanlı IO
/// iş parçacığında DEĞİL, motorun kendi gerçek zamansız tap kuyruğunda çağrılır; tampon IO
/// iş parçacığından o kuyruğa motor tarafından kopyalanır. Bu blokta uygulama tarafında
/// bellek ayırma (String/Array/closure), kilit, log ve aktör sıçraması YOK: yalnızca
/// `AVAudioFile.write` (dosyaya yazmanın kendi yolu) ve ön-ayrılmış alanlara skaler yazma var.
/// Yazma bir an takılsa bile ses IO iş parçacığı etkilenmez. Alanlara yalnızca tap kuyruğu
/// yazar; ana iş parçacığı `removeTap` döndükten SONRA okur (bu noktada tap artık çağrılmaz).
final class TapWriter: @unchecked Sendable {
    private var file: AVAudioFile?
    private(set) var frames: Int64 = 0
    private(set) var peak: Float = 0
    private(set) var failed = false

    init(file: AVAudioFile) { self.file = file }

    func write(_ buffer: AVAudioPCMBuffer) {
        guard let file, !failed else { return }
        if let ch = buffer.floatChannelData {
            let n = Int(buffer.frameLength)
            var p = peak
            for c in 0..<Int(buffer.format.channelCount) {
                let ptr = ch[c]
                for i in 0..<n {
                    let v = abs(ptr[i])
                    if v > p { p = v }
                }
            }
            peak = p
        }
        do {
            try file.write(from: buffer)
            frames += Int64(buffer.frameLength)
        } catch {
            failed = true   // yalnız bayrak; ayrıntı yok (hata dizesi ayırmaz)
        }
    }

    /// Dosyayı kapatır (AVAudioFile kapanışı serbest bırakmayla olur). Yalnız tap kaldırıldıktan sonra.
    func close() { file = nil }
}

@MainActor
@Observable
final class RecorderController {
    var form = TrialForm.loadLast()
    var calibrationMode = false
    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var status = "Hazır"
    private(set) var lastSaved = ""
    private(set) var warnings: [String] = []
    private(set) var sessionFiles: [URL] = []

    static let calibrationSeconds: TimeInterval = 10
    private static let requestedRate = 48_000.0

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var writer: TapWriter?
    @ObservationIgnored private var current: Current?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    private struct Current {
        var baseName: String
        var dir: URL
        var form: TrialForm
        var calibration: Bool
        var start: Date
        var startMono: TimeInterval
        var rate: Double
        var channels: Int
        var warnings: [String]
        var events: [RecordingSidecar.Event]
    }

    init() {
        refreshFiles()
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            MainActor.assumeIsolated { self?.handleInterruption(typeRaw: raw) }
        })
        observers.append(nc.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            MainActor.assumeIsolated { self?.handleRouteChange(reasonRaw: raw) }
        })
        observers.append(nc.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleEngineConfigChange() }
        })
    }

    // MARK: Başlat / durdur

    func toggle() {
        if isRecording { finish(reason: "kullanici_durdurdu", isInterruption: false) } else { Task { await start() } }
    }

    private func start() async {
        guard !isRecording else { return }
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else { status = "Mikrofon izni yok (Ayarlar > SV Kayıt)"; return }

        let calibration = calibrationMode
        form.saveAsLast()
        let startDate = Date()
        var warn: [String] = []
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setPreferredSampleRate(Self.requestedRate)
            try? session.setPreferredInputNumberOfChannels(1)
            try session.setActive(true)

            let format = engine.inputNode.outputFormat(forBus: 0)
            let rate = format.sampleRate
            let channels = Int(format.channelCount)
            if rate != Self.requestedRate { warn.append("Cihaz 48 kHz vermedi: gerçek hız \(Int(rate)) Hz") }
            if channels != 1 { warn.append("Mono beklenirdi, kanal sayısı \(channels)") }
            if let port = session.currentRoute.inputs.first?.portType, port != .builtInMic {
                warn.append("Giriş yerleşik mikrofon değil: \(port.rawValue)")
            }

            let dir = try SessionStore.sessionDir(form.oturum)
            let base = SessionStore.baseName(form: form, calibration: calibration, start: startDate)
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: rate,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: 24,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ]
            let file = try AVAudioFile(forWriting: dir.appendingPathComponent(base + ".wav"),
                                       settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            let w = TapWriter(file: file)
            writer = w
            engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
                w.write(buffer)
            }
            engine.prepare()
            try engine.start()

            current = Current(baseName: base, dir: dir, form: form, calibration: calibration, start: startDate,
                              startMono: ProcessInfo.processInfo.systemUptime, rate: rate, channels: channels,
                              warnings: warn, events: [])
            warnings = warn
            isRecording = true
            elapsed = 0
            status = calibration ? "Kalibrasyon kaydı (10 sn)" : "Kayıt: \(base)"
            startTicker(autoStopAfter: calibration ? Self.calibrationSeconds : nil)
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            writer?.close()
            writer = nil
            current = nil
            status = "Başlatılamadı: \(error.localizedDescription)"
        }
    }

    private func startTicker(autoStopAfter limit: TimeInterval?) {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, let cur = self.current else { return }
                self.elapsed = ProcessInfo.processInfo.systemUptime - cur.startMono
                if let limit, self.elapsed >= limit {
                    self.finish(reason: "kalibrasyon_suresi_doldu", isInterruption: false)
                    return
                }
            }
        }
    }

    /// Kaydı kapatır, yan dosyayı ve CSV satırını yazar. Kesinti dahil tüm duruşlar buradan geçer.
    private func finish(reason: String, isInterruption: Bool) {
        guard isRecording, var cur = current, let w = writer else { return }
        ticker?.cancel()
        ticker = nil
        engine.inputNode.removeTap(onBus: 0)   // döndükten sonra tap çağrılmaz
        engine.stop()
        let frames = w.frames
        let peak = w.peak
        let failed = w.failed
        w.close()
        writer = nil
        current = nil
        isRecording = false

        let end = Date()
        let dur = ProcessInfo.processInfo.systemUptime - cur.startMono
        let expected = dur * cur.rate
        if failed { cur.warnings.append("AVAudioFile yazma hatası: dosya eksik olabilir") }
        if expected > 0, abs(Double(frames) - expected) / expected > 0.02 {
            cur.warnings.append("Yazılan çerçeve (\(frames)) süreden beklenenden (\(Int(expected))) %2'den fazla sapıyor: boşluk olabilir")
        }
        cur.events.append(.init(zaman: SessionStore.isoString(end), tur: "durdu", ayrinti: reason))
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        let sidecar = RecordingSidecar(
            dosya: cur.baseName + ".wav", kalibrasyon: cur.calibration, form: cur.form,
            aliciModel: DeviceInfo.machine, aliciIOS: DeviceInfo.systemVersion,
            istenenOrneklemeHizi: Self.requestedRate, gercekOrneklemeHizi: cur.rate, kanal: cur.channels,
            dosyaBicimi: "WAV linear PCM 24 bit little-endian",
            baslangic: SessionStore.isoString(cur.start), bitis: SessionStore.isoString(end),
            sureSn: (dur * 1000).rounded() / 1000, yazilanCerceve: frames,
            tepeDBFS: (20 * log10(Double(max(peak, 1e-9))) * 10).rounded() / 10,
            uyarilar: cur.warnings, kesintiOlaylari: cur.events)
        do {
            try SessionStore.writeSidecar(sidecar, dir: cur.dir, baseName: cur.baseName)
            try SessionStore.appendCSV(sidecar: sidecar, dir: cur.dir)
            lastSaved = "\(cur.baseName).wav  \(String(format: "%.1f", dur)) sn  tepe \(sidecar.tepeDBFS) dBFS"
            status = isInterruption ? "Kesinti: kayıt durdu, dosya kaydedildi" : "Kaydedildi"
        } catch {
            status = "Yan dosya/CSV yazılamadı: \(error.localizedDescription)"
        }
        warnings = cur.warnings
        refreshFiles()
    }

    // MARK: Kesintiler

    private func noteEvent(_ tur: String, _ detail: String) {
        current?.events.append(.init(zaman: SessionStore.isoString(Date()), tur: tur, ayrinti: detail))
    }

    private func handleInterruption(typeRaw: UInt?) {
        guard let typeRaw, let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
        switch type {
        case .began:
            guard isRecording else { return }
            noteEvent("kesinti_basladi", "arama/Siri/başka uygulama")
            finish(reason: "kesinti", isInterruption: true)
        case .ended:
            status = "Kesinti bitti. Yeni kayıt için Kaydet'e basın."
        @unknown default:
            break
        }
    }

    private func handleRouteChange(reasonRaw: UInt?) {
        guard isRecording, let reasonRaw, let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) else { return }
        noteEvent("rota_degisti", "neden=\(reasonRaw)")
        // Giriş cihazı kaybolur/eklenirse kayıt kaynağı değişir; dosyayı kapatıp durdururuz.
        if reason == .oldDeviceUnavailable || reason == .newDeviceAvailable {
            finish(reason: "rota_degisti", isInterruption: true)
        }
    }

    private func handleEngineConfigChange() {
        guard isRecording else { return }
        noteEvent("motor_yapilandirma", "AVAudioEngineConfigurationChange")
        finish(reason: "motor_yapilandirma_degisti", isInterruption: true)
    }

    // MARK: Dışa aktarma

    func refreshFiles() {
        sessionFiles = SessionStore.files(in: form.oturum)
    }
}
