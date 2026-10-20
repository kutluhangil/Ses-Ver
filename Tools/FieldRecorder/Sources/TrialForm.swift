import Foundation
import UIKit

/// Sahada girilen deneme alanları. Son değerler UserDefaults'ta tutulur ve bir sonraki denemeye taşınır.
struct TrialForm: Codable, Equatable, Sendable {
    var oturum = "S1"
    var nokta = "P00"
    var operatorAdi = ""
    var model = ""          // verici model
    var ios = ""            // verici iOS
    var sesYuzde = "100"
    var kilif = "yok"
    var yonelim = "ekran aşağı"
    var outputGain = ""
    var molozTipi = "M1"
    var derinlikM = ""
    var dinleyiciYatayM = ""
    var dinleyiciYukseklikM = ""
    var gurultuDBA = ""
    var sicaklikC = ""
    var not = ""

    static let defaultsKey = "FieldRecorder.lastForm.v1"

    static func loadLast() -> TrialForm {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let form = try? JSONDecoder().decode(TrialForm.self, from: data) {
            return form
        }
        return TrialForm()
    }

    func saveAsLast() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    /// Dosya adı için güvenli parça (harf/rakam/-/_ dışını `-` yapar).
    static func slug(_ s: String, fallback: String) -> String {
        let cleaned = String(s.unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" ? Character($0) : "-"
        })
        return cleaned.isEmpty ? fallback : cleaned
    }
}

enum DeviceInfo {
    /// "iPhone16,1" gibi donanım tanımlayıcısı.
    static var machine: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
    @MainActor static var systemVersion: String { UIDevice.current.systemVersion }
}
