import Foundation

/// SignalSpec v0 çerçeve DÜZENİNE (docs/contracts/signal-v0.md §2–3) yaklaşık bir dalga biçimi üretir.
///
/// NORMATİF DEĞİLDİR. Yalnızca platform spike'ları için duyulabilir, gerçekçi enerji/görev döngüsüne
/// sahip bir işaret sağlar (pil, arka plan, bildirim sesi testleri). CRC ve yük kodlaması yoktur;
/// kod çözme testi için kullanılmaz. Referans üretici `research/signal` (dsp-acoustics) altındadır.
enum ChirpWaveform {
    static let fL = 1_800.0
    static let fH = 4_200.0
    static let bandwidth = fH - fL
    static let tp = 0.120      // giriş/senk chirp süresi
    static let tg = 0.080      // giriş chirp'leri arası boşluk
    static let ts = 0.064      // veri sembolü süresi
    static let symbolCount = 8
    static let alphabet = 16.0
    /// −1 dBFS (signal-v0 §3.5).
    static let amplitude: Float = 0.891

    /// Çerçeve süresi saniye (≈ 1,232 s).
    static var frameDuration: Double { 3 * (tp + tg) + tp + Double(symbolCount) * ts }
    /// Akustik açık kalma süresi (boşluklar hariç, ≈ 0,992 s).
    static var onDuration: Double { 4 * tp + Double(symbolCount) * ts }

    /// Tek bir çerçeve: U1 G1 U2 G2 U3 G3 D S0…S7. Kaydırmalar sabit örnek değerlerdir.
    static func frame(sampleRate fs: Double, shifts: [Int] = [7, 15, 2, 0, 9, 4, 12, 1]) -> [Float] {
        var out: [Float] = []
        out.reserveCapacity(Int(frameDuration * fs) + 8)
        for _ in 0..<3 {
            out += risingChirp(fs: fs)
            out += silence(seconds: tg, fs: fs)   // G1, G2, G3
        }
        out += fallingChirp(fs: fs)
        for s in shifts.prefix(symbolCount) {
            out += cssSymbol(shift: s, fs: fs)
        }
        return out
    }

    static func silence(seconds: Double, fs: Double) -> [Float] {
        [Float](repeating: 0, count: Int((seconds * fs).rounded()))
    }

    static func risingChirp(fs: Double) -> [Float] {
        let n = Int((tp * fs).rounded())
        let k = bandwidth / (2 * tp)
        return (0..<n).map { i in
            let t = Double(i) / fs
            let phi = 2 * Double.pi * (fL * t + k * t * t)
            return amplitude * Float(window(i, n, ramp: Int(0.005 * fs)) * sin(phi))
        }
    }

    static func fallingChirp(fs: Double) -> [Float] {
        let n = Int((tp * fs).rounded())
        let k = bandwidth / (2 * tp)
        return (0..<n).map { i in
            let t = Double(i) / fs
            let phi = 2 * Double.pi * (fH * t - k * t * t)
            return amplitude * Float(window(i, n, ramp: Int(0.005 * fs)) * sin(phi))
        }
    }

    static func cssSymbol(shift s: Int, fs: Double) -> [Float] {
        let n = Int((ts * fs).rounded())
        let k = bandwidth / ts
        let tw = ts * (1 - Double(s) / alphabet)
        let f0 = fL + Double(s) * bandwidth / alphabet
        let phiTw = 2 * Double.pi * (f0 * tw + 0.5 * k * tw * tw)
        return (0..<n).map { i in
            let t = Double(i) / fs
            let phi: Double
            if t < tw {
                phi = 2 * Double.pi * (f0 * t + 0.5 * k * t * t)
            } else {
                let u = t - tw
                phi = phiTw + 2 * Double.pi * (fL * u + 0.5 * k * u * u)
            }
            return amplitude * Float(window(i, n, ramp: Int(0.002 * fs)) * sin(phi))
        }
    }

    /// Yarım-Hann giriş/çıkış rampası (signal-v0 §3.4).
    static func window(_ i: Int, _ n: Int, ramp r: Int) -> Double {
        guard r > 0 else { return 1 }
        if i < r { return 0.5 * (1 - cos(Double.pi * Double(i) / Double(r))) }
        let j = n - 1 - i
        if j < r { return 0.5 * (1 - cos(Double.pi * Double(j) / Double(r))) }
        return 1
    }

    /// Bildirim / alarm sesi için 16 bit PCM mono WAV.
    /// - Parameters:
    ///   - totalSeconds: dosya uzunluğu. Bildirim sesi için < 30 s olmalı (aksi halde varsayılan sese düşer).
    ///   - frameInterval: çerçeve başlangıçları arası süre. 10 s → 25 s'lik dosyada 3 çerçeve, 60 s'lik
    ///     pencerede görev döngüsü ≈ %5 (signal-v0 §5 kulak güvenliği sınırı %12).
    static func wavData(totalSeconds: Double, frameInterval: Double = 10, sampleRate fs: Double = 22_050, gain: Float = 1) -> Data {
        let total = Int(totalSeconds * fs)
        var pcm = [Int16](repeating: 0, count: total)
        let f = frame(sampleRate: fs)
        var start = 0
        let step = Int(frameInterval * fs)
        while start < total {
            for (i, v) in f.enumerated() where start + i < total {
                pcm[start + i] = Int16(max(-1, min(1, v * gain)) * Float(Int16.max))
            }
            start += step
        }
        var data = Data()
        func put32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        func put16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        let byteCount = UInt32(pcm.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); put32(36 + byteCount)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); put32(16); put16(1); put16(1)
        put32(UInt32(fs)); put32(UInt32(fs) * 2); put16(2); put16(16)
        data.append(contentsOf: Array("data".utf8)); put32(byteCount)
        // iOS cihazları küçük uçlu; PCM doğrudan eklenir.
        pcm.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }

    /// `Library/Sounds/<name>` dosyasını yazar ve URL'yi döndürür.
    @discardableResult
    static func writeLibrarySound(named name: String, totalSeconds: Double, frameInterval: Double = 10) throws -> URL {
        let lib = try FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = lib.appendingPathComponent("Sounds", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try wavData(totalSeconds: totalSeconds, frameInterval: frameInterval)
            .write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return url
    }
}
