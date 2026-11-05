import SwiftUI
import DesignSystem

@main
struct SesVerApp: App {
    @State private var isBeaconActive = false

    var body: some Scene {
        WindowGroup {
            Group {
                if isBeaconActive {
                    ActiveBeaconView(isActive: $isBeaconActive)
                } else {
                    PreparationView(isActive: $isBeaconActive)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
