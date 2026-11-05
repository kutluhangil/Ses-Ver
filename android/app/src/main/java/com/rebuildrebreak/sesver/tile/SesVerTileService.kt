package com.rebuildrebreak.sesver.tile

import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi
import com.rebuildrebreak.sesver.service.BeaconForegroundService

@RequiresApi(Build.VERSION_CODES.N)
class SesVerTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        updateTileState()
    }

    override fun onClick() {
        super.onClick()
        val isRunning = BeaconForegroundService.isRunning.get()
        if (isRunning) {
            BeaconForegroundService.stopService(this)
        } else {
            BeaconForegroundService.startService(this)
        }
        updateTileState()
    }

    private fun updateTileState() {
        val tile = qsTile ?: return
        val isRunning = BeaconForegroundService.isRunning.get()

        tile.state = if (isRunning) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = if (isRunning) "Ses Ver: Açık" else "Ses Ver"
        tile.icon = Icon.createWithResource(this, android.R.drawable.ic_lock_silent_mode_off)
        tile.updateTile()
    }
}
