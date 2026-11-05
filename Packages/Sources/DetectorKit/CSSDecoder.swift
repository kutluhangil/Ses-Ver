import Foundation
import Accelerate
import BeaconKit

/// CSS sembol çözücü ve RS(10,6) sendrom doğrulayıcısı (docs/contracts/signal-v1.md §3.3).
public final class CSSDecoder: Sendable {
    public let spec: SignalSpec
    private let templatesI: [[Float]]
    private let templatesQ: [[Float]]

    public init(spec: SignalSpec = .v1) {
        self.spec = spec
        var tmplsI: [[Float]] = []
        var tmplsQ: [[Float]] = []
        let k = spec.chirpRateSym
        let fs = spec.sampleRate
        let fL = spec.fLow
        let b = spec.bandwidth
        let m = Double(spec.alphabet)
        let ts = spec.ts
        let ramp = spec.rampSymbol

        // 16 sembol için analitik karesel (I/Q quadrature) şablonlar
        for s in 0..<spec.alphabet {
            var iArr = [Float](repeating: 0, count: spec.nSym)
            var qArr = [Float](repeating: 0, count: spec.nSym)
            let tw = ts * (1.0 - Double(s) / m)
            let nw = Int(round(tw * fs))
            let phiTw = 2.0 * .pi * ((fL + Double(s) * b / m) * tw + 0.5 * k * tw * tw)

            for n in 0..<spec.nSym {
                let t = Double(n) / fs
                let phi: Double
                if n < nw || s == 0 {
                    phi = 2.0 * .pi * ((fL + Double(s) * b / m) * t + 0.5 * k * t * t)
                } else {
                    let dt = t - tw
                    phi = phiTw + 2.0 * .pi * (fL * dt + 0.5 * k * dt * dt)
                }

                var w: Double = 1.0
                if n < ramp {
                    w = 0.5 * (1.0 - cos(.pi * Double(n) / Double(ramp)))
                } else if n >= spec.nSym - ramp {
                    w = 0.5 * (1.0 - cos(.pi * Double(spec.nSym - 1 - n) / Double(ramp)))
                }
                iArr[n] = Float(w * cos(phi))
                qArr[n] = Float(w * sin(phi))
            }
            tmplsI.append(iArr)
            tmplsQ.append(qArr)
        }
        self.templatesI = tmplsI
        self.templatesQ = tmplsQ
    }

    /// Çerçeve başlangıç noktasından itibaren 10 sembolü çözer.
    public func decodeSymbols(from signal: [Float], frameStart: Int) -> (ok: Bool, payload: PayloadV1?, shifts: [Int]) {
        let dataStart = frameStart + spec.dataStart
        guard signal.count >= dataStart + spec.nSymbols * spec.nSym else {
            return (false, nil, [])
        }

        var detectedShifts: [Int] = []

        for i in 0..<spec.nSymbols {
            let symStart = dataStart + i * spec.nSym
            let symSamples = Array(signal[symStart..<(symStart + spec.nSym)])

            var bestShift = 0
            var maxEnergy: Float = -1.0

            for s in 0..<spec.alphabet {
                // I/Q analitik korelasyon enerjisi (|⟨r, e^{jφ}⟩|²)
                var dotI: Float = 0
                var dotQ: Float = 0
                vDSP_dotpr(symSamples, 1, templatesI[s], 1, &dotI, vDSP_Length(spec.nSym))
                vDSP_dotpr(symSamples, 1, templatesQ[s], 1, &dotQ, vDSP_Length(spec.nSym))
                let energy = dotI * dotI + dotQ * dotQ
                if energy > maxEnergy {
                    maxEnergy = energy
                    bestShift = s
                }
            }
            detectedShifts.append(bestShift)
        }

        let (ok, payload) = FrameDecoder.decode(shifts: detectedShifts, tMax: 1)
        return (ok, payload, detectedShifts)
    }
}
