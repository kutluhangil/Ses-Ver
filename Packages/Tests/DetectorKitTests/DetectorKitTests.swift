import Testing
import Foundation
@testable import DetectorKit
@testable import BeaconKit
@testable import LocalizationKit

@Suite("DetectorKit and LocalizationKit Tests")
struct DetectorKitTests {

    @Test("MatchedFilterBank Generates Peaks for Signal")
    func testMatchedFilterBank() {
        let payload = PayloadV1(id: 0x7F2, people: 2, injured: 0, lifeAge: 3, battery: 2, mode: 0)
        let signal = FrameEncoder.encode(payload: payload, spec: .v1)

        let bank = MatchedFilterBank(spec: .v1)
        let power = bank.correlatePower(input: signal)

        #expect(!power.isEmpty)
        let maxPower = power.max() ?? 0
        #expect(maxPower > 10.0) // Eşlenik filtre kazancı ile tepe gücü belirgin
    }

    @Test("CSSDecoder End-to-End Frame Decoding")
    func testCSSDecoderEndToEnd() {
        let payload = PayloadV1(id: 0x5A1, people: 3, injured: 1, lifeAge: 2, battery: 3, mode: 0)
        let signal = FrameEncoder.encode(payload: payload, spec: .v1)

        let decoder = CSSDecoder(spec: .v1)
        let (ok, decodedPayload, shifts) = decoder.decodeSymbols(from: signal, frameStart: 0)

        #expect(ok)
        #expect(shifts == payload.shifts)
        #expect(decodedPayload == payload)
    }

    @Test("BeaconTracker Two-Frame Verification Rule")
    func testBeaconTrackerTwoFrameRule() {
        let tracker = BeaconTracker()
        let payload = PayloadV1(id: 0x3BC, people: 1, injured: 0, lifeAge: 0, battery: 2, mode: 0)

        // 1. Çerçeve: doğrulanmamış
        let b1 = tracker.registerFrame(payload: payload, snr: 12.5)
        #expect(b1.frameCount == 1)
        #expect(!b1.isVerifiedTwoFrames)
        #expect(tracker.verifiedBeacons.isEmpty)
        #expect(tracker.allBeacons.count == 1)

        // 2. Çerçeve: doğrulanmış
        let b2 = tracker.registerFrame(payload: payload, snr: 14.0)
        #expect(b2.frameCount == 2)
        #expect(b2.isVerifiedTwoFrames)
        #expect(tracker.verifiedBeacons.count == 1)
        #expect(tracker.verifiedBeacons[0].id == 0x3BC)
    }

    @Test("SNRFieldMapper IDW Heatmap and Peak Detection")
    func testSNRFieldMapper() {
        let mapper = SNRFieldMapper(cellSize: 0.5)

        // 3 okuma ekle, en güçlüsü (2.0, 3.0) noktasında
        mapper.addReading(position: Point3D(x: 0, y: 0, z: 0), snrDb: 6.0)
        mapper.addReading(position: Point3D(x: 2.0, y: 3.0, z: 0), snrDb: 24.0)
        mapper.addReading(position: Point3D(x: 4.0, y: 0, z: 0), snrDb: 4.0)

        let heatmap = mapper.generateHeatmap()
        #expect(heatmap.count > 10)

        let peak = mapper.estimatedPeak()
        #expect(peak != nil)
        #expect(abs(peak!.x - 2.0) <= 0.5)
        #expect(abs(peak!.y - 3.0) <= 0.5)
    }
}
