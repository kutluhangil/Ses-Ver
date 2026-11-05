import Foundation
import Accelerate
import BeaconKit

/// vDSP destekli eşlenik filtre bankası (docs/contracts/signal-v1.md §7).
public final class MatchedFilterBank: Sendable {
    public let spec: SignalSpec
    private let upTemplate: [Float]

    public init(spec: SignalSpec = .v1) {
        self.spec = spec
        // Yükselen chirp şablonu (zamanda ters çevrilmiş)
        let chirp = FrameEncoder.generateUpChirp(spec: spec, gain: 1.0)
        self.upTemplate = Array(chirp.reversed())
    }

    /// Giriş ses tamponu üzerinde eşlenik filtre korelasyon gücünü P[n] = |y[n]|^2 hesaplar.
    public func correlatePower(input: [Float]) -> [Float] {
        guard input.count >= upTemplate.count else { return [] }
        let outCount = input.count - upTemplate.count + 1
        var result = [Float](repeating: 0, count: outCount)

        input.withUnsafeBufferPointer { inPtr in
            upTemplate.withUnsafeBufferPointer { tmplPtr in
                result.withUnsafeMutableBufferPointer { outPtr in
                    vDSP_conv(
                        inPtr.baseAddress!, 1,
                        tmplPtr.baseAddress!, 1,
                        outPtr.baseAddress!, 1,
                        vDSP_Length(outCount),
                        vDSP_Length(upTemplate.count)
                    )
                }
            }
        }

        // P[n] = y[n]^2
        var power = [Float](repeating: 0, count: outCount)
        vDSP_vsq(result, 1, &power, 1, vDSP_Length(outCount))
        return power
    }
}
