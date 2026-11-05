import SwiftUI
import DesignSystem

@main
struct SesVerApp: App {
    @State private var isBeaconActive = false
    @State private var selectedTab = 0

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                Group {
                    if isBeaconActive {
                        ActiveBeaconView(isActive: $isBeaconActive)
                    } else {
                        PreparationView(isActive: $isBeaconActive)
                    }
                }
                .tabItem {
                    Label(NSLocalizedString("mode.victim", comment: ""), systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(0)

                RescuerListenView()
                    .tabItem {
                        Label(NSLocalizedString("mode.rescuer", comment: ""), systemImage: "waveform.badge.magnifyingglass")
                    }
                    .tag(1)
            }
            .preferredColorScheme(.dark)
            .tint(selectedTab == 0 ? DesignSystem.Colors.Victim.signal : DesignSystem.Colors.Rescuer.signal)
        }
    }
}
