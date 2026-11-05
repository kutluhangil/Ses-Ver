import SwiftUI
import DesignSystem
import BeaconKit
import DeviceServices

public struct ActiveBeaconView: View {
    @Binding var isActive: Bool
    @State private var peopleCount = 1
    @State private var hasInjured = false
    @State private var lastTouchDate = Date()
    @State private var isMuted = false
    @ObservedObject private var audio = AudioSessionCtl.shared

    public init(isActive: Binding<Bool>) {
        self._isActive = isActive
    }

    public var body: some View {
        ZStack {
            DesignSystem.Colors.Victim.bg.ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.xl) {
                // Üst durum çipleri
                HStack {
                    let volPct = Int(audio.currentVolume * 100)
                    StatusChip(
                        icon: "speaker.wave.3.fill",
                        text: "\(volPct)%",
                        isWarning: audio.currentVolume < 0.8
                    )
                    Spacer()
                    StatusChip(icon: "battery.100", text: "85%")
                    Spacer()
                    StatusChip(icon: "bell.badge.fill", text: "Yedek 24s")
                }
                .padding(.top, DesignSystem.Spacing.m)

                // Ana başlık ve sayaç
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("beacon.title")
                        .font(.largeTitle.bold())
                        .foregroundStyle(DesignSystem.Colors.Victim.signal)
                    Text(String(format: NSLocalizedString("beacon.next", comment: ""), audio.nextFrameSeconds))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(DesignSystem.Colors.Victim.textSecondary)
                }

                // "Buradayım" butonu
                HereButton(lastTouchDescription: "az önce") {
                    lastTouchDate = Date()
                    LifeSignStore.shared.registerTouch(at: lastTouchDate)
                }

                // Kişi sayısı ve yaralı seçimi
                VStack(spacing: DesignSystem.Spacing.m) {
                    HStack {
                        Text("beacon.people.title")
                            .font(.headline)
                            .foregroundStyle(DesignSystem.Colors.Victim.text)
                        Spacer()
                        Picker("", selection: $peopleCount) {
                            ForEach(1...7, id: \.self) { n in
                                Text(n == 7 ? "7+" : "\(n)").tag(n)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 180)
                    }

                    Toggle(isOn: $hasInjured) {
                        Text("beacon.injured")
                            .font(.headline)
                            .foregroundStyle(DesignSystem.Colors.Victim.text)
                    }
                    .tint(DesignSystem.Colors.Victim.stop)
                }
                .padding(DesignSystem.Spacing.l)
                .background(DesignSystem.Colors.Victim.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))

                Spacer()

                // Durdurma ve acil arama düğmeleri
                VStack(spacing: DesignSystem.Spacing.m) {
                    HoldToStopButton {
                        stopBeacon()
                    }

                    Link(destination: URL(string: "tel://112")!) {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("beacon.call112")
                        }
                        .font(.footnote)
                        .foregroundStyle(DesignSystem.Colors.Victim.textSecondary)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenInset)
            .padding(.bottom, DesignSystem.Spacing.l)
        }
        .onAppear {
            startBeacon()
        }
    }

    private func startBeacon() {
        let payload = PayloadV1(
            id: Int.random(in: 1..<0xFFF),
            people: min(7, peopleCount),
            injured: hasInjured ? 1 : 0,
            lifeAge: 0,
            battery: 3,
            mode: 0
        )
        try? audio.start(payload: payload)
        Task {
            await NotificationChain.shared.scheduleChain()
        }
        BLEAdvertiser.shared.start(payload: payload)
    }

    private func stopBeacon() {
        audio.stop()
        NotificationChain.shared.cancelChain()
        BLEAdvertiser.shared.stop()
        isActive = false
    }
}
