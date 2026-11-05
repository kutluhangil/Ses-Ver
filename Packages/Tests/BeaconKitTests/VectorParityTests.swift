import Testing
import Foundation
@testable import BeaconKit

@Suite("SignalSpec v1 Vector Parity Tests")
struct VectorParityTests {

    struct VectorMeta: Decodable {
        let name: String
        let data24_hex: String
        let nibbles: [Int]
        let shifts: [Int]
        struct FieldsMeta: Decodable {
            let id: Int
            let people: Int
            let injured: Int
            let lifeAge: Int
            let battery: Int
            let mode: Int
        }
        let fields: FieldsMeta
        struct SamplesMeta: Decodable {
            let file: String
            let count: Int
            let first8: [Float]
        }
        let samples: SamplesMeta
    }

    struct IndexMeta: Decodable {
        struct Item: Decodable {
            let name: String
            let json: String
            let f32: String
        }
        let vectors: [Item]
    }

    @Test("Verify Swift Parity with Python Test Vectors")
    func testParityWithPythonVectors() throws {
        let vectorsDir = URL(fileURLWithPath: "/Volumes/ProjectClaude/Ses-Ver/research/signal/vectors/v1")
        let indexUrl = vectorsDir.appendingPathComponent("index.json")

        guard FileManager.default.fileExists(atPath: indexUrl.path) else {
            print("Vektör dizini bulunamadı: \(indexUrl.path)")
            return
        }

        let indexData = try Data(contentsOf: indexUrl)
        let index = try JSONDecoder().decode(IndexMeta.self, from: indexData)

        #expect(index.vectors.count == 55)

        for item in index.vectors {
            let jsonUrl = vectorsDir.appendingPathComponent(item.json)
            let f32Url = vectorsDir.appendingPathComponent(item.f32)

            let jsonData = try Data(contentsOf: jsonUrl)
            let meta = try JSONDecoder().decode(VectorMeta.self, from: jsonData)

            let payload = PayloadV1(
                id: meta.fields.id,
                people: meta.fields.people,
                injured: meta.fields.injured,
                lifeAge: meta.fields.lifeAge,
                battery: meta.fields.battery,
                mode: meta.fields.mode
            )

            // 1. Packed 24-bit paritesi
            let expectedData24 = Int(meta.data24_hex.dropFirst(2), radix: 16) ?? 0
            #expect(payload.packed24 == expectedData24, "Packed 24 uyumsuz: \(meta.name)")

            // 2. RS Codeword paritesi
            #expect(payload.codeword == meta.nibbles, "RS nibble uyumsuz: \(meta.name)")

            // 3. CSS shifts paritesi
            #expect(payload.shifts == meta.shifts, "CSS shifts uyumsuz: \(meta.name)")

            // 4. Dalga boyu ve örnek karşılaştırması
            let samples = FrameEncoder.encode(payload: payload, spec: .v1)
            #expect(samples.count == meta.samples.count)

            let f32Data = try Data(contentsOf: f32Url)
            let expectedSamples = f32Data.withUnsafeBytes { ptr in
                Array(ptr.bindMemory(to: Float.self))
            }

            #expect(samples.count == expectedSamples.count)

            // İlk 8 örnek
            for i in 0..<8 {
                let diff = abs(samples[i] - meta.samples.first8[i])
                #expect(diff < 1e-4, "İlk 8 örnek uyumsuz \(meta.name) @ \(i): \(diff)")
            }

            // Tüm örnekler max sapma < 1e-3 (floating-point trigonometri farkı toleransı)
            var maxDiff: Float = 0.0
            for i in 0..<samples.count {
                let diff = abs(samples[i] - expectedSamples[i])
                if diff > maxDiff { maxDiff = diff }
            }
            #expect(maxDiff < 1e-3, "Maksimum dalga biçimi sapması aşıldı \(meta.name): \(maxDiff)")
        }
    }
}
