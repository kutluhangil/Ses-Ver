import SwiftUI
import DesignSystem
import BeaconKit
import DeviceServices

public struct TestSignalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var countdown = 5
    @State private var hasPlayed = false
    @State private var answered = false
    @State private var timer: Timer?

    public init() {}

    public var body: some View {
        ZStack {
            DesignSystem.Colors.Victim.bg.ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()

                if !hasPlayed {
                    VStack(spacing: DesignSystem.Spacing.m) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(DesignSystem.Colors.Victim.signal)
                        Text("test.title")
                            .font(.title2.bold())
                            .foregroundStyle(DesignSystem.Colors.Victim.text)
                        Text(String(format: NSLocalizedString("test.countdown", comment: ""), countdown))
                            .font(.largeTitle.bold().monospacedDigit())
                            .foregroundStyle(DesignSystem.Colors.Victim.signal)
                    }
                } else {
                    VStack(spacing: DesignSystem.Spacing.l) {
                        Text("test.question")
                            .font(.title.bold())
                            .foregroundStyle(DesignSystem.Colors.Victim.text)

                        VictimPrimaryButton("test.yes", icon: "checkmark.circle.fill") {
                            dismiss()
                        }

                        Button {
                            countdown = 5
                            hasPlayed = false
                            startTest()
                        } label: {
                            Text("test.no")
                                .font(.body.weight(.medium))
                                .foregroundStyle(DesignSystem.Colors.Victim.textSecondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(DesignSystem.Spacing.screenInset)
        }
        .onAppear {
            startTest()
        }
        .onDisappear {
            timer?.invalidate()
            AudioSessionCtl.shared.stop()
        }
    }

    private func startTest() {
        let testPayload = PayloadV1(id: 0x7F2, people: 1, injured: 0, lifeAge: 0, battery: 3, mode: 0)
        try? AudioSessionCtl.shared.start(payload: testPayload)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            countdown -= 1
            if countdown <= 0 {
                t.invalidate()
                AudioSessionCtl.shared.stop()
                hasPlayed = true
            }
        }
    }
}
