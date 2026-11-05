package com.rebuildrebreak.sesver

import com.rebuildrebreak.sesver.core.FrameEncoder
import com.rebuildrebreak.sesver.core.PayloadV1
import com.rebuildrebreak.sesver.core.SignalSpec
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs

class VectorParityTest {

    data class VectorMeta(
        val name: String,
        val id: Int,
        val people: Int,
        val injured: Int,
        val lifeAge: Int,
        val battery: Int,
        val mode: Int,
        val data24Hex: String,
        val nibbles: IntArray,
        val shifts: IntArray,
        val sampleCount: Int,
        val first8: FloatArray,
        val f32File: String
    )

    private fun parseVectorJson(file: File): VectorMeta {
        val text = file.readText()

        fun extractInt(pattern: String): Int {
            val m = Regex(pattern).find(text)
            return m?.groupValues?.get(1)?.toInt() ?: 0
        }

        fun extractString(pattern: String): String {
            val m = Regex(pattern).find(text)
            return m?.groupValues?.get(1) ?: ""
        }

        fun extractIntArray(arrayName: String): IntArray {
            val m = Regex("\"$arrayName\"\\s*:\\s*\\[([^\\]]+)\\]").find(text)
            val content = m?.groupValues?.get(1) ?: return intArrayOf()
            return content.split(",").map { it.trim().toInt() }.toIntArray()
        }

        fun extractFloatArray(arrayName: String): FloatArray {
            val m = Regex("\"$arrayName\"\\s*:\\s*\\[([^\\]]+)\\]").find(text)
            val content = m?.groupValues?.get(1) ?: return floatArrayOf()
            return content.split(",").map { it.trim().toFloat() }.toFloatArray()
        }

        val name = extractString("\"name\"\\s*:\\s*\"([^\"]+)\"")
        val id = extractInt("\"id\"\\s*:\\s*(\\d+)")
        val people = extractInt("\"people\"\\s*:\\s*(\\d+)")
        val injured = extractInt("\"injured\"\\s*:\\s*(\\d+)")
        val lifeAge = extractInt("\"lifeAge\"\\s*:\\s*(\\d+)")
        val battery = extractInt("\"battery\"\\s*:\\s*(\\d+)")
        val mode = extractInt("\"mode\"\\s*:\\s*(\\d+)")
        val data24Hex = extractString("\"data24_hex\"\\s*:\\s*\"([^\"]+)\"")
        val nibbles = extractIntArray("nibbles")
        val shifts = extractIntArray("shifts")
        val sampleCount = extractInt("\"count\"\\s*:\\s*(\\d+)")
        val first8 = extractFloatArray("first8")
        val f32File = extractString("\"file\"\\s*:\\s*\"([^\"]+)\"")

        return VectorMeta(
            name, id, people, injured, lifeAge, battery, mode,
            data24Hex, nibbles, shifts, sampleCount, first8, f32File
        )
    }

    @Test
    fun testAllVectorsParityWithPython() {
        val vectorsDir = File("/Volumes/ProjectClaude/Ses-Ver/research/signal/vectors/v1")
        val indexFile = File(vectorsDir, "index.json")
        assertTrue("Index dosyası bulunmalı", indexFile.exists())

        // JSON dosyalarını bul
        val jsonFiles = vectorsDir.listFiles { _, name -> name.endsWith(".json") && name != "index.json" }
            ?: emptyArray()
        assertEquals("55 test vektörü bulunmalı", 55, jsonFiles.size)

        for (jsonFile in jsonFiles) {
            val meta = parseVectorJson(jsonFile)
            val payload = PayloadV1(
                id = meta.id,
                people = meta.people,
                injured = meta.injured,
                lifeAge = meta.lifeAge,
                battery = meta.battery,
                mode = meta.mode
            )

            // 1. 24-bit data hex paritesi
            val expectedHex = meta.data24Hex.removePrefix("0x").toInt(16)
            assertEquals("Packed 24 uyumsuz: ${meta.name}", expectedHex, payload.packed24)

            // 2. Codeword (RS16) paritesi
            val codeword = payload.codeword
            assertEquals("Codeword uzunluğu", meta.nibbles.size, codeword.size)
            for (i in codeword.indices) {
                assertEquals("Codeword nibble [$i] uyumsuz: ${meta.name}", meta.nibbles[i], codeword[i])
            }

            // 3. CSS shifts paritesi
            val shifts = payload.shifts
            assertEquals("Shifts uzunluğu", meta.shifts.size, shifts.size)
            for (i in shifts.indices) {
                assertEquals("Shift [$i] uyumsuz: ${meta.name}", meta.shifts[i], shifts[i])
            }

            // 4. Dalga boyu ve örnek karşılaştırması
            val generatedSamples = FrameEncoder.encode(payload, SignalSpec.V1)
            assertEquals("Örnek sayısı", meta.sampleCount, generatedSamples.size)

            // İlk 8 örnek
            for (i in 0 until minOf(8, meta.first8.size)) {
                val diff = abs(generatedSamples[i] - meta.first8[i])
                assertTrue("İlk 8 örnek uyumsuz ${meta.name} @ $i: $diff", diff < 1e-4)
            }

            // f32 binary dosyasını oku ve tam dalga şeklini doğrula
            val f32File = File(vectorsDir, meta.f32File)
            if (f32File.exists()) {
                val bytes = f32File.readBytes()
                val byteBuffer = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
                val expectedFloatArray = FloatArray(bytes.size / 4)
                byteBuffer.asFloatBuffer().get(expectedFloatArray)

                assertEquals("Float32 örnek sayısı", expectedFloatArray.size, generatedSamples.size)

                var maxDiff = 0.0f
                for (i in generatedSamples.indices) {
                    val diff = abs(generatedSamples[i] - expectedFloatArray[i])
                    if (diff > maxDiff) maxDiff = diff
                }
                assertTrue(
                    "Maksimum dalga biçimi sapması aşıldı ${meta.name}: $maxDiff",
                    maxDiff < 1e-3f
                )
            }
        }
    }
}
