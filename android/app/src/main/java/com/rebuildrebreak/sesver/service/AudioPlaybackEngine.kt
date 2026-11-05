package com.rebuildrebreak.sesver.service

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import com.rebuildrebreak.sesver.core.FrameEncoder
import com.rebuildrebreak.sesver.core.PayloadV1
import com.rebuildrebreak.sesver.core.SignalSpec

/**
 * 48 kHz mono Float AudioTrack sentez ve çalma motoru.
 * USAGE_ALARM kullanarak sessiz mod ve Rahatsız Etmeyin (DND) filtrelerini deler.
 */
class AudioPlaybackEngine(private val spec: SignalSpec = SignalSpec.V1) {

    private var audioTrack: AudioTrack? = null
    @Volatile private var isPlaying = false

    fun initAudioTrack() {
        val bufferSize = spec.frameLen * 4 // Float (4 byte)
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM) // Sessiz modu ve DND'yi deler
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val format = AudioFormat.Builder()
            .setSampleRate(spec.sampleRate.toInt())
            .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
            .build()

        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(attributes)
            .setAudioFormat(format)
            .setBufferSizeInBytes(bufferSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()

        audioTrack?.play()
        isPlaying = true
    }

    fun playFrame(payload: PayloadV1, gain: Float = 1.0f) {
        val samples = FrameEncoder.encode(payload, spec, gain)
        audioTrack?.let { track ->
            if (track.playState != AudioTrack.PLAYSTATE_PLAYING) {
                track.play()
            }
            track.write(samples, 0, samples.size, AudioTrack.WRITE_BLOCKING)
        }
    }

    fun stop() {
        isPlaying = false
        try {
            audioTrack?.stop()
            audioTrack?.release()
        } catch (_: Exception) {}
        audioTrack = null
    }
}
