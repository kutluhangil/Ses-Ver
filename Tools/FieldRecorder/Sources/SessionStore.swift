import Foundation

/// Kayıt yan dosyası (`<ad>.json`).
struct RecordingSidecar: Codable, Sendable {
    struct Event: Codable, Sendable {
        var zaman: String
        var tur: String        // "kesinti_basladi", "rota_degisti", "motor_yapilandirma", "yazma_hatasi" ...
        var ayrinti: String
    }
    var dosya: String
    var kalibrasyon: Bool
    var form: TrialForm
    var aliciModel: String
    var aliciIOS: String
    var istenenOrneklemeHizi: Double
    var gercekOrneklemeHizi: Double
    var kanal: Int
    var dosyaBicimi: String
    var baslangic: String
    var bitis: String
    var sureSn: Double
    var yazilanCerceve: Int64
    var tepeDBFS: Double
    var uyarilar: [String]
    var kesintiOlaylari: [Event]
}

/// Belgeler/<oturum>/ klasörü, CSV ve JSON yazımı. Yalnız ana iş parçacığından kullanılır.
@MainActor
struct SessionStore {
    static let csvHeader = [
        "tarih_saat", "oturum", "operator", "model", "ios", "ses_yuzde", "kilif", "yonelim", "output_gain",
        "moloz_tipi", "derinlik_m", "foto_no", "dinleyici_yatay_m", "dinleyici_yukseklik_m",
        "gurultu_dBA_LAeq30", "sicaklik_C", "nem_yuzde", "ruzgar_m_sn", "insan_dogru", "insan_yanlis",
        "insan_kacirilan", "insan_yon", "makine_tespit", "makine_crc_gecen", "makine_snr_dB",
        "kayit_dosyasi", "not",
    ]

    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func sessionDir(_ oturum: String) throws -> URL {
        let dir = documents.appendingPathComponent(TrialForm.slug(oturum, fallback: "oturum"), isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func isoString(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = .current
        return f.string(from: date)
    }

    static func stamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd'T'HHmmss"
        return f.string(from: date)
    }

    static func baseName(form: TrialForm, calibration: Bool, start: Date) -> String {
        let oturum = TrialForm.slug(form.oturum, fallback: "oturum")
        let nokta = calibration ? "KAL" : TrialForm.slug(form.nokta, fallback: "P")
        return "\(oturum)_\(nokta)_\(stamp(start))"
    }

    static func writeSidecar(_ sidecar: RecordingSidecar, dir: URL, baseName: String) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try enc.encode(sidecar).write(to: dir.appendingPathComponent(baseName + ".json"), options: .atomic)
    }

    private static func csvEscape(_ s: String) -> String {
        guard s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Oturum CSV'sine bir satır ekler (yoksa başlık yazar). Doldurulmayan sütunlar boş kalır.
    static func appendCSV(sidecar: RecordingSidecar, dir: URL) throws {
        let f = sidecar.form
        let note = sidecar.kalibrasyon
            ? (["94 dB kalibratör tonu", f.not].filter { !$0.isEmpty }.joined(separator: " | "))
            : f.not
        let values: [String: String] = [
            "tarih_saat": sidecar.baslangic, "oturum": f.oturum, "operator": f.operatorAdi,
            "model": f.model, "ios": f.ios, "ses_yuzde": f.sesYuzde, "kilif": f.kilif,
            "yonelim": f.yonelim, "output_gain": f.outputGain, "moloz_tipi": f.molozTipi,
            "derinlik_m": f.derinlikM, "dinleyici_yatay_m": f.dinleyiciYatayM,
            "dinleyici_yukseklik_m": f.dinleyiciYukseklikM, "gurultu_dBA_LAeq30": f.gurultuDBA,
            "sicaklik_C": f.sicaklikC, "kayit_dosyasi": sidecar.dosya, "not": note,
        ]
        let row = csvHeader.map { csvEscape(values[$0] ?? "") }.joined(separator: ",") + "\n"
        let url = dir.appendingPathComponent(TrialForm.slug(f.oturum, fallback: "oturum") + "_deneme.csv")
        if !FileManager.default.fileExists(atPath: url.path) {
            try (csvHeader.joined(separator: ",") + "\n" + row).write(to: url, atomically: true, encoding: .utf8)
        } else {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(row.utf8))
        }
    }

    /// Oturum klasöründeki dosyalar (ShareLink için).
    static func files(in oturum: String) -> [URL] {
        let dir = documents.appendingPathComponent(TrialForm.slug(oturum, fallback: "oturum"), isDirectory: true)
        let items = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return items.filter { !$0.lastPathComponent.hasPrefix(".") }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
