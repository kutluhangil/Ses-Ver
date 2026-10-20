import Foundation
import os

/// Spike olaylarını zaman damgasıyla dosyaya (ve unified log'a) yazan küçük yardımcı.
///
/// Satır biçimi (TSV):
/// `seq  wall(ISO8601, UTC, ms)  mono(s, CLOCK_MONOTONIC, uykuyu içerir)  pid  event  k=v …`
///
/// - Dosya: `Documents/spike-logs/<SpikeName>-<başlangıç>.tsv` (Dosyalar uygulamasından ve
///   `xcrun devicectl device copy from …` ile alınabilir).
/// - Aynı olay `Logger` (subsystem `sesver.spike`) ile unified log'a da gider; sysdiagnose içinde görünür.
/// - **Gerçek zamanlı ses iş parçacığından ÇAĞRILMAZ** (dosya G/Ç, kuyruk, bellek ayırma içerir).
final class SpikeLog: @unchecked Sendable {
    static let shared = SpikeLog()

    let spikeName: String
    let fileURL: URL
    let signposter: OSSignposter
    private let logger: Logger
    // Aşağıdakiler yalnızca `queue` üzerinde kullanılır.
    private let queue = DispatchQueue(label: "sesver.spike.log", qos: .utility)
    private var handle: FileHandle?
    private var seq: UInt64 = 0
    private let iso: ISO8601DateFormatter

    private init() {
        spikeName = (Bundle.main.object(forInfoDictionaryKey: "SpikeName") as? String)
            ?? Bundle.main.bundleIdentifier ?? "spike"
        logger = Logger(subsystem: "sesver.spike", category: spikeName)
        signposter = OSSignposter(subsystem: "sesver.spike", category: spikeName)
        iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        iso.timeZone = TimeZone(identifier: "UTC")

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("spike-logs", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        let stamp = ISO8601DateFormatter.string(
            from: Date(), timeZone: TimeZone(identifier: "UTC")!,
            formatOptions: [.withYear, .withMonth, .withDay, .withTime])
        fileURL = dir.appendingPathComponent("\(spikeName)-\(stamp).tsv")
        FileManager.default.createFile(
            atPath: fileURL.path, contents: nil,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        handle = try? FileHandle(forWritingTo: fileURL)
        _ = try? handle?.seekToEnd()
    }

    /// Monotonik saat (s). Uyku süresini içerir; duvar saatinden bağımsızdır.
    static func monotonicSeconds() -> Double {
        Double(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / 1e9
    }

    /// Olay yazar. `fields` sıralı tutulur.
    func log(_ event: String, _ fields: [(String, String)] = []) {
        let now = Date()
        let mono = Self.monotonicSeconds()
        let pid = ProcessInfo.processInfo.processIdentifier
        let kv = fields.map { "\($0.0)=\($0.1)" }.joined(separator: " ")
        logger.notice("\(event, privacy: .public) \(kv, privacy: .public)")
        signposter.emitEvent("spike-event", "\(event, privacy: .public)")
        queue.async { [self] in
            seq += 1
            let line = "\(seq)\t\(iso.string(from: now))\t\(String(format: "%.3f", mono))\t\(pid)\t\(event)\t\(kv)\n"
            if let data = line.data(using: .utf8) {
                do { try handle?.write(contentsOf: data) } catch {
                    logger.error("log write failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    /// Bekleyen satırları diske yazar (ör. arka plana geçerken).
    func flush() {
        queue.sync { try? handle?.synchronize() }
    }

    /// Tüm log dosyaları (en yeni önce).
    func allLogFiles() -> [URL] {
        let dir = fileURL.deletingLastPathComponent()
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
}

/// Önceki çalıştırmanın temiz bitip bitmediğini izler. Uygulama sistem tarafından sonlandırılırsa
/// bir sonraki açılışta `previous_run_unclean` olayı ve son kalp atışı zamanı yazılır.
enum RunMarker {
    private static let runningKey = "spike.run.active"
    private static let lastBeatKey = "spike.run.lastHeartbeat"
    private static let startKey = "spike.run.start"

    static func markLaunch() {
        let d = UserDefaults.standard
        if d.bool(forKey: runningKey) {
            let last = d.double(forKey: lastBeatKey)
            let start = d.double(forKey: startKey)
            SpikeLog.shared.log("previous_run_unclean", [
                ("lastHeartbeatWall", ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: last))),
                ("runStartWall", ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: start))),
                ("aliveHours", String(format: "%.2f", (last - start) / 3600)),
            ])
        }
        SpikeLog.shared.log("app_launch", [
            ("os", ProcessInfo.processInfo.operatingSystemVersionString),
            ("model", Self.hardwareModel()),
        ])
    }

    static func markBeaconStarted() {
        let d = UserDefaults.standard
        d.set(true, forKey: runningKey)
        d.set(Date().timeIntervalSince1970, forKey: startKey)
        d.set(Date().timeIntervalSince1970, forKey: lastBeatKey)
    }

    static func heartbeat() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastBeatKey)
    }

    static func markCleanStop() {
        UserDefaults.standard.set(false, forKey: runningKey)
    }

    /// ör. "iPhone15,2" (pazarlama adı değil; RESULT dosyasına ikisi de yazılır).
    static func hardwareModel() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
