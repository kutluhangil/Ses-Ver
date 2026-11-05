import Foundation

/// 4-bit Gray kodlama yardımcıları (docs/contracts/signal-v1.md §5).
public enum GrayCode: Sendable {
    public static func encode(_ x: Int) -> Int {
        x ^ (x >> 1)
    }

    public static func decode(_ g: Int) -> Int {
        var x = g
        var mask = x >> 1
        while mask != 0 {
            x ^= mask
            mask >>= 1
        }
        return x
    }
}

/// SignalSpec v1 P1 yükü (24 bit).
public struct PayloadV1: Sendable, Equatable {
    public let id: Int          // 12 bit (0x001..0xFFE)
    public let people: Int      // 3 bit (0: belirtilmedi, 1..6, 7: 7+)
    public let injured: Int     // 1 bit (0/1)
    public let lifeAge: Int     // 4 bit (0..15)
    public let battery: Int     // 2 bit (0..3)
    public let mode: Int        // 2 bit (0..3)

    public init(id: Int, people: Int = 0, injured: Int = 0, lifeAge: Int = 15, battery: Int = 0, mode: Int = 0) {
        precondition(id > 0 && id < 0xFFF, "id 12-bit ve ayrılmış olmamalı")
        precondition(people >= 0 && people < 8, "people 3-bit olmalı")
        precondition(injured >= 0 && injured < 2, "injured 1-bit olmalı")
        precondition(lifeAge >= 0 && lifeAge < 16, "lifeAge 4-bit olmalı")
        precondition(battery >= 0 && battery < 4, "battery 2-bit olmalı")
        precondition(mode >= 0 && mode < 4, "mode 2-bit olmalı")
        self.id = id
        self.people = people
        self.injured = injured
        self.lifeAge = lifeAge
        self.battery = battery
        self.mode = mode
    }

    public var packed24: Int {
        (id << 12) | (people << 9) | (injured << 8) | (lifeAge << 4) | (battery << 2) | mode
    }

    public static func unpack(_ d: Int) -> PayloadV1 {
        PayloadV1(
            id: (d >> 12) & 0xFFF,
            people: (d >> 9) & 7,
            injured: (d >> 8) & 1,
            lifeAge: (d >> 4) & 0xF,
            battery: (d >> 2) & 3,
            mode: d & 3
        )
    }

    public var dataNibbles: [Int] {
        let w = packed24
        return (0..<6).map { (w >> (20 - 4 * $0)) & 0xF }
    }

    public static func fromNibbles(_ nibs: [Int]) -> PayloadV1 {
        precondition(nibs.count >= 6)
        var w = 0
        for x in nibs.prefix(6) {
            w = (w << 4) | (x & 0xF)
        }
        return unpack(w)
    }

    /// RS(10,6) ile kodlanmış 10 nibble
    public var codeword: [Int] {
        RS16.encode(dataNibbles)
    }

    /// CSS frekans kaydırma değerleri (shifts: gray_inv(nibble))
    public var shifts: [Int] {
        codeword.map { GrayCode.decode($0) }
    }
}
