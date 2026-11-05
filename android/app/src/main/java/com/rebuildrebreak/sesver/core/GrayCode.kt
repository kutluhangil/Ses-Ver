package com.rebuildrebreak.sesver.core

object GrayCode {
    fun encode(x: Int): Int = x xor (x shr 1)

    fun decode(g: Int): Int {
        var x = g
        var mask = x shr 1
        while (mask != 0) {
            x = x xor mask
            mask = mask shr 1
        }
        return x
    }
}
