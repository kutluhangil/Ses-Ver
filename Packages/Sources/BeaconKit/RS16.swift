import Foundation

/// Kısaltılmış Reed–Solomon RS(10,6), GF(16) (docs/contracts/signal-v1.md §5).
/// Python rs16.py referansı ile bit-bit uyumludur.
public enum RS16: Sendable {
    public static let n = 10
    public static let k = 6
    public static let npar = 4
    public static let prim = 0x13

    public static let exp: [Int] = {
        var e = [Int](repeating: 0, count: 30)
        var v = 1
        for i in 0..<15 {
            e[i] = v
            v <<= 1
            if (v & 0x10) != 0 {
                v ^= prim
            }
        }
        for i in 15..<30 {
            e[i] = e[i - 15]
        }
        return e
    }()

    public static let log: [Int] = {
        var l = [Int](repeating: 0, count: 16)
        for i in 0..<15 {
            l[exp[i]] = i
        }
        return l
    }()

    public static func gfMul(_ a: Int, _ b: Int) -> Int {
        if a == 0 || b == 0 { return 0 }
        return exp[log[a] + log[b]]
    }

    public static let gen: [Int] = {
        var g = [1]
        for j in 1...npar {
            var next = [Int](repeating: 0, count: g.count + 1)
            let root = exp[j]
            for (idx, coeff) in g.enumerated() {
                next[idx] ^= coeff
                next[idx + 1] ^= gfMul(coeff, root)
            }
            g = next
        }
        return g
    }()

    private static func polyMod(_ num: [Int]) -> [Int] {
        var r = num
        for i in 0..<(r.count - npar) {
            let c = r[i]
            if c != 0 {
                for j in 1...npar {
                    r[i + j] ^= gfMul(gen[j], c)
                }
            }
        }
        return Array(r.suffix(npar))
    }

    private static func pack4(_ nibs: [Int]) -> Int {
        var v = 0
        for x in nibs {
            v = (v << 4) | (x & 0xF)
        }
        return v
    }

    /// REM[i][v]: i. konumdaki (derece N-1-i) v değerinin kalanı (16-bit).
    public static let remTable: [[Int]] = {
        var table = [[Int]]()
        for i in 0..<n {
            var row = [Int]()
            for v in 0..<16 {
                var poly = [Int](repeating: 0, count: n)
                poly[i] = v
                row.append(pack4(polyMod(poly)))
            }
            table.append(row)
        }
        return table
    }()

    public static func remainder(_ word: [Int]) -> Int {
        precondition(word.count == n, "10 nibble gerekli")
        var s = 0
        for i in 0..<n {
            s ^= remTable[i][word[i]]
        }
        return s
    }

    public static func encode(_ data: [Int]) -> [Int] {
        precondition(data.count == k, "6 nibble veri gerekli")
        var s = 0
        for i in 0..<k {
            s ^= remTable[i][data[i]]
        }
        var par = [Int](repeating: 0, count: npar)
        for j in 0..<npar {
            par[j] = (s >> (4 * (npar - 1 - j))) & 0xF
        }
        return data + par
    }

    /// Hata deseni tablosu: Kalan -> Hata konum ve değerleri (Ağırlık 1 ve 2).
    public static let errTable: [Int: [(Int, Int)]] = {
        var table = [Int: [(Int, Int)]]()
        // Ağırlık 1
        for i in 0..<n {
            for v in 1..<16 {
                let key = remTable[i][v]
                table[key] = [(i, v)]
            }
        }
        // Ağırlık 2
        for i in 0..<n {
            for j in (i + 1)..<n {
                for v in 1..<16 {
                    for u in 1..<16 {
                        let key = remTable[i][v] ^ remTable[j][u]
                        if table[key] == nil {
                            table[key] = [(i, v), (j, u)]
                        }
                    }
                }
            }
        }
        return table
    }()

    /// Kod çözücü. ZORUNLU: tMax = 1 normatiftir.
    public static func decode(_ word: [Int], tMax: Int = 1) -> (ok: Bool, corrected: [Int], corrections: [(Int, Int)]) {
        precondition(word.count == n, "10 nibble gerekli")
        let s = remainder(word)
        if s == 0 {
            return (true, word, [])
        }
        guard let pat = errTable[s], pat.count <= tMax else {
            return (false, word, [])
        }
        var out = word
        for (i, v) in pat {
            out[i] ^= v
        }
        return (true, out, pat)
    }

    /// Silinme (erasure) çözücü. 2t + e <= 4.
    public static func decodeErasures(
        _ word: [Int],
        erasures: [Int],
        tMax: Int = 0
    ) -> (ok: Bool, corrected: [Int], corrections: [(Int, Int)]) {
        precondition(word.count == n, "10 nibble gerekli")
        let erSet = Array(Set(erasures)).sorted()
        let eCnt = erSet.count
        if 2 * tMax + eCnt > npar {
            return (false, word, [])
        }

        let sOrig = remainder(word)
        if sOrig == 0 && eCnt == 0 {
            return (true, word, [])
        }
        if eCnt == 0 {
            return decode(word, tMax: tMax)
        }

        if eCnt == 1 {
            let p0 = erSet[0]
            for v0 in 0..<16 {
                let sRem = sOrig ^ remTable[p0][v0]
                if sRem == 0 {
                    var out = word
                    out[p0] ^= v0
                    return (true, out, [(p0, v0)])
                }
                if tMax >= 1, let pat = errTable[sRem], pat.count <= tMax, pat.allSatisfy({ $0.0 != p0 }) {
                    var out = word
                    out[p0] ^= v0
                    for (pos, val) in pat {
                        out[pos] ^= val
                    }
                    return (true, out, [(p0, v0)] + pat)
                }
            }
            return (false, word, [])
        }

        if eCnt == 2 {
            let p0 = erSet[0]
            let p1 = erSet[1]
            for v0 in 0..<16 {
                let sPartial = sOrig ^ remTable[p0][v0]
                for v1 in 0..<16 {
                    let sRem = sPartial ^ remTable[p1][v1]
                    if sRem == 0 {
                        var out = word
                        out[p0] ^= v0
                        out[p1] ^= v1
                        var corr = [(Int, Int)]()
                        if v0 != 0 { corr.append((p0, v0)) }
                        if v1 != 0 { corr.append((p1, v1)) }
                        return (true, out, corr)
                    }
                    if tMax >= 1, let pat = errTable[sRem], pat.count <= tMax, pat.allSatisfy({ $0.0 != p0 && $0.0 != p1 }) {
                        var out = word
                        out[p0] ^= v0
                        out[p1] ^= v1
                        for (pos, val) in pat {
                            out[pos] ^= val
                        }
                        var corr = [(Int, Int)]()
                        if v0 != 0 { corr.append((p0, v0)) }
                        if v1 != 0 { corr.append((p1, v1)) }
                        return (true, out, corr + pat)
                    }
                }
            }
            return (false, word, [])
        }

        return (false, word, [])
    }
}
