package com.rebuildrebreak.sesver

import com.rebuildrebreak.sesver.core.PayloadV1
import com.rebuildrebreak.sesver.core.ScheduleEngine
import com.rebuildrebreak.sesver.core.SignalSpec
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SignalSpecTest {

    @Test
    fun testPhysicalConstantsV1() {
        val spec = SignalSpec.V1
        assertEquals(48000.0, spec.sampleRate, 1e-6)
        assertEquals(1200.0, spec.fLow, 1e-6)
        assertEquals(3000.0, spec.fHigh, 1e-6)
        assertEquals(1800.0, spec.bandwidth, 1e-6)
        assertEquals(4608, spec.nPre)
        assertEquals(3840, spec.nGap)
        assertEquals(3072, spec.nSym)
        assertEquals(16, spec.alphabet)
        assertEquals(10, spec.nSymbols)
        assertEquals(60672, spec.frameLen)
        assertEquals(49152, spec.onLen)
    }

    @Test
    fun testPayloadPackingAndUnpacking() {
        val original = PayloadV1(id = 0x5A1, people = 3, injured = 1, lifeAge = 2, battery = 3, mode = 0)
        val packed = original.packed24
        val unpacked = PayloadV1.unpack(packed)
        assertEquals(original, unpacked)
        assertEquals(6, original.dataNibbles.size)
        assertEquals(10, original.codeword.size)
        assertEquals(10, original.shifts.size)
    }

    @Test
    fun testScheduleEngine() {
        val engine = ScheduleEngine()
        val interval0 = engine.baseInterval(batteryPercent = 100.0)
        assertEquals(10.0, interval0, 1e-6)

        val lowBat = engine.baseInterval(batteryPercent = 15.0)
        assertEquals(20.0, lowBat, 1e-6)

        val jittered = engine.nextInterval(batteryPercent = 100.0)
        assertTrue(jittered >= 8.6)
    }
}
