import SwiftUI

// DESIGN §1 — color tokens. No hex values outside this file (AGENTS §7).
public enum FillColor {
    public static let palette: [String] = ["orange", "pink", "green", "blue", "violet", "teal", "amber", "ink"]
    public static func color(for token: String) -> Color {
        switch token {
        case "orange": return Color(red: 1.0, green: 0.42, blue: 0.10)      // #FF6B1A
        case "pink": return Color(red: 1.0, green: 0.18, blue: 0.44)        // #FF2D6F
        case "green": return Color(red: 0.08, green: 0.66, blue: 0.40)      // #13A866
        case "blue": return Color(red: 0.18, green: 0.36, blue: 1.0)        // #2F5BFF
        case "violet": return Color(red: 0.48, green: 0.36, blue: 1.0)      // #7A5CFF
        case "teal": return Color(red: 0.0, green: 0.64, blue: 0.74)        // #00A3BC
        case "amber": return Color(red: 0.85, green: 0.57, blue: 0.0)       // #D99100
        case "ink": return Color(red: 0.07, green: 0.07, blue: 0.09)        // #111216
        default: return Color(red: 1.0, green: 0.42, blue: 0.10)
        }
    }
    public static let ink = Color(red: 0.07, green: 0.07, blue: 0.09)
    public static let text2 = Color(red: 0.36, green: 0.38, blue: 0.43)
    public static let text3 = Color(red: 0.48, green: 0.50, blue: 0.55)
    public static let bg = Color(red: 0.957, green: 0.957, blue: 0.965)
    public static let surface = Color.white
    public static let hairline = Color(red: 0.933, green: 0.937, blue: 0.949)
    public static let chipBg = Color(red: 0.941, green: 0.945, blue: 0.953)
    public static let danger = Color(red: 0.898, green: 0.282, blue: 0.302)
    public static let success = Color(red: 0.075, green: 0.70, blue: 0.42)

    /// tint = C at 12–14% over white.
    public static func tint(_ token: String) -> Color { color(for: token).opacity(0.13) }
}

// DESIGN §2 — typography.
public enum FillFont {
    public static func hero(_ long: Bool = false) -> Font { .system(size: long ? 62 : 92, weight: .heavy, design: .default) }
    public static let heroUnit = Font.system(size: 15, weight: .semibold)
    public static let remaining = Font.system(size: 21, weight: .heavy)
    public static let pageTitle = Font.system(size: 30, weight: .heavy)
    public static let overviewTitle = Font.system(size: 46, weight: .black)
    public static let sentence = Font.system(size: 33, weight: .heavy)
    public static let panelTitle = Font.system(size: 26, weight: .heavy)
    public static let onbTitle = Font.system(size: 38, weight: .black)
    public static let welcomeTitle = Font.system(size: 45, weight: .black)
    public static let footValue = Font.system(size: 24, weight: .heavy)
    public static let celebrateValue = Font.system(size: 52, weight: .heavy)
    public static func mono(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .bold, design: .monospaced) }
}

public enum FillMetricIcon {
    public static func symbol(for metric: String) -> String {
        switch metric {
        case "steps": return "figure.walk"
        case "rings": return "circle.circle"
        case "exercise": return "bolt.fill"
        case "run": return "figure.run"
        case "sleep": return "moon.fill"
        case "calories": return "flame.fill"
        default: return "figure.walk"
        }
    }
}
