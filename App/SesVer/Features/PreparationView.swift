import SwiftUI
import DesignSystem
import BeaconKit
import DeviceServices

public struct PreparationView: View {
    @Binding var isActive: Bool
    @State private var showingTest = false
    @ObservedObject private var audio = AudioSessionCtl.shared

    public init(isActive: Binding<Bool>) {
        self._isActive = isActive
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.Victim.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                        // Başlık ve sayaç
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("prep.title")
                                .font(.largeTitle.bold())
                                .foregroundStyle(DesignSystem.Colors.Victim.text)
                            Text(String(format: NSLocalizedString("prep.counter", comment: ""), 4, 5))
                                .font(.subheadline)
                                .foregroundStyle(DesignSystem.Colors.Victim.textSecondary)
                        }

                        // Birincil başlatma kartı
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.m) {
                            Text("prep.card.body")
                                .font(.body)
                                .foregroundStyle(DesignSystem.Colors.Victim.text)
                            VictimPrimaryButton("prep.card.cta", icon: "waveform") {
                                isActive = true
                            }
                        }
                        .padding(DesignSystem.Spacing.l)
                        .background(DesignSystem.Colors.Victim.surface)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))

                        // Hazırlık listesi
                        VStack(spacing: DesignSystem.Spacing.m) {
                            // Düdük kartı
                            HStack {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .foregroundStyle(DesignSystem.Colors.Victim.signal)
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text("prep.whistle.title")
                                        .font(.headline)
                                        .foregroundStyle(DesignSystem.Colors.Victim.text)
                                    Text("prep.whistle.sub")
                                        .font(.caption)
                                        .foregroundStyle(DesignSystem.Colors.Victim.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(DesignSystem.Spacing.m)
                            .background(DesignSystem.Colors.Victim.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control))

                            // Ses düzeyi kontrolü
                            HStack {
                                Image(systemName: audio.currentVolume >= 0.8 ? "speaker.wave.3.fill" : "speaker.wave.1.fill")
                                    .foregroundStyle(audio.currentVolume >= 0.8 ? DesignSystem.Colors.Victim.text : DesignSystem.Colors.Victim.stop)
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text("prep.volume.title")
                                        .font(.headline)
                                        .foregroundStyle(DesignSystem.Colors.Victim.text)
                                    let volPct = Int(audio.currentVolume * 100)
                                    if audio.currentVolume >= 0.8 {
                                        Text(String(format: NSLocalizedString("prep.volume.ok", comment: ""), volPct))
                                            .font(.caption)
                                            .foregroundStyle(DesignSystem.Colors.Victim.textSecondary)
                                    } else {
                                        Text(String(format: NSLocalizedString("prep.volume.low", comment: ""), volPct))
                                            .font(.caption)
                                            .foregroundStyle(DesignSystem.Colors.Victim.stop)
                                    }
                                }
                                Spacer()
                            }
                            .padding(DesignSystem.Spacing.m)
                            .background(DesignSystem.Colors.Victim.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control))

                            // Test CTA
                            Button {
                                showingTest = true
                            } label: {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                    Text("prep.test.cta")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .font(.body.weight(.medium))
                                .foregroundStyle(DesignSystem.Colors.Victim.signal)
                                .padding(DesignSystem.Spacing.m)
                                .background(DesignSystem.Colors.Victim.surfaceAlt)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control))
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.screenInset)
                }
            }
            .sheet(isPresented: $showingTest) {
                TestSignalView()
            }
        }
    }
}
