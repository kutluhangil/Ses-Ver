package com.rebuildrebreak.sesver.core

/**
 * SignalSpec v1 P1 yükü (24 bit).
 */
data class PayloadV1(
    val id: Int,          // 12 bit (0x001..0xFFE)
    val people: Int = 0,  // 3 bit (0: belirtilmedi, 1..6, 7: 7+)
    val injured: Int = 0, // 1 bit (0/1)
    val lifeAge: Int = 15,// 4 bit (0..15)
    val battery: Int = 0, // 2 bit (0..3)
    val mode: Int = 0     // 2 bit (0..3)
) {
    init {
        require(id in 1..0xFFE) { "id 12-bit ve ayrılmış olmamalı" }
        require(people in 0..7) { "people 3-bit olmalı" }
        require(injured in 0..1) { "injured 1-bit olmalı" }
        require(lifeAge in 0..15) { "lifeAge 4-bit olmalı" }
        require(battery in 0..3) { "battery 2-bit olmalı" }
        require(mode in 0..3) { "mode 2-bit olmalı" }
    }

    val packed24: Int
        get() = (id shl 12) or (people shl 9) or (injured shl 8) or (lifeAge shl 4) or (battery shl 2) or mode

    val dataNibbles: IntArray
        get() {
            val w = packed24
            return IntArray(6) { i -> (w shr (20 - 4 * i)) and 0xF }
        }

    val codeword: IntArray
        get() = RS16.encode(dataNibbles)

    val shifts: IntArray
        get() = codeword.map { GrayCode.decode(it) }.toIntArray()

    companion object {
        fun unpack(d: Int): PayloadV1 {
            return PayloadV1(
                id = (d shr 12) and 0xFFF,
                people = (d shr 9) and 7,
                injured = (d shr 8) and 1,
                lifeAge = (d shr 4) and 0xF,
                battery = (d shr 2) and 3,
                mode = d and 3
            )
        }

        fun fromNibbles(nibs: IntArray): PayloadV1 {
            require(nibs.size >= 6) { "En az 6 nibble gerekli" }
            var w = 0
            for (i in 0 until 6) {
                w = (w shl 4) or (nibs[i] and 0xF)
            }
            return unpack(w)
        }
    }
}
