package com.rebuildrebreak.sesver.core

import kotlin.random.Random

/**
 * Çerçeve yayım zamanlaması ve pil koruma görev döngüsü yöneticisi (docs/contracts/signal-v1.md §6).
 */
class ScheduleEngine(val startTimeMs: Long = System.currentTimeMillis()) {

    fun baseInterval(nowMs: Long = System.currentTimeMillis(), batteryPercent: Double = 100.0): Double {
        val elapsedHours = (nowMs - startTimeMs) / (1000.0 * 3600.0)
        val base = when {
            elapsedHours < 6.0 -> 10.0
            elapsedHours < 24.0 -> 20.0
            elapsedHours < 72.0 -> 45.0
            else -> 90.0
        }
        val batteryFactor = if (batteryPercent < 20.0) 2.0 else 1.0
        return base * batteryFactor
    }

    fun nextInterval(nowMs: Long = System.currentTimeMillis(), batteryPercent: Double = 100.0): Double {
        val base = baseInterval(nowMs, batteryPercent)
        val jitterFraction = Random.nextDouble(-0.15, 0.15)
        val interval = base * (1.0 + jitterFraction)
        // Güvenlik alt sınırı: Ton / interval <= 0.12 => Ton=1.024s için interval >= 8.54s
        return maxOf(8.6, interval)
    }
}
