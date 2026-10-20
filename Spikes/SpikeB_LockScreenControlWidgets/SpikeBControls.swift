import AppIntents
import SwiftUI
import WidgetKit

// Spike (b) kontrol uzantısı (iOS 18+). `BeaconIntents.swift` bu hedefe WIDGET_EXTENSION koşuluyla
// derlenir; `perform()` sistem tarafından UYGULAMA sürecinde çalıştırılır.

struct StartBeaconControl: ControlWidget {
    static let kind = "sesver.spike.b.start.always"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: StartBeaconIntent()) {
                Label("SV başlat (her zaman)", systemImage: "waveform")
            }
        }
        .displayName("SV başlat (her zaman)")
        .description("authenticationPolicy = alwaysAllowed")
    }
}

struct StartBeaconAuthControl: ControlWidget {
    static let kind = "sesver.spike.b.start.auth"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: StartBeaconAuthIntent()) {
                Label("SV başlat (kimlik)", systemImage: "lock.circle")
            }
        }
        .displayName("SV başlat (kimlik)")
        .description("authenticationPolicy = requiresAuthentication")
    }
}

struct StopBeaconControl: ControlWidget {
    static let kind = "sesver.spike.b.stop"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: StopBeaconIntent()) {
                Label("SV durdur", systemImage: "stop.fill")
            }
        }
        .displayName("SV durdur")
    }
}

@main
struct SpikeBWidgets: WidgetBundle {
    var body: some Widget {
        StartBeaconControl()
        StartBeaconAuthControl()
        StopBeaconControl()
    }
}
