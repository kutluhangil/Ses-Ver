#if os(iOS)
import AVFoundation
#else
import Foundation
import AVFAudio
#endif
import BeaconKit

/// AVAudioEngine + AVAudioSourceNode ile kesintisiz arka plan işaret ses motoru (BLUEPRINT §3.2 Katman 1).
@MainActor
public final class AudioSessionCtl: ObservableObject {
    public static let shared = AudioSessionCtl()

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var framesPlayed: Int = 0
    #if os(iOS)
    @Published public private(set) var currentVolume: Float = AVAudioSession.sharedInstance().outputVolume
    #else
    @Published public private(set) var currentVolume: Float = 1.0
    #endif
    @Published public private(set) var nextFrameSeconds: Int = 10

    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var scheduleEngine = ScheduleEngine()
    private var activePayload: PayloadV1?
    #if os(iOS)
    private var volumeObserver: NSKeyValueObservation?
    #endif

    // Gerçek zamanlı ses tamponları (render bloğunda bellek ayırmamak için önceden ayrılır)
    private nonisolated(unsafe) var frameBuffer: [Float] = []
    private nonisolated(unsafe) var frameBufferIndex: Int = 0
    private nonisolated(unsafe) var samplesUntilNextFrame: Int = 0
    private nonisolated(unsafe) var sampleRate: Double = 48_000.0

    private init() {
        setupObservers()
    }

    private func setupObservers() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        volumeObserver = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let newVol = change.newValue else { return }
            Task { @MainActor [weak self] in
                self?.currentVolume = newVol
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notif in
            guard let info = notif.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt
            let shouldResume = optionsValue.map { AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume) } ?? false

            Task { @MainActor [weak self] in
                self?.handleInterruption(type: type, shouldResume: shouldResume)
            }
        }
        #endif
    }

    #if os(iOS)
    private func handleInterruption(type: AVAudioSession.InterruptionType, shouldResume: Bool) {
        if type == .ended && shouldResume {
            try? engine?.start()
        }
    }
    #endif

    public func start(payload: PayloadV1, spec: SignalSpec = .v1) throws {
        self.activePayload = payload
        self.scheduleEngine = ScheduleEngine(startTime: Date())
        self.sampleRate = spec.sampleRate

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
        #endif

        // Sinyal çerçevesini sentezle
        let samples = FrameEncoder.encode(payload: payload, spec: spec, outputGain: 1.0)
        self.frameBuffer = samples
        self.frameBufferIndex = 0
        self.samplesUntilNextFrame = 0

        let eng = AVAudioEngine()
        let format = AVAudioFormat(standardFormatWithSampleRate: spec.sampleRate, channels: 1)!

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buf = ablPointer.first, let ptr = buf.mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }

            for i in 0..<Int(frameCount) {
                if self.frameBufferIndex < self.frameBuffer.count {
                    ptr[i] = self.frameBuffer[self.frameBufferIndex]
                    self.frameBufferIndex += 1
                } else {
                    ptr[i] = 0.0 // sessizlik
                    if self.samplesUntilNextFrame > 0 {
                        self.samplesUntilNextFrame -= 1
                    } else {
                        // Yeni çerçeve başlangıcı
                        self.frameBufferIndex = 0
                        let interval = 10.0 // Varsayılan test aralığı
                        self.samplesUntilNextFrame = Int(interval * self.sampleRate)
                    }
                }
            }
            return noErr
        }

        eng.attach(node)
        eng.connect(node, to: eng.mainMixerNode, format: format)
        try eng.start()

        self.engine = eng
        self.sourceNode = node
        self.isRunning = true
    }

    public func stop() {
        engine?.stop()
        sourceNode = nil
        engine = nil
        isRunning = false
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}
