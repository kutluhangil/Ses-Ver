package com.rebuildrebreak.sesver.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import com.rebuildrebreak.sesver.R
import com.rebuildrebreak.sesver.core.PayloadV1
import com.rebuildrebreak.sesver.core.ScheduleEngine
import com.rebuildrebreak.sesver.core.SignalSpec
import com.rebuildrebreak.sesver.ui.MainActivity
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 72 saat kesintisiz arka plan akustik ve BLE yayını yürüten Ön Plan Servisi.
 */
class BeaconForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "sesver_beacon_channel"
        const val NOTIFICATION_ID = 1001

        const val ACTION_START = "com.rebuildrebreak.sesver.START"
        const val ACTION_STOP = "com.rebuildrebreak.sesver.STOP"
        const val ACTION_HERE = "com.rebuildrebreak.sesver.HERE"

        val isRunning = AtomicBoolean(false)

        fun startService(context: Context) {
            val intent = Intent(context, BeaconForegroundService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, BeaconForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var playbackEngine: AudioPlaybackEngine? = null
    private var bleAdvertiser: BLEAdvertiserService? = null
    private var scheduleEngine = ScheduleEngine()
    private var loopThread: Thread? = null

    // Varsayılan kurban yükü
    private var payload = PayloadV1(id = 0x5A1, people = 0, injured = 0, lifeAge = 0, battery = 3, mode = 0)
    private var lastTouchTimeMs = System.currentTimeMillis()

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()

        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SesVer:BeaconWakeLock").apply {
            setReferenceCounted(false)
        }

        playbackEngine = AudioPlaybackEngine(SignalSpec.V1)
        bleAdvertiser = BLEAdvertiserService(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopBeacon()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_HERE -> {
                lastTouchTimeMs = System.currentTimeMillis()
                updatePayloadLifeAge()
            }
            ACTION_START, null -> {
                if (!isRunning.get()) {
                    startBeacon()
                }
            }
        }
        return START_STICKY
    }

    private fun startBeacon() {
        isRunning.set(true)
        wakeLock?.acquire(72 * 3600 * 1000L) // 72 saat azami tutuş

        val notification = buildNotification()
        startForeground(NOTIFICATION_ID, notification)

        playbackEngine?.initAudioTrack()
        bleAdvertiser?.startAdvertising(payload)

        scheduleEngine = ScheduleEngine()
        loopThread = Thread {
            while (isRunning.get()) {
                updatePayloadLifeAge()

                // Akustik çerçeveyi çal (1.024 sn Ton)
                playbackEngine?.playFrame(payload, gain = 1.0f)

                // Görev döngüsü aralığını bekle
                val nextWaitSec = scheduleEngine.nextInterval(batteryPercent = 100.0)
                val sleepMs = (nextWaitSec * 1000).toLong()

                try {
                    Thread.sleep(sleepMs)
                } catch (_: InterruptedException) {
                    break
                }
            }
        }.apply {
            priority = Thread.MAX_PRIORITY
            start()
        }
    }

    private fun updatePayloadLifeAge() {
        val elapsedSec = (System.currentTimeMillis() - lastTouchTimeMs) / 1000
        val ageBin = when {
            elapsedSec < 120 -> 0      // < 2 dk
            elapsedSec < 300 -> 1      // 2–5 dk
            elapsedSec < 900 -> 2      // 5–15 dk
            elapsedSec < 3600 -> 3     // 15–60 dk
            else -> 4                  // 1–4 sa
        }
        payload = payload.copy(lifeAge = ageBin)
    }

    private fun stopBeacon() {
        isRunning.set(false)
        loopThread?.interrupt()
        loopThread = null

        playbackEngine?.stop()
        bleAdvertiser?.stopAdvertising()

        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    override fun onDestroy() {
        stopBeacon()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                getString(R.string.notification_channel_name),
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = getString(R.string.notification_channel_desc)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val launchIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle(getString(R.string.notification_title))
            .setContentText(getString(R.string.notification_text))
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
