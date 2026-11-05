import Foundation

/// SignalSpec v1 akustik çerçeve sentezleyicisi (docs/contracts/signal-v1.md §3).
public enum FrameEncoder: Sendable {

    /// Verilen yük ve spesifikasyona göre tam çerçeve ses dalgasını üretir.
    public static func encode(payload: PayloadV1, spec: SignalSpec = .v1, outputGain: Float = 1.0) -> [Float] {
        var buffer = [Float](repeating: 0, count: spec.frameLen)
        let effectiveGain = spec.amplitude * max(0.0, min(1.0, outputGain))

        // U1, U2, U3
        let uChirp = generateUpChirp(spec: spec, gain: effectiveGain)
        let (u0, u1, u2) = spec.upStarts
        buffer.replaceSubrange(u0..<(u0 + spec.nPre), with: uChirp)
        buffer.replaceSubrange(u1..<(u1 + spec.nPre), with: uChirp)
        buffer.replaceSubrange(u2..<(u2 + spec.nPre), with: uChirp)

        // D (Down chirp)
        let dChirp = generateDownChirp(spec: spec, gain: effectiveGain)
        buffer.replaceSubrange(spec.downStart..<(spec.downStart + spec.nPre), with: dChirp)

        // Veri sembolleri (CSS)
        let shifts = payload.shifts
        for (i, shift) in shifts.enumerated() {
            let sym = generateCSSSymbol(shift: shift, spec: spec, gain: effectiveGain)
            let start = spec.symbolStart(i)
            buffer.replaceSubrange(start..<(start + spec.nSym), with: sym)
        }

        return buffer
    }

    public static func generateUpChirp(spec: SignalSpec, gain: Float) -> [Float] {
        var out = [Float](repeating: 0, count: spec.nPre)
        let k = spec.chirpRatePre
        let fs = spec.sampleRate
        let fL = spec.fLow
        let ramp = spec.rampChirp

        for n in 0..<spec.nPre {
            let t = Double(n) / fs
            let phi = 2.0 * .pi * (fL * t + 0.5 * k * t * t)
            var w: Double = 1.0
            if n < ramp {
                w = 0.5 * (1.0 - cos(.pi * Double(n) / Double(ramp)))
            } else if n >= spec.nPre - ramp {
                w = 0.5 * (1.0 - cos(.pi * Double(spec.nPre - 1 - n) / Double(ramp)))
            }
            out[n] = gain * Float(w * sin(phi))
        }
        return out
    }

    public static func generateDownChirp(spec: SignalSpec, gain: Float) -> [Float] {
        var out = [Float](repeating: 0, count: spec.nPre)
        let k = spec.chirpRatePre
        let fs = spec.sampleRate
        let fH = spec.fHigh
        let ramp = spec.rampChirp

        for n in 0..<spec.nPre {
            let t = Double(n) / fs
            let phi = 2.0 * .pi * (fH * t - 0.5 * k * t * t)
            var w: Double = 1.0
            if n < ramp {
                w = 0.5 * (1.0 - cos(.pi * Double(n) / Double(ramp)))
            } else if n >= spec.nPre - ramp {
                w = 0.5 * (1.0 - cos(.pi * Double(spec.nPre - 1 - n) / Double(ramp)))
            }
            out[n] = gain * Float(w * sin(phi))
        }
        return out
    }

    public static func generateCSSSymbol(shift: Int, spec: SignalSpec, gain: Float) -> [Float] {
        var out = [Float](repeating: 0, count: spec.nSym)
        let k = spec.chirpRateSym
        let fs = spec.sampleRate
        let fL = spec.fLow
        let b = spec.bandwidth
        let m = Double(spec.alphabet)
        let ts = spec.ts
        let tw = ts * (1.0 - Double(shift) / m)
        let nw = Int(round(tw * fs))
        let ramp = spec.rampSymbol

        // tw anındaki faz
        let phiTw = 2.0 * .pi * ((fL + Double(shift) * b / m) * tw + 0.5 * k * tw * tw)

        for n in 0..<spec.nSym {
            let t = Double(n) / fs
            let phi: Double
            if n < nw || shift == 0 {
                phi = 2.0 * .pi * ((fL + Double(shift) * b / m) * t + 0.5 * k * t * t)
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
            out[n] = gain * Float(w * sin(phi))
        }
        return out
    }
}
