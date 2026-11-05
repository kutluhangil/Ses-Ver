import Foundation
import BeaconKit

/// Kurtarıcı için ARKit pozuna bağlı SNR haritası ve konum kestirimi.
public struct SNRReading: Sendable {
    public let timestamp: Date
    public let snr: Float
    public let position: (x: Float, y: Float, z: Float)

    public init(timestamp: Date = Date(), snr: Float, position: (x: Float, y: Float, z: Float)) {
        self.timestamp = timestamp
        self.snr = snr
        self.position = position
    }
}

public final class SNRFieldMapper: Sendable {
    public init() {}
}
