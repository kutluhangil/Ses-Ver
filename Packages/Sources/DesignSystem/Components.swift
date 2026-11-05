import SwiftUI

/// Kurban ekranı birincil eylem düğmesi (min 60 pt yükseklik, OLED uyumlu).
public struct VictimPrimaryButton: View {
    public let titleKey: LocalizedStringKey
    public let icon: String?
    public let role: ButtonRole?
    public let action: @Sendable () -> Void

    public init(
        _ titleKey: LocalizedStringKey,
        icon: String? = nil,
        role: ButtonRole? = nil,
        action: @escaping @Sendable () -> Void
    ) {
        self.titleKey = titleKey
        self.icon = icon
        self.role = role
        self.action = action
    }

    public var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: DesignSystem.Spacing.m) {
                if let icon {
                    Image(systemName: icon)
                        .font(.title2.bold())
                }
                Text(titleKey)
                    .font(.title3.bold())
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: DesignSystem.HitTarget.victimMin)
            .background(role == .destructive ? DesignSystem.Colors.Victim.stop : DesignSystem.Colors.Victim.signal)
            .foregroundStyle(role == .destructive ? .white : DesignSystem.Colors.Victim.onSignal)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Durum çipi (Ses, Pil, Yedek zincir vb.).
public struct StatusChip: View {
    public let icon: String
    public let text: String
    public let isWarning: Bool

    public init(icon: String, text: String, isWarning: Bool = false) {
        self.icon = icon
        self.text = text
        self.isWarning = isWarning
    }

    public var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.footnote.bold())
            Text(text)
                .font(.footnote.weight(.semibold).monospacedDigit())
        }
        .padding(.horizontal, DesignSystem.Spacing.m)
        .padding(.vertical, DesignSystem.Spacing.s)
        .background(DesignSystem.Colors.Victim.surface)
        .foregroundStyle(isWarning ? DesignSystem.Colors.Victim.stop : DesignSystem.Colors.Victim.text)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.chip)
                .stroke(isWarning ? DesignSystem.Colors.Victim.stop : DesignSystem.Colors.Victim.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.chip, style: .continuous))
    }
}

/// Yanlışlıkla durdurmayı önleyen 3 saniyelik basılı tutma düğmesi.
public struct HoldToStopButton: View {
    public let onTrigger: @Sendable () -> Void

    @State private var progress: Double = 0.0
    @State private var isPressing = false

    public init(onTrigger: @escaping @Sendable () -> Void) {
        self.onTrigger = onTrigger
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.button)
                .fill(DesignSystem.Colors.Victim.surface)
                .frame(minHeight: DesignSystem.HitTarget.victimMin)

            // İlerleme dolgusu
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: DesignSystem.Radius.button)
                    .fill(DesignSystem.Colors.Victim.stop.opacity(0.35))
                    .frame(width: geo.size.width * CGFloat(progress))
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.button))

            HStack(spacing: DesignSystem.Spacing.s) {
                Image(systemName: "stop.circle.fill")
                    .font(.title3)
                Text("beacon.stop")
                    .font(.body.weight(.medium))
            }
            .foregroundStyle(DesignSystem.Colors.Victim.stop)
        }
        .frame(minHeight: DesignSystem.HitTarget.victimMin)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.button)
                .stroke(DesignSystem.Colors.Victim.stop.opacity(0.5), lineWidth: 1)
        )
        .onLongPressGesture(minimumDuration: 3.0, maximumDistance: 50) {
            progress = 0.0
            isPressing = false
            onTrigger()
        } onPressingChanged: { pressing in
            isPressing = pressing
            withAnimation(.linear(duration: pressing ? 3.0 : 0.2)) {
                progress = pressing ? 1.0 : 0.0
            }
        }
    }
}

/// "Buradayım" yaşam belirtisi düğmesi.
public struct HereButton: View {
    public let lastTouchDescription: String
    public let onTouch: @Sendable () -> Void

    public init(lastTouchDescription: String, onTouch: @escaping @Sendable () -> Void) {
        self.lastTouchDescription = lastTouchDescription
        self.onTouch = onTouch
    }

    public var body: some View {
        Button(action: onTouch) {
            VStack(spacing: DesignSystem.Spacing.s) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 44, weight: .bold))
                Text("beacon.here.title")
                    .font(.title.bold())
                Text(lastTouchDescription)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(DesignSystem.Colors.Victim.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.xl)
            .background(DesignSystem.Colors.Victim.surface)
            .foregroundStyle(DesignSystem.Colors.Victim.signal)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .stroke(DesignSystem.Colors.Victim.border, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
