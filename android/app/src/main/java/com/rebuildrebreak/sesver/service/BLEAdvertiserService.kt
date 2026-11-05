package com.rebuildrebreak.sesver.service

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import com.rebuildrebreak.sesver.core.PayloadV1
import java.util.UUID

/**
 * SignalSpec v1 BLE yayın yöneticisi (docs/contracts/signal-v1.md §7).
 * UUID: A6E00001-5E50-4E10-9E10-5E5056455201.
 */
class BLEAdvertiserService(private val context: Context) {

    companion object {
        val SERVICE_UUID: UUID = UUID.fromString("A6E00001-5E50-4E10-9E10-5E5056455201")
        const val MANUFACTURER_ID = 0xFFFF
    }

    private var advertiser: BluetoothLeAdvertiser? = null
    private var isAdvertising = false

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            isAdvertising = true
        }

        override fun onStartFailure(errorCode: Int) {
            isAdvertising = false
        }
    }

    fun startAdvertising(payload: PayloadV1) {
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = bluetoothManager?.adapter ?: return
        if (!adapter.isEnabled) return

        advertiser = adapter.bluetoothLeAdvertiser ?: return

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_POWER)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(false)
            .setTimeout(0)
            .build()

        val manufacturerData = byteArrayOf(
            ((payload.id shr 8) and 0xFF).toByte(),
            (payload.id and 0xFF).toByte(),
            ((payload.lifeAge shl 4) or (payload.battery and 0xF)).toByte()
        )

        val data = AdvertiseData.Builder()
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .addManufacturerData(MANUFACTURER_ID, manufacturerData)
            .setIncludeDeviceName(false)
            .build()

        try {
            advertiser?.startAdvertising(settings, data, advertiseCallback)
        } catch (_: SecurityException) {}
    }

    fun stopAdvertising() {
        try {
            advertiser?.stopAdvertising(advertiseCallback)
        } catch (_: SecurityException) {}
        isAdvertising = false
        advertiser = null
    }
}
