import Testing
import Foundation
@testable import BeaconKit

@Suite("BeaconKit Unit Tests")
struct BeaconKitTests {

    @Test("RS16 Encode & Remainder Check")
    func testRS16EncodeAndRemainder() {
        let data = [1, 2, 3, 4, 5, 6]
        let codeword = RS16.encode(data)
        #expect(codeword.count == 10)
        #expect(Array(codeword.prefix(6)) == data)
        #expect(RS16.remainder(codeword) == 0)

        let (ok, corrected, corrections) = RS16.decode(codeword, tMax: 1)
        #expect(ok)
        #expect(corrected == codeword)
        #expect(corrections.isEmpty)
    }

    @Test("RS16 1-Symbol Error Correction (t_max = 1)")
    func testRS16OneErrorCorrection() {
        let data = [7, 8, 9, 10, 11, 12]
        let codeword = RS16.encode(data)

        var corrupted = codeword
        corrupted[3] ^= 5  // 3. konumda hata

        let (ok, corrected, corrections) = RS16.decode(corrupted, tMax: 1)
        #expect(ok)
        #expect(corrected == codeword)
        #expect(corrections.count == 1)
        #expect(corrections[0].0 == 3)
    }

    @Test("RS16 2-Symbol Error Rejection when t_max = 1")
    func testRS16TwoErrorRejection() {
        let data = [2, 4, 6, 8, 10, 12]
        let codeword = RS16.encode(data)

        var corrupted = codeword
        corrupted[1] ^= 3
        corrupted[4] ^= 7

        let (ok, _, _) = RS16.decode(corrupted, tMax: 1)
        // t_max = 1 iken 2 sembol hatası kabul edilmemelidir
        #expect(!ok)
    }

    @Test("RS16 Erasure Decoding")
    func testRS16ErasureDecoding() {
        let data = [3, 1, 4, 1, 5, 9]
        let codeword = RS16.encode(data)

        var corrupted = codeword
        corrupted[2] = 0 // silinme konumu 2
        corrupted[5] = 0 // silinme konumu 5

        let (ok, corrected, _) = RS16.decodeErasures(corrupted, erasures: [2, 5], tMax: 0)
        #expect(ok)
        #expect(corrected == codeword)
    }

    @Test("PayloadV1 Packing and Unpacking")
    func testPayloadV1PackUnpack() {
        let p = PayloadV1(id: 0x7F2, people: 5, injured: 1, lifeAge: 8, battery: 3, mode: 2)
        let packed = p.packed24
        let unpacked = PayloadV1.unpack(packed)
        #expect(unpacked == p)
        #expect(p.dataNibbles.count == 6)
        #expect(p.codeword.count == 10)
        #expect(p.shifts.count == 10)
    }

    @Test("FrameEncoder Sample Generation")
    func testFrameEncoder() {
        let p = PayloadV1(id: 0x1A3, people: 2, injured: 0, lifeAge: 4, battery: 2, mode: 0)
        let samples = FrameEncoder.encode(payload: p, spec: .v1)

        #expect(samples.count == SignalSpec.v1.frameLen)
        #expect(samples.count == 60_672)

        let maxVal = samples.map { abs($0) }.max() ?? 0
        #expect(maxVal > 0.0)
        #expect(maxVal <= 1.0)
    }

    @Test("ScheduleEngine Intervals and Jitter")
    func testScheduleEngine() {
        let start = Date()
        let engine = ScheduleEngine(startTime: start)

        let initialInterval = engine.baseInterval(at: start, batteryPercent: 100)
        #expect(initialInterval == 10.0)

        // 7 saat sonra (6-24h dilimi): 20s
        let t7h = start.addingTimeInterval(7 * 3600)
        #expect(engine.baseInterval(at: t7h, batteryPercent: 100) == 20.0)

        // Pil < %20 iken 2 katı
        #expect(engine.baseInterval(at: t7h, batteryPercent: 15) == 40.0)

        // Jitter alt sınırı 8.6s
        let next = engine.nextInterval(at: start, batteryPercent: 100)
        #expect(next >= 8.6)
    }

    @Test("LifeSignStore LifeAge Bins")
    func testLifeSignStore() {
        let store = LifeSignStore()
        #expect(store.currentLifeAge() == 15) // henüz dokunulmadı

        let now = Date()
        store.registerTouch(at: now)
        #expect(store.currentLifeAge(at: now) == 0) // < 1 dk

        let t5m = now.addingTimeInterval(5.5 * 60)
        #expect(store.currentLifeAge(at: t5m) == 3) // 5-10 dk
    }
}
