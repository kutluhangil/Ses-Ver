package com.rebuildrebreak.sesver.ui

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rebuildrebreak.sesver.service.BeaconForegroundService

// Tasarım Sistemi Renk Token'ları (docs/design/tokens.json)
object SesVerTheme {
    val Black = Color(0xFF000000)
    val SurfaceVictim = Color(0xFF1F1C18)
    val TextVictim = Color(0xFFF4EFE6)
    val TextVictimSecondary = Color(0xFFB3ADA2)
    val SignalAmber = Color(0xFFFFB23E)
    val OnSignal = Color(0xFF1A1100)
    val StopRed = Color(0xFFFF7A6B)

    val RescuerBg = Color(0xFF0E1114)
    val SurfaceRescuer = Color(0xFF171C21)
    val TextRescuer = Color(0xFFEEF2F5)
    val TextRescuerSecondary = Color(0xFFA2ADB9)
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            SesVerMainScreen()
        }
    }
}

@Composable
fun SesVerMainScreen() {
    val context = LocalContext.current
    var selectedTab by remember { mutableIntStateOf(0) }
    var isBeaconActive by remember { mutableStateOf(BeaconForegroundService.isRunning.get()) }

    Scaffold(
        bottomBar = {
            NavigationBar(
                containerColor = if (selectedTab == 0) SesVerTheme.SurfaceVictim else SesVerTheme.SurfaceRescuer
            ) {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    icon = {
                        Text("📡", fontSize = 20.sp)
                    },
                    label = { Text("İşaret", color = if (selectedTab == 0) SesVerTheme.SignalAmber else Color.Gray) },
                    colors = NavigationBarItemDefaults.colors(
                        indicatorColor = SesVerTheme.SignalAmber.copy(alpha = 0.2f)
                    )
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = {
                        Text("🎧", fontSize = 20.sp)
                    },
                    label = { Text("Kurtarıcı (Dinle)", color = if (selectedTab == 1) SesVerTheme.SignalAmber else Color.Gray) },
                    colors = NavigationBarItemDefaults.colors(
                        indicatorColor = SesVerTheme.SignalAmber.copy(alpha = 0.2f)
                    )
                )
            }
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(if (selectedTab == 0) SesVerTheme.Black else SesVerTheme.RescuerBg)
        ) {
            if (selectedTab == 0) {
                if (isBeaconActive) {
                    ActiveBeaconContent(
                        onHereClicked = {
                            val intent = android.content.Intent(context, BeaconForegroundService::class.java).apply {
                                action = BeaconForegroundService.ACTION_HERE
                            }
                            context.startService(intent)
                        },
                        onStopHeld = {
                            BeaconForegroundService.stopService(context)
                            isBeaconActive = false
                        }
                    )
                } else {
                    PreparationContent(
                        onStart = {
                            BeaconForegroundService.startService(context)
                            isBeaconActive = true
                        }
                    )
                }
            } else {
                RescuerContent()
            }
        }
    }
}

@Composable
fun PreparationContent(onStart: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        Column {
            Text(
                text = "Ses Ver",
                color = SesVerTheme.TextVictim,
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Deprem sonrası akustik işaretleyici",
                color = SesVerTheme.TextVictimSecondary,
                fontSize = 16.sp
            )

            Spacer(modifier = Modifier.height(32.dp))

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(SesVerTheme.SurfaceVictim, RoundedCornerShape(20.dp))
                    .padding(20.dp)
            ) {
                Column {
                    Text(
                        text = "Telefonunuz belirli aralıklarla insan kulağının ve kurtarma dedektörlerinin duyabileceği akustik bir ıslık deseni çalar.",
                        color = SesVerTheme.TextVictim,
                        fontSize = 16.sp,
                        lineHeight = 24.sp
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = "Ekran kapalı olsa dahi 72 saat boyunca çalışır.",
                        color = SesVerTheme.SignalAmber,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }
        }

        Button(
            onClick = onStart,
            modifier = Modifier
                .fillMaxWidth()
                .height(64.dp),
            shape = RoundedCornerShape(22.dp),
            colors = ButtonDefaults.buttonColors(containerColor = SesVerTheme.SignalAmber)
        ) {
            Text(
                text = "SES VER'İ BAŞLAT",
                color = SesVerTheme.OnSignal,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
fun ActiveBeaconContent(onHereClicked: () -> Unit, onStopHeld: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        Column {
            Text(
                text = "İşaret Aktif",
                color = SesVerTheme.SignalAmber,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Ekranı kapatabilirsiniz · Sinyal arka planda çalıyor",
                color = SesVerTheme.TextVictimSecondary,
                fontSize = 14.sp
            )
        }

        Button(
            onClick = onHereClicked,
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp),
            shape = RoundedCornerShape(28.dp),
            colors = ButtonDefaults.buttonColors(containerColor = SesVerTheme.SignalAmber)
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = "BURADAYIM",
                    color = SesVerTheme.OnSignal,
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Black
                )
                Text(
                    text = "Uyanık olduğunuzu belirtmek için dokunun",
                    color = SesVerTheme.OnSignal.copy(alpha = 0.8f),
                    fontSize = 13.sp
                )
            }
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp)
                .background(SesVerTheme.SurfaceVictim, RoundedCornerShape(16.dp))
                .pointerInput(Unit) {
                    detectTapGestures(
                        onLongPress = { onStopHeld() }
                    )
                },
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "DURDURMAK İÇİN BASILI TUTUN",
                color = SesVerTheme.StopRed,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
fun RescuerContent() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
    ) {
        Text(
            text = "Dinle",
            color = SesVerTheme.TextRescuer,
            fontSize = 32.sp,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = "Dinleniyor · 1 200 – 3 000 Hz akustik bant",
            color = SesVerTheme.TextRescuerSecondary,
            fontSize = 14.sp
        )

        Spacer(modifier = Modifier.height(24.dp))

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(SesVerTheme.SurfaceRescuer, RoundedCornerShape(20.dp))
                .padding(20.dp)
        ) {
            Column {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        text = "#05A1",
                        color = SesVerTheme.SignalAmber,
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                        fontSize = 18.sp
                    )
                    Text(
                        text = "+14.5 dB SNR",
                        color = SesVerTheme.SignalAmber,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 14.sp
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "≥ 1 kişi · Son dokunuş 2–5 dk önce",
                    color = SesVerTheme.TextRescuer,
                    fontSize = 14.sp
                )
                Text(
                    text = "Pil %62–75 · BLE: Güçlü",
                    color = SesVerTheme.TextRescuerSecondary,
                    fontSize = 12.sp
                )
            }
        }
    }
}
