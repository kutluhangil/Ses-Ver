import AVFoundation
import Foundation

/// Gerçek zamanlı render bloğunun okuduğu/yazdığı durum.
///
/// Tüm bellek `start` sırasında, render başlamadan ÖNCE ayrılır; render bloğu bellek ayırmaz,
/// kilit almaz, log yazmaz. `frames` sayacı render iş parçacığında yazılır, ana iş parçacığında
/// yalnızca okunur (hizalı tek sözcük; arm64'te yırtılmaz). Spike için bilinçli olarak kabul edildi;
/// üretimde `Synchronization.Atomic` (iOS 18+) kullanılmalı.
final class ChirpRenderState: @unchecked Sendable {
    let samples: UnsafeMutableBufferPointer<Float>
    let frameLength: Int
    let basePeriod: Int
    let gain: Float
    let pos: UnsafeMutablePointer<Int>
    let period: UnsafeMutablePointer<Int>
    let rng: UnsafeMutablePointer<UInt64>
    let frames: UnsafeMutablePointer<Int>

    init(frame: [Float], basePeriodSamples: Int, gain: Float) {
        samples = .allocate(capacity: frame.count)
        _ = samples.initialize(from: frame)
        frameLength = frame.count
        basePeriod = max(basePeriodSamples, frame.count + 1)
        self.gain = gain
        pos = .allocate(capacity: 1); pos.initialize(to: 0)
        period = .allocate(capacity: 1); period.initialize(to: basePeriod)
        rng = .allocate(capacity: 1); rng.initialize(to: UInt64.random(in: 1...UInt64.max))
        frames = .allocate(capacity: 1); frames.initialize(to: 0)
    }

    deinit {
        samples.deallocate()
        pos.deallocate(); period.deallocate(); rng.deallocate(); frames.deallocate()
    }

    /// `I · U(0,85; 1,15)` (signal-v0 §5). xorshift64; bellek ayırmaz.
    @inline(__always)
    func nextPeriod() -> Int {
        var x = rng.pointee
        x ^= x << 13; x ^= x >> 7; x ^= x << 17
        rng.pointee = x
        let u = Double(x >> 11) / Double(1 << 53)
        return max(frameLength + 1, Int(Double(basePeriod) * (0.85 + 0.30 * u)))
    }

    func makeRenderBlock() -> AVAudioSourceNodeRenderBlock {
        // `unowned(unsafe)`: render sırasında ARC trafiği olmasın. Yaşam süresi ChirpEngine tarafından
        // garanti edilir (düğüm ayrılmadan durum serbest bırakılmaz).
        return { [unowned(unsafe) self] _, _, frameCount, ablPointer in
            let abl = UnsafeMutableAudioBufferListPointer(ablPointer)
            let n = Int(frameCount)
            var p = self.pos.pointee
            var per = self.period.pointee
            var count = self.frames.pointee
            for b in 0..<abl.count {
                guard let out = abl[b].mData?.assumingMemoryBound(to: Float.self) else { continue }
                if b == 0 {
                    for i in 0..<n {
                        if p == 0 { count &+= 1 }
                        out[i] = p < self.frameLength ? self.samples[p] * self.gain : 0
                        p += 1
                        if p >= per { p = 0; per = self.nextPeriod() }
                    }
                } else if let first = abl[0].mData {
                    out.update(from: first.assumingMemoryBound(to: Float.self), count: n)
                }
            }
            self.pos.pointee = p
            self.period.pointee = per
            self.frames.pointee = count
            return noErr
        }
    }
}

/// Spike'larda kullanılan ses oturumu varyantları.
enum SessionVariant: String, CaseIterable, Sendable {
    /// `.playback`, karıştırılamaz. Sessiz anahtarını yok sayar.
    case playback
    /// `.playback` + `.mixWithOthers`. Başka uygulamanın sesi bizi kesmez (ama Now Playing/öncelik yok).
    case playbackMix
    /// `.playAndRecord` + `.defaultToSpeaker` (+ giriş tap'i). Katman 1 + dinleme penceresi (v1.1) senaryosu.
    case playAndRecord
}

