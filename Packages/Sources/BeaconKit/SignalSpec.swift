import Foundation

/// SignalSpec normatif sabitleri (docs/contracts/signal-v1.md ve signal-v0.md).
public struct SignalSpec: Sendable, Equatable {
    public let name: String
    public let sampleRate: Double
    public let fLow: Double
    public let fHigh: Double
    public let nPre: Int
    public let nGap: Int
    public let nSym: Int
    public let alphabet: Int
    public let nSymbols: Int
    public let rampChirp: Int
    public let rampSymbol: Int
    public let amplitude: Float

    public var bandwidth: Double { fHigh - fLow }
    public var tp: Double { Double(nPre) / sampleRate }
    public var ts: Double { Double(nSym) / sampleRate }
    public var chirpRatePre: Double { bandwidth / tp }
    public var chirpRateSym: Double { bandwidth / ts }
    public var shiftStepSamples: Int { nSym / alphabet }

    public var upStarts: (Int, Int, Int) {
        let p = nPre + nGap
        return (0, p, 2 * p)
    }

    public var downStart: Int { 3 * (nPre + nGap) }
    public var dataStart: Int { downStart + nPre }
    public func symbolStart(_ index: Int) -> Int { dataStart + index * nSym }
    public var frameLen: Int { dataStart + nSymbols * nSym }
    public var onLen: Int { 4 * nPre + nSymbols * nSym }

    public static let v1 = SignalSpec(
        name: "v1",
        sampleRate: 48_000,
        fLow: 1_200,
        fHigh: 3_000,
        nPre: 4_608,   // 96 ms
        nGap: 3_840,   // 80 ms
        nSym: 3_072,   // 64 ms
        alphabet: 16,
        nSymbols: 10,  // 6 veri + 4 RS eşlik
        rampChirp: 240,
        rampSymbol: 96,
        amplitude: pow(10.0, -1.0 / 20.0)
    )

    public static let v0 = SignalSpec(
        name: "v0",
        sampleRate: 48_000,
        fLow: 1_800,
        fHigh: 4_200,
        nPre: 5_760,   // 120 ms
        nGap: 3_840,   // 80 ms
        nSym: 3_072,   // 64 ms
        alphabet: 16,
        nSymbols: 8,
        rampChirp: 240,
        rampSymbol: 96,
        amplitude: pow(10.0, -1.0 / 20.0)
    )
}
