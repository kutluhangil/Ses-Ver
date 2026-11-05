package com.rebuildrebreak.sesver.core

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.round
import kotlin.math.sin

/**
 * SignalSpec v1 akustik çerçeve sentezleyicisi (docs/contracts/signal-v1.md §3).
 */
object FrameEncoder {

    fun encode(payload: PayloadV1, spec: SignalSpec = SignalSpec.V1, outputGain: Float = 1.0f): FloatArray {
        val buffer = FloatArray(spec.frameLen)
        val effectiveGain = spec.amplitude * outputGain.coerceIn(0.0f, 1.0f)

        // U1, U2, U3
        val uChirp = generateUpChirp(spec, effectiveGain)
        val (u0, u1, u2) = spec.upStarts
        System.arraycopy(uChirp, 0, buffer, u0, spec.nPre)
        System.arraycopy(uChirp, 0, buffer, u1, spec.nPre)
        System.arraycopy(uChirp, 0, buffer, u2, spec.nPre)

        // D (Down chirp)
        val dChirp = generateDownChirp(spec, effectiveGain)
        System.arraycopy(dChirp, 0, buffer, spec.downStart, spec.nPre)

        // Veri sembolleri (CSS)
        val shifts = payload.shifts
        for (i in shifts.indices) {
            val sym = generateCSSSymbol(shifts[i], spec, effectiveGain)
            val start = spec.symbolStart(i)
            System.arraycopy(sym, 0, buffer, start, spec.nSym)
        }

        return buffer
    }

    fun generateUpChirp(spec: SignalSpec, gain: Float): FloatArray {
        val out = FloatArray(spec.nPre)
        val k = spec.chirpRatePre
        val fs = spec.sampleRate
        val fL = spec.fLow
        val ramp = spec.rampChirp

        for (n in 0 until spec.nPre) {
            val t = n.toDouble() / fs
            val phi = 2.0 * PI * (fL * t + 0.5 * k * t * t)
            var w = 1.0
            if (n < ramp) {
                w = 0.5 * (1.0 - cos(PI * n.toDouble() / ramp.toDouble()))
            } else if (n >= spec.nPre - ramp) {
                w = 0.5 * (1.0 - cos(PI * (spec.nPre - 1 - n).toDouble() / ramp.toDouble()))
            }
            out[n] = gain * (w * sin(phi)).toFloat()
        }
        return out
    }

    fun generateDownChirp(spec: SignalSpec, gain: Float): FloatArray {
        val out = FloatArray(spec.nPre)
        val k = spec.chirpRatePre
        val fs = spec.sampleRate
        val fH = spec.fHigh
        val ramp = spec.rampChirp

        for (n in 0 until spec.nPre) {
            val t = n.toDouble() / fs
            val phi = 2.0 * PI * (fH * t - 0.5 * k * t * t)
            var w = 1.0
            if (n < ramp) {
                w = 0.5 * (1.0 - cos(PI * n.toDouble() / ramp.toDouble()))
            } else if (n >= spec.nPre - ramp) {
                w = 0.5 * (1.0 - cos(PI * (spec.nPre - 1 - n).toDouble() / ramp.toDouble()))
            }
            out[n] = gain * (w * sin(phi)).toFloat()
        }
        return out
    }

    fun generateCSSSymbol(shift: Int, spec: SignalSpec, gain: Float): FloatArray {
        val out = FloatArray(spec.nSym)
        val k = spec.chirpRateSym
        val fs = spec.sampleRate
        val fL = spec.fLow
        val b = spec.bandwidth
        val m = spec.alphabet.toDouble()
        val ts = spec.ts
        val tw = ts * (1.0 - shift.toDouble() / m)
        val nw = round(tw * fs).toInt()
        val ramp = spec.rampSymbol

        // tw anındaki faz
        val phiTw = 2.0 * PI * ((fL + shift.toDouble() * b / m) * tw + 0.5 * k * tw * tw)

        for (n in 0 until spec.nSym) {
            val t = n.toDouble() / fs
            val phi = if (n < nw || shift == 0) {
                2.0 * PI * ((fL + shift.toDouble() * b / m) * t + 0.5 * k * t * t)
            } else {
                val dt = t - tw
                phiTw + 2.0 * PI * (fL * dt + 0.5 * k * dt * dt)
            }

            var w = 1.0
            if (n < ramp) {
                w = 0.5 * (1.0 - cos(PI * n.toDouble() / ramp.toDouble()))
            } else if (n >= spec.nSym - ramp) {
                w = 0.5 * (1.0 - cos(PI * (spec.nSym - 1 - n).toDouble() / ramp.toDouble()))
            }
            out[n] = gain * (w * sin(phi)).toFloat()
        }
        return out
    }
}
