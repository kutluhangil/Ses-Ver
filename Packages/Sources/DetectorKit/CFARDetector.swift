import Foundation
import Accelerate
import BeaconKit

public struct DetectionCandidate: Sendable {
    public let sampleIndex: Int
    public let metricC: Float
    public let peakValues: [Float]
    public let snrEstimateDb: Float
}

/// Uyarlamalı gürültü tabanı (CFAR) ve 3 tepe birleştirme detektörü (BLUEPRINT §3.4.1).
public final class CFARDetector: Sendable {
    public let spec: SignalSpec
    public let etaC: Float
    public let guardSamples: Int
    public let windowSamples: Int

    public init(spec: SignalSpec = .v1, etaC: Float = 22.0, guardSamples: Int = 64, windowSamples: Int = 512) {
        self.spec = spec
        self.etaC = etaC
        self.guardSamples = guardSamples
        self.windowSamples = windowSamples
    }

    /// Normalize güç eğrisinden 3 tepe birleştirilmiş tepe adaylarını döner.
    public func detect(power: [Float]) -> [DetectionCandidate] {
        guard power.count > 2 * (guardSamples + windowSamples) else { return [] }
        let n = power.count
        var pNorm = [Float](repeating: 0, count: n)

        // Basitleştirilmiş kayan ortalama CFAR
        let halfWin = windowSamples / 2
        var runningSum: Float = 0
        for i in 0..<min(n, windowSamples) {
            runningSum += power[i]
        }

        for i in 0..<n {
            let leftOut = i - halfWin - 1
            let rightIn = i + halfWin
            if leftOut >= 0 { runningSum -= power[leftOut] }
            if rightIn < n { runningSum += power[rightIn] }

            let avg = max(1e-12, runningSum / Float(windowSamples))
            pNorm[i] = power[i] / avg
        }

        // 3 tepe birleştirme: U1, U2, U3 aralığı spec.upSpacing = 4608 + 3840 = 8448
        let spacing = spec.nPre + spec.nGap
        var candidates: [DetectionCandidate] = []

        let maxCheckIndex = n - 2 * spacing
        if maxCheckIndex <= 0 { return [] }

        var i = 0
        while i < maxCheckIndex {
            let p1 = pNorm[i]
            let p2 = pNorm[i + spacing]
            let p3 = pNorm[i + 2 * spacing]
            let c = p1 + p2 + p3

            if c >= etaC && p1 > 1.5 && p2 > 1.5 && p3 > 1.5 {
                let snr = 10.0 * log10(max(1.0, c / 3.0))
                candidates.append(DetectionCandidate(
                    sampleIndex: i,
                    metricC: c,
                    peakValues: [p1, p2, p3],
                    snrEstimateDb: snr
                ))
                i += spacing / 2 // NMS atlaması
            } else {
                i += 1
            }
        }

        return candidates
    }
}
