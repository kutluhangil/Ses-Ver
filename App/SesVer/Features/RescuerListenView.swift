import SwiftUI
import DesignSystem
import DetectorKit
import LocalizationKit
import BeaconKit

public struct RescuerListenView: View {
    @State private var tracker = BeaconTracker()
    @State private var showingSilence = false
    @State private var selectedBeacon: TrackedBeacon?
    @State private var noiseLevelDb: Int = 42

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.Rescuer.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                        // Üst Dinleme Durumu ve Sessizlik Butonu
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.m) {
                            HStack {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text("listen.title")
                                        .font(.largeTitle.bold())
                                        .foregroundStyle(DesignSystem.Colors.Rescuer.text)
                                    Text(String(format: NSLocalizedString("listen.status", comment: ""), noiseLevelDb))
                                        .font(.subheadline.monospaced())
                                        .foregroundStyle(DesignSystem.Colors.Rescuer.textSecondary)
                                }
                                Spacer()
                            }

                            // Sessizlik Butonu
                            Button {
                                showingSilence = true
                            } label: {
                                HStack {
                                    Image(systemName: "waveform.badge.magnifyingglass")
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("listen.silence.cta")
                                            .font(.headline)
                                        Text("listen.silence.sub")
                                            .font(.caption2)
                                            .foregroundStyle(DesignSystem.Colors.Rescuer.onSignal.opacity(0.8))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .padding(DesignSystem.Spacing.m)
                                .foregroundStyle(DesignSystem.Colors.Rescuer.onSignal)
                                .background(DesignSystem.Colors.Rescuer.signal)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control))
                            }
                        }

                        // İşaretler Listesi
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.m) {
                            Text("listen.nearby")
                                .font(.headline)
                                .foregroundStyle(DesignSystem.Colors.Rescuer.text)

                            let beacons = tracker.allBeacons
                            if beacons.isEmpty {
                                VStack(spacing: DesignSystem.Spacing.m) {
                                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                                        .font(.system(size: 40))
                                        .foregroundStyle(DesignSystem.Colors.Rescuer.textSecondary.opacity(0.6))
                                    Text("listen.empty")
                                        .font(.subheadline)
                                        .foregroundStyle(DesignSystem.Colors.Rescuer.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(DesignSystem.Spacing.xl)
                                .frame(maxWidth: .infinity)
                                .background(DesignSystem.Colors.Rescuer.surface)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
                            } else {
                                ForEach(beacons) { b in
                                    BeaconCard(beacon: b) {
                                        selectedBeacon = b
                                    }
                                }
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.screenInset)
                }
            }
            .sheet(isPresented: $showingSilence) {
                SilenceModeView()
            }
            .sheet(item: $selectedBeacon) { b in
                HeatMapView(beacon: b)
            }
            .onAppear {
                // Önizleme veya test için örnek işaretler (boş değilse)
                if tracker.allBeacons.isEmpty {
                    let p1 = PayloadV1(id: 0x05A1, people: 0, injured: 1, lifeAge: 2, battery: 3, mode: 0)
                    tracker.registerFrame(payload: p1, snr: 14.5)
                    tracker.registerFrame(payload: p1, snr: 15.0)

                    let p2 = PayloadV1(id: 0x07F2, people: 2, injured: 0, lifeAge: 0, battery: 2, mode: 0)
                    tracker.registerFrame(payload: p2, snr: 9.8) // Henüz tek çerçeve
                }
            }
        }
    }
}

private struct BeaconCard: View {
    let beacon: TrackedBeacon
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.m) {
                // Başlık Satırı: ID ve Doğrulama Durumu
                HStack {
                    Text(String(format: "#%04X", beacon.id))
                        .font(.title3.bold().monospaced())
                        .foregroundStyle(DesignSystem.Colors.Rescuer.signal)

                    Spacer()

                    if beacon.isVerifiedTwoFrames {
                        Text(String(format: "+%.1f dB", beacon.lastSNR))
                            .font(.caption.bold().monospaced())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DesignSystem.Colors.Rescuer.surfaceAlt)
                            .foregroundStyle(DesignSystem.Colors.Rescuer.signal)
                            .clipShape(Capsule())
                    } else {
                        Text("card.confirming")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DesignSystem.Colors.Rescuer.surfaceAlt)
                            .foregroundStyle(DesignSystem.Colors.Rescuer.textSecondary)
                            .clipShape(Capsule())
                    }
                }

                // Canlılık Bilgileri
                if beacon.isVerifiedTwoFrames {
                    HStack(spacing: DesignSystem.Spacing.m) {
                        // Kişi sayısı
                        if beacon.payload.people == 0 {
                            Label(NSLocalizedString("card.people.atleast1", comment: ""), systemImage: "person.fill")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(DesignSystem.Colors.Rescuer.text)
                        } else {
                            Label(String(format: NSLocalizedString("card.people", comment: ""), beacon.payload.people + 1), systemImage: "person.2.fill")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(DesignSystem.Colors.Rescuer.text)
                        }

                        // Yaralı durumu
                        if beacon.payload.injured == 1 {
                            Label(NSLocalizedString("card.injured", comment: ""), systemImage: "cross.case.fill")
                                .font(.footnote.bold())
                                .foregroundStyle(DesignSystem.Colors.Rescuer.stop)
                        }

                        Spacer()
                    }

                    // Alt Detaylar (Son dokunuş, pil)
                    HStack {
                        let ageStr = lifeAgeDescription(beacon.payload.lifeAge)
                        Text(String(format: NSLocalizedString("card.lastTouch.range", comment: ""), ageStr))
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Rescuer.textSecondary)

                        Spacer()

                        let batMin = beacon.payload.battery * 12 + 10
                        let batMax = min(100, batMin + 15)
                        Text(String(format: NSLocalizedString("card.battery", comment: ""), batMin, batMax))
                            .font(.caption.monospaced())
                            .foregroundStyle(DesignSystem.Colors.Rescuer.textSecondary)
                    }
                } else {
                    Text("card.confirming.sub")
                        .font(.footnote)
                        .foregroundStyle(DesignSystem.Colors.Rescuer.textSecondary)
                }
            }
            .padding(DesignSystem.Spacing.l)
            .background(DesignSystem.Colors.Rescuer.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .stroke(beacon.isVerifiedTwoFrames ? DesignSystem.Colors.Rescuer.border : DesignSystem.Colors.Rescuer.border.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func lifeAgeDescription(_ code: Int) -> String {
        switch code {
        case 0: return "< 2 dk"
        case 1: return "2–5 dk"
        case 2: return "5–15 dk"
        case 3: return "15–60 dk"
        default: return "1–4 sa"
        }
    }
}
