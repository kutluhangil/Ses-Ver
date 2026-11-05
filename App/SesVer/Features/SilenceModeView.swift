import SwiftUI
import DesignSystem

public struct SilenceModeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var timeRemaining = 60
    @State private var whistlesHeard = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.Rescuer.bg.ignoresSafeArea()

                VStack(spacing: DesignSystem.Spacing.xl) {
                    Spacer()

                    // 60 sn Geri Sayım
                    VStack(spacing: DesignSystem.Spacing.s) {
                        Text(String(format: NSLocalizedString("silence.countdown", comment: ""), timeRemaining))
                            .font(.system(size: 72, weight: .bold, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.Rescuer.signal)

                        Text("silence.title")
                            .font(.title2.bold())
                            .foregroundStyle(DesignSystem.Colors.Rescuer.text)
                    }

                    // Canlı Durum
                    VStack(spacing: DesignSystem.Spacing.m) {
                        if whistlesHeard > 0 {
                            Text(String(format: NSLocalizedString("silence.heard", comment: ""), whistlesHeard))
                                .font(.title3.weight(.medium))
                                .foregroundStyle(DesignSystem.Colors.Rescuer.signal)
                        } else {
                            Text("silence.none")
                                .font(.subheadline)
                                .foregroundStyle(DesignSystem.Colors.Rescuer.textSecondary)
                        }
                    }
                    .padding(DesignSystem.Spacing.l)
                    .frame(maxWidth: .infinity)
                    .background(DesignSystem.Colors.Rescuer.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text("silence.end")
                            .font(.headline)
                            .foregroundStyle(DesignSystem.Colors.Rescuer.text)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: DesignSystem.HitTarget.rescuerMin)
                            .background(DesignSystem.Colors.Rescuer.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.button))
                    }
                }
                .padding(DesignSystem.Spacing.screenInset)
            }
            .onReceive(timer) { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                }
            }
        }
    }
}
