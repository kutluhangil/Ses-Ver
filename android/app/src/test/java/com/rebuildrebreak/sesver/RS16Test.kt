package com.rebuildrebreak.sesver

import com.rebuildrebreak.sesver.core.RS16
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RS16Test {

    @Test
    fun testEncodeAndRemainder() {
        val data = intArrayOf(0, 5, 10, 1, 2, 3)
        val encoded = RS16.encode(data)
        assertEquals(10, encoded.size)
        assertEquals(0, RS16.remainder(encoded))
    }

    @Test
    fun testSingleSymbolCorrection() {
        val data = intArrayOf(1, 2, 3, 4, 5, 6)
        val encoded = RS16.encode(data)

        // 1 sembol boz
        val corrupted = encoded.copyOf()
        corrupted[2] = corrupted[2] xor 0x7

        val result = RS16.decode(corrupted, tMax = 1)
        assertTrue(result.ok)
        assertArrayEquals(encoded, result.corrected)
        assertEquals(1, result.corrections.size)
        assertEquals(2, result.corrections[0].position)
        assertEquals(0x7, result.corrections[0].value)
    }

    @Test
    fun testTwoSymbolErrorRejection() {
        val data = intArrayOf(1, 2, 3, 4, 5, 6)
        val encoded = RS16.encode(data)

        // 2 sembol boz
        val corrupted = encoded.copyOf()
        corrupted[0] = corrupted[0] xor 0x3
        corrupted[4] = corrupted[4] xor 0x5

        val result = RS16.decode(corrupted, tMax = 1)
        assertFalse("tMax=1 iken 2 sembol hatası reddedilmeli", result.ok)
    }

    @Test
    fun testErasureDecoding() {
        val data = intArrayOf(9, 8, 7, 6, 5, 4)
        val encoded = RS16.encode(data)

        val corrupted = encoded.copyOf()
        corrupted[1] = 0 // silinme konumu 1
        corrupted[3] = 0 // silinme konumu 3

        val result = RS16.decodeErasures(corrupted, erasures = intArrayOf(1, 3), tMax = 0)
        assertTrue(result.ok)
        assertArrayEquals(encoded, result.corrected)
    }
}
