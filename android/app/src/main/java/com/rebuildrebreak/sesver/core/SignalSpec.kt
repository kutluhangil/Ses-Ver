package com.rebuildrebreak.sesver.core

import kotlin.math.pow

data class SignalSpec(
    val name: String,
    val sampleRate: Double,
    val fLow: Double,
    val fHigh: Double,
    val nPre: Int,
    val nGap: Int,
    val nSym: Int,
    val alphabet: Int,
    val nSymbols: Int,
    val rampChirp: Int,
    val rampSymbol: Int,
    val amplitude: Float
) {
    val bandwidth: Double get() = fHigh - fLow
    val tp: Double get() = nPre.toDouble() / sampleRate
    val ts: Double get() = nSym.toDouble() / sampleRate
    val chirpRatePre: Double get() = bandwidth / tp
    val chirpRateSym: Double get() = bandwidth / ts
    val shiftStepSamples: Int get() = nSym / alphabet

    val upStarts: Triple<Int, Int, Int>
        get() {
            val p = nPre + nGap
            return Triple(0, p, 2 * p)
        }

    val downStart: Int get() = 3 * (nPre + nGap)
    val dataStart: Int get() = downStart + nPre
    fun symbolStart(index: Int): Int = dataStart + index * nSym
    val frameLen: Int get() = dataStart + nSymbols * nSym
    val onLen: Int get() = 4 * nPre + nSymbols * nSym

    companion object {
        val V1 = SignalSpec(
            name = "v1",
            sampleRate = 48000.0,
            fLow = 1200.0,
            fHigh = 3000.0,
            nPre = 4608,   // 96 ms
            nGap = 3840,   // 80 ms
            nSym = 3072,   // 64 ms
            alphabet = 16,
            nSymbols = 10,  // 6 veri + 4 RS eşlik
            rampChirp = 240,
            rampSymbol = 96,
            amplitude = 10.0.pow(-1.0 / 20.0).toFloat()
        )

        val V0 = SignalSpec(
            name = "v0",
            sampleRate = 48000.0,
            fLow = 1800.0,
            fHigh = 4200.0,
            nPre = 5760,   // 120 ms
            nGap = 3840,   // 80 ms
            nSym = 3072,   // 64 ms
            alphabet = 16,
            nSymbols = 8,
            rampChirp = 240,
            rampSymbol = 96,
            amplitude = 10.0.pow(-1.0 / 20.0).toFloat()
        )
    }
}