struct SpikeSettings: Sendable {
    var variant: SessionVariant
    /// Nominal çerçeve aralığı (s). Ürün taslağı: 10 / 20 / 45 / 90.
    var intervalSeconds: Double
    /// signal-v0 §3.5 `outputGain`. Kulak güvenliği ölçülmeden 1,0 = açık risk (docs/safety).
    var gain: Float

    static var current: SpikeSettings {
        let d = UserDefaults.standard
        return SpikeSettings(
            variant: SessionVariant(rawValue: d.string(forKey: "spike.variant") ?? "") ?? .playback,
            intervalSeconds: d.object(forKey: "spike.interval") as? Double ?? 10,
            gain: d.object(forKey: "spike.gain") as? Float ?? 1.0)
    }

    func save() {
        let d = UserDefaults.standard
        d.set(variant.rawValue, forKey: "spike.variant")
        d.set(intervalSeconds, forKey: "spike.interval")
        d.set(gain, forKey: "spike.gain")
    }
}

/// Mikrofon tap'inin tepe değeri. Tap bloğu gerçek zamanlı IO iş parçacığında değil, AVAudioEngine'in
/// dağıttığı ayrı bir iş parçacığında çalışır; yine de burada log/ayırma yapılmaz.
final class MicPeakBox: @unchecked Sendable {
    let peak = UnsafeMutablePointer<Float>.allocate(capacity: 1)
    let buffers = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    init() { peak.initialize(to: 0); buffers.initialize(to: 0) }
    deinit { peak.deallocate(); buffers.deallocate() }
    func takePeak() -> (Float, Int) {
        let v = (peak.pointee, buffers.pointee)
        peak.pointee = 0
        return v
    }
}

/// AVAudioEngine + AVAudioSourceNode ile periyodik, duyulabilir işaret çalar.
///
/// Çerçeveler arasında sessizlik çalınır (oturum kesintisiz kalır; BLUEPRINT §3.2). Bu, "sessiz ses
/// çalarak canlı kalma" değildir: her `intervalSeconds` saniyede bir gerçek, duyulabilir çerçeve çalınır.
/// App Review notunda bu açıkça anlatılmalı (R4).
@MainActor
final class ChirpEngine {
    static let shared = ChirpEngine()

    private var engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var state: ChirpRenderState?
    private var settings = SpikeSettings.current
    private var observers: [NSObjectProtocol] = []
    let mic = MicPeakBox()
    private(set) var isRunning = false
    private(set) var startedAt: Date?
    private(set) var restartCount = 0

    var framesEmitted: Int { state?.frames.pointee ?? 0 }

    private init() { installObservers() }

    func start(_ settings: SpikeSettings = .current, reason: String) throws {
        if isRunning { SpikeLog.shared.log("engine_start_ignored", [("reason", reason)]); return }
        self.settings = settings
        let interval = SpikeLog.shared.signposter.beginInterval("engine-start")
        defer { SpikeLog.shared.signposter.endInterval("engine-start", interval) }
        try configureSession(settings.variant)
        try buildAndStartEngine()
        isRunning = true
        if startedAt == nil { startedAt = Date() }
        RunMarker.markBeaconStarted()
        SpikeLog.shared.log("engine_started", [
            ("reason", reason), ("variant", settings.variant.rawValue),
            ("interval", "\(settings.intervalSeconds)"), ("gain", "\(settings.gain)"),
            ("outputVolume", "\(AVAudioSession.sharedInstance().outputVolume)"),
            ("route", Self.routeDescription()),
        ])
    }

    func stop(reason: String) {
        if settings.variant == .playAndRecord { engine.inputNode.removeTap(onBus: 0) }
        engine.stop()
        if let source { engine.detach(source) }
        source = nil
        state = nil
        isRunning = false
        startedAt = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        RunMarker.markCleanStop()
        SpikeLog.shared.log("engine_stopped", [("reason", reason)])
    }

