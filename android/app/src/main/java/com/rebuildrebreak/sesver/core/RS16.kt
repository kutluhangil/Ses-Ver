package com.rebuildrebreak.sesver.core

/**
 * Kısaltılmış Reed–Solomon RS(10,6), GF(16) (docs/contracts/signal-v1.md §5).
 * Python rs16.py ve Swift RS16.swift ile bit-bit uyumludur.
 */
object RS16 {
    const val N = 10
    const val K = 6
    const val NPAR = 4
    const val PRIM = 0x13

    val exp = IntArray(30).apply {
        var v = 1
        for (i in 0 until 15) {
            this[i] = v
            v = v shl 1
            if ((v and 0x10) != 0) {
                v = v xor PRIM
            }
        }
        for (i in 15 until 30) {
            this[i] = this[i - 15]
        }
    }

    val log = IntArray(16).apply {
        for (i in 0 until 15) {
            this[exp[i]] = i
        }
    }

    fun gfMul(a: Int, b: Int): Int {
        if (a == 0 || b == 0) return 0
        return exp[log[a] + log[b]]
    }

    val gen = run {
        var g = intArrayOf(1)
        for (j in 1..NPAR) {
            val next = IntArray(g.size + 1)
            val root = exp[j]
            for ((idx, coeff) in g.withIndex()) {
                next[idx] = next[idx] xor coeff
                next[idx + 1] = next[idx + 1] xor gfMul(coeff, root)
            }
            g = next
        }
        g
    }

    private fun polyMod(num: IntArray): IntArray {
        val r = num.copyOf()
        for (i in 0 until (r.size - NPAR)) {
            val c = r[i]
            if (c != 0) {
                for (j in 1..NPAR) {
                    r[i + j] = r[i + j] xor gfMul(gen[j], c)
                }
            }
        }
        return r.takeLast(NPAR).toIntArray()
    }

    private fun pack4(nibs: IntArray): Int {
        var v = 0
        for (x in nibs) {
            v = (v shl 4) or (x and 0xF)
        }
        return v
    }

    val remTable: Array<IntArray> = Array(N) { i ->
        IntArray(16) { v ->
            val poly = IntArray(N)
            poly[i] = v
            pack4(polyMod(poly))
        }
    }

    fun remainder(word: IntArray): Int {
        require(word.size == N) { "10 nibble gerekli" }
        var s = 0
        for (i in 0 until N) {
            s = s xor remTable[i][word[i]]
        }
        return s
    }

    fun encode(data: IntArray): IntArray {
        require(data.size == K) { "6 nibble veri gerekli" }
        var s = 0
        for (i in 0 until K) {
            s = s xor remTable[i][data[i]]
        }
        val par = IntArray(NPAR)
        for (j in 0 until NPAR) {
            par[j] = (s shr (4 * (NPAR - 1 - j))) and 0xF
        }
        return data + par
    }

    data class ErrorCorrection(val position: Int, val value: Int)
    data class DecodeResult(val ok: Boolean, val corrected: IntArray, val corrections: List<ErrorCorrection>)

    val errTable: Map<Int, List<ErrorCorrection>> = run {
        val table = mutableMapOf<Int, List<ErrorCorrection>>()
        // Ağırlık 1
        for (i in 0 until N) {
            for (v in 1 until 16) {
                val key = remTable[i][v]
                table[key] = listOf(ErrorCorrection(i, v))
            }
        }
        // Ağırlık 2
        for (i in 0 until N) {
            for (j in (i + 1) until N) {
                for (v in 1 until 16) {
                    for (u in 1 until 16) {
                        val key = remTable[i][v] xor remTable[j][u]
                        if (!table.containsKey(key)) {
                            table[key] = listOf(ErrorCorrection(i, v), ErrorCorrection(j, u))
                        }
                    }
                }
            }
        }
        table
    }

    fun decode(word: IntArray, tMax: Int = 1): DecodeResult {
        require(word.size == N) { "10 nibble gerekli" }
        val s = remainder(word)
        if (s == 0) {
            return DecodeResult(true, word.copyOf(), emptyList())
        }
        val pat = errTable[s]
        if (pat == null || pat.size > tMax) {
            return DecodeResult(false, word.copyOf(), emptyList())
        }
        val out = word.copyOf()
        for (c in pat) {
            out[c.position] = out[c.position] xor c.value
        }
        return DecodeResult(true, out, pat)
    }

    fun decodeErasures(word: IntArray, erasures: IntArray, tMax: Int = 0): DecodeResult {
        require(word.size == N) { "10 nibble gerekli" }
        val erSet = erasures.distinct().sorted()
        val eCnt = erSet.size
        if (2 * tMax + eCnt > NPAR) {
            return DecodeResult(false, word.copyOf(), emptyList())
        }

        val sOrig = remainder(word)
        if (sOrig == 0 && eCnt == 0) {
            return DecodeResult(true, word.copyOf(), emptyList())
        }
        if (eCnt == 0) {
            return decode(word, tMax)
        }

        if (eCnt == 1) {
            val p0 = erSet[0]
            for (v0 in 0 until 16) {
                val sRem = sOrig xor remTable[p0][v0]
                if (sRem == 0) {
                    val out = word.copyOf()
                    out[p0] = out[p0] xor v0
                    return DecodeResult(true, out, listOf(ErrorCorrection(p0, v0)))
                }
                if (tMax >= 1) {
                    val pat = errTable[sRem]
                    if (pat != null && pat.size <= tMax && pat.all { it.position != p0 }) {
                        val out = word.copyOf()
                        out[p0] = out[p0] xor v0
                        for (c in pat) {
                            out[c.position] = out[c.position] xor c.value
                        }
                        return DecodeResult(true, out, listOf(ErrorCorrection(p0, v0)) + pat)
                    }
                }
            }
            return DecodeResult(false, word.copyOf(), emptyList())
        }

        if (eCnt == 2) {
            val p0 = erSet[0]
            val p1 = erSet[1]
            for (v0 in 0 until 16) {
                val sPartial = sOrig xor remTable[p0][v0]
                for (v1 in 0 until 16) {
                    val sRem = sPartial xor remTable[p1][v1]
                    if (sRem == 0) {
                        val out = word.copyOf()
                        out[p0] = out[p0] xor v0
                        out[p1] = out[p1] xor v1
                        val corr = mutableListOf<ErrorCorrection>()
                        if (v0 != 0) corr.add(ErrorCorrection(p0, v0))
                        if (v1 != 0) corr.add(ErrorCorrection(p1, v1))
                        return DecodeResult(true, out, corr)
                    }
                    if (tMax >= 1) {
                        val pat = errTable[sRem]
                        if (pat != null && pat.size <= tMax && pat.all { it.position != p0 && it.position != p1 }) {
                            val out = word.copyOf()
                            out[p0] = out[p0] xor v0
                            out[p1] = out[p1] xor v1
                            val corr = mutableListOf<ErrorCorrection>()
                            if (v0 != 0) corr.add(ErrorCorrection(p0, v0))
                            if (v1 != 0) corr.add(ErrorCorrection(p1, v1))
                            return DecodeResult(true, out, corr + pat)
                        }
                    }
                }
            }
            return DecodeResult(false, word.copyOf(), emptyList())
        }

        return DecodeResult(false, word.copyOf(), emptyList())
    }
}
