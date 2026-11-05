import Foundation
import BeaconKit

public struct Point3D: Sendable, Equatable {
    public let x: Float
    public let y: Float
    public let z: Float

    public init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }
}

public struct FieldReading: Sendable {
    public let id: UUID
    public let position: Point3D
    public let snrDb: Float
    public let timestamp: Date

    public init(position: Point3D, snrDb: Float, timestamp: Date = Date()) {
        self.id = UUID()
        self.position = position
        self.snrDb = snrDb
        self.timestamp = timestamp
    }
}

public struct HeatmapCell: Sendable, Identifiable {
    public let id: String
    public let x: Float
    public let y: Float
    public let interpolatedSNR: Float

    public init(x: Float, y: Float, interpolatedSNR: Float) {
        self.id = "\(x)_\(y)"
        self.x = x
        self.y = y
        self.interpolatedSNR = interpolatedSNR
    }
}

/// ARKit pozuna bağlı SNR güç haritası ve tepe noktası kestiricisi (BLUEPRINT §3.4.2).
public final class SNRFieldMapper: @unchecked Sendable {
    private let lock = NSLock()
    private var readings: [FieldReading] = []
    public let cellSize: Float // 25 cm = 0.25 m

    public init(cellSize: Float = 0.25) {
        self.cellSize = cellSize
    }

    public func addReading(position: Point3D, snrDb: Float, at date: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        readings.append(FieldReading(position: position, snrDb: snrDb, timestamp: date))
    }

    public var allReadings: [FieldReading] {
        lock.lock()
        defer { lock.unlock() }
        return readings
    }

    /// Ters mesafe ağırlıklı (IDW) 2B zemin ızgarası üretir.
    public func generateHeatmap() -> [HeatmapCell] {
        lock.lock()
        defer { lock.unlock() }
        guard readings.count >= 2 else { return [] }

        var minX = Float.infinity, maxX = -Float.infinity
        var minY = Float.infinity, maxY = -Float.infinity

        for r in readings {
            if r.position.x < minX { minX = r.position.x }
            if r.position.x > maxX { maxX = r.position.x }
            if r.position.y < minY { minY = r.position.y }
            if r.position.y > maxY { maxY = r.position.y }
        }

        let pad: Float = 1.0
        minX -= pad; maxX += pad
        minY -= pad; maxY += pad

        var cells: [HeatmapCell] = []
        var x = minX
        while x <= maxX {
            var y = minY
            while y <= maxY {
                // IDW interpolasyonu (p = 2)
                var weightSum: Float = 0
                var valSum: Float = 0
                for r in readings {
                    let dx = x - r.position.x
                    let dy = y - r.position.y
                    let d = sqrt(dx * dx + dy * dy)
                    if d < 1e-4 {
                        valSum = r.snrDb
                        weightSum = 1.0
                        break
                    }
                    let w = 1.0 / (d * d)
                    weightSum += w
                    valSum += w * r.snrDb
                }
                let interp = weightSum > 0 ? (valSum / weightSum) : 0
                cells.append(HeatmapCell(x: x, y: y, interpolatedSNR: interp))
                y += cellSize
            }
            x += cellSize
        }
        return cells
    }

    /// Tahmini tepe noktası koordinatı (en güçlü sinyal bölgesi).
    public func estimatedPeak() -> Point3D? {
        let heatmap = generateHeatmap()
        guard let best = heatmap.max(by: { $0.interpolatedSNR < $1.interpolatedSNR }) else {
            return readings.max(by: { $0.snrDb < $1.snrDb })?.position
        }
        return Point3D(x: best.x, y: best.y, z: 0)
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        readings.removeAll()
    }
}