    private func configureSession(_ variant: SessionVariant) throws {
        let s = AVAudioSession.sharedInstance()
        switch variant {
        case .playback:
            try s.setCategory(.playback, mode: .default, options: [])
        case .playbackMix:
            try s.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        case .playAndRecord:
            // .defaultToSpeaker olmazsa çıkış ahizeye (kulaklık hoparlörü) gider.
            try s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        }
        try s.setActive(true)
    }

    private func buildAndStartEngine() throws {
        let fs = 48_000.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: fs, channels: 1) else {
            throw NSError(domain: "spike", code: 1)
        }
        let st = ChirpRenderState(
            frame: ChirpWaveform.frame(sampleRate: fs),
            basePeriodSamples: Int(settings.intervalSeconds * fs),
            gain: settings.gain)
        let node = AVAudioSourceNode(format: format, renderBlock: st.makeRenderBlock())
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        if settings.variant == .playAndRecord {
            let input = engine.inputNode
            let box = mic
            input.installTap(onBus: 0, bufferSize: 4_096, format: input.outputFormat(forBus: 0)) { buffer, _ in
                guard let ch = buffer.floatChannelData?[0] else { return }
                var m: Float = 0
                for i in 0..<Int(buffer.frameLength) { m = max(m, abs(ch[i])) }
                box.peak.pointee = max(box.peak.pointee, m)
                box.buffers.pointee &+= 1
            }
        }
        engine.prepare()
        try engine.start()
        state = st          // düğüm bağlıyken durum yaşar (unowned(unsafe) için)
        source = node
    }

    /// Kesinti / yapılandırma değişikliği sonrası yeniden başlatma.
    private func restart(reason: String) {
        guard isRunning else { return }
        restartCount += 1
        if settings.variant == .playAndRecord { engine.inputNode.removeTap(onBus: 0) }
        engine.stop()
        if let source { engine.detach(source) }
        source = nil
        state = nil
        do {
            try configureSession(settings.variant)
            try buildAndStartEngine()
            SpikeLog.shared.log("engine_restarted", [("reason", reason), ("restartCount", "\(restartCount)")])
        } catch {
            SpikeLog.shared.log("engine_restart_failed", [("reason", reason), ("error", "\(error)")])
        }
    }

    private func rebuildAfterMediaReset() {
        engine = AVAudioEngine()
        source = nil
        state = nil
        restart(reason: "mediaServicesReset")
    }

    private func installObservers() {
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { note in
            let info = note.userInfo ?? [:]
            let type = (info[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init)
            let opts = AVAudioSession.InterruptionOptions(rawValue: info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            let reasonRaw = info[AVAudioSessionInterruptionReasonKey] as? UInt ?? 999
            let began = type == .began
            let shouldResume = opts.contains(.shouldResume)
            MainActor.assumeIsolated {
                SpikeLog.shared.log(began ? "audio_interruption_began" : "audio_interruption_ended", [
                    ("shouldResume", "\(shouldResume)"), ("reasonRaw", "\(reasonRaw)"),
                ])
                // İşaret uygulaması: sistem shouldResume demese de yeniden başlatmayı dener ve sonucu loglar.
                if !began { ChirpEngine.shared.restart(reason: "interruptionEnded(shouldResume=\(shouldResume))") }
            }
        })
        observers.append(nc.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { note in
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 999
            MainActor.assumeIsolated {
                SpikeLog.shared.log("route_change", [("reasonRaw", "\(reason)"), ("route", ChirpEngine.routeDescription())])
            }
        })
        observers.append(nc.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                SpikeLog.shared.log("media_services_reset")
                ChirpEngine.shared.rebuildAfterMediaReset()
            }
        })
        observers.append(nc.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                SpikeLog.shared.log("engine_configuration_change")
                ChirpEngine.shared.restart(reason: "configurationChange")
            }
        })
    }

    static func routeDescription() -> String {
        AVAudioSession.sharedInstance().currentRoute.outputs
            .map { "\($0.portType.rawValue)" }.joined(separator: ",")
    }
}
