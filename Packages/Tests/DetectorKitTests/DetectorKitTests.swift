import Testing
import Foundation
@testable import DetectorKit
@testable import BeaconKit

@Suite("DetectorKit Unit Tests")
struct DetectorKitTests {

    @Test("FrameDecoder Decodes Clean Shifts")
    func testFrameDecoderClean() {
        let p = PayloadV1(id: 0x3E1, people: 2, injured: 0, lifeAge: 1, battery: 2, mode: 0)
        let shifts = p.shifts

        let (ok, decoded) = FrameDecoder.decode(shifts: shifts, tMax: 1)
        #expect(ok)
        #expect(decoded == p)
    }

    @Test("FrameDecoder Corrects Single Symbol Error")
    func testFrameDecoderCorrection() {
        let p = PayloadV1(id: 0x3E1, people: 2, injured: 0, lifeAge: 1, battery: 2, mode: 0)
        var shifts = p.shifts

        // 1 sembolü boz
        shifts[2] = (shifts[2] + 3) % 16

        let (ok, decoded) = FrameDecoder.decode(shifts: shifts, tMax: 1)
        #expect(ok)
        #expect(decoded == p)
    }
}
