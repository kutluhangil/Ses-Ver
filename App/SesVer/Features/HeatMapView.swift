import SwiftUI
import DesignSystem
import LocalizationKit
import DetectorKit

public struct HeatMapView: View {
    @Environment(\.dismiss) private var dismiss
    public let beacon: TrackedBeacon
    @State private var mapper = SNRFieldMapper(cellSize: 0.5)
    @State private var readings: [FieldReading] = []
    @State private var peak: Point3D? = nil

    public init(beacon: TrackedBeacon) {
        self.beacon = beacon
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.Rescuer.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                        // Üst Bilgi Kartı
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s) {
                            HStack {
                                Text(String(format: "#%04X", beacon.id))
                                    .font(.title2.bold().monospaced())
                                    .foregroundStyle(DesignSystem.Colors.Rescuer.signal)

                                Spacer()

                                Text("ar.experimental")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(DesignSystem.Colors.Rescuer.surfaceAlt)
                                    .foregroundStyle(DesignSystem.Colors.Rescuer.textSecondary)
                                    .clipShape(Capsule())
                            }

                            Text(String(format: NSLocalizedString("listen.status", comment: ""), Int(beacon.lastSNR)))
                                .font(.subheadline)
                                .foregroundStyle(DesignSystem.Colors.Rescuer.textSecondary)
                        }
                        .padding(DesignSystem.Spacing.l)
                        .background(DesignSystem.Colors.Rescuer.surface)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))

                        // Zemin Güç Izgarası / Simülasyon Görseli
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.m) {
                            Text("ar.title")
                                .font(.headline)
                                .foregroundStyle(DesignSystem.Colors.Rescuer.text)

                            ZStack {
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                                    .fill(DesignSystem.Colors.Rescuer.surface)
                                    .frame(height: 240)

                                // Izgara Çizgileri
                                GridShape()
                                    .stroke(DesignSystem.Colors.Rescuer.border.opacity(0.4), lineWidth: 1)
                                    .frame(height: 240)

                                // Tepe Noktası Göstergesi
                                Circle()
                                    .fill(DesignSystem.Colors.Rescuer.signal.opacity(0.8))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(DesignSystem.Colors.Rescuer.signal, lineWidth: 2)
                                            .scaleEffect(1.6)
                                    )

                                Text(String(format: "%.1f dB", beacon.lastSNR))
                                    .font(.caption.bold().monospaced())
                                    .foregroundStyle(DesignSystem.Colors.Rescuer.onSignal)
                            }

                            HStack {
                                Text(String(format: NSLocalizedString("ar.samples", comment: ""), max(1, beacon.frameCount)))
                                    .font(.footnote)
                                    .foregroundStyle(DesignSystem.Colors.Rescuer.textSecondary)
                                Spacer()
                                if let p = peak {
                                    Text(String(format: "X: %.1fm Y: %.1fm", p.x, p.y))
                                        .font(.footnote.monospaced())
                                        .foregroundStyle(DesignSystem.Colors.Rescuer.signal)
                                }
                            }
                        }

                        // Eylem Butonu
                        Button {
                            // Bölgeyi işaretle
                            mapper.addReading(position: Point3D(x: 0, y: 0, z: 0), snrDb: beacon.lastSNR)
                            readings = mapper.allReadings
                            peak = mapper.estimatedPeak()
                        } label: {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                Text("ar.mark")
                            }
                            .font(.headline)
                            .foregroundStyle(DesignSystem.Colors.Rescuer.onSignal)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: DesignSystem.HitTarget.rescuerMin)
                            .background(DesignSystem.Colors.Rescuer.signal)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.button))
                        }
                    }
                    .padding(DesignSystem.Spacing.screenInset)
                }
            }
            .navigationTitle("hc.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DesignSystem.Colors.Rescuer.textSecondary)
                    }
                }
            }
        }
        .onAppear {
            mapper.addReading(position: Point3D(x: 0, y: 0, z: 0), snrDb: beacon.lastSNR)
            readings = mapper.allReadings
            peak = mapper.estimatedPeak()
        }
    }
}

private struct GridShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 30
        var x = step
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            x += step
        }
        var y = step
        while y < rect.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += step
        }
        return path
    }
}
