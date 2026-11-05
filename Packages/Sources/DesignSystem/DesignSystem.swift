import SwiftUI

/// Ses Ver Tasarım Sistemi Token'ları ve Bileşenleri (docs/design/tokens.json).
public enum DesignSystem {
    public enum Colors {
        public enum Victim {
            public static let bg = Color(hex: "000000")
            public static let surface = Color(hex: "1F1C18")
            public static let surfaceAlt = Color(hex: "14120F")
            public static let border = Color(hex: "34302A")
            public static let text = Color(hex: "F4EFE6")
            public static let textSecondary = Color(hex: "B3ADA2")
            public static let signal = Color(hex: "FFB23E")
            public static let onSignal = Color(hex: "1A1100")
            public static let stop = Color(hex: "FF7A6B")
        }

        public enum Rescuer {
            public static let bg = Color(hex: "0E1114")
            public static let surface = Color(hex: "171C21")
            public static let surfaceAlt = Color(hex: "20262D")
            public static let border = Color(hex: "323A44")
            public static let text = Color(hex: "EEF2F5")
            public static let textSecondary = Color(hex: "A2ADB9")
            public static let signal = Color(hex: "FFB23E")
            public static let onSignal = Color(hex: "1A1100")
            public static let stop = Color(hex: "FF7A6B")
        }
    }

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
        public static let screenInset: CGFloat = 24
    }

    public enum Radius {
        public static let chip: CGFloat = 12
        public static let control: CGFloat = 16
        public static let card: CGFloat = 20
        public static let button: CGFloat = 22
        public static let sheet: CGFloat = 28
    }

    public enum HitTarget {
        public static let victimMin: CGFloat = 60
        public static let rescuerMin: CGFloat = 56
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
