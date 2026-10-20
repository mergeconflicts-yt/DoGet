import SwiftUI
import UIKit

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
    public static var orange: Color { color(for: "orange") }
    public static var pink: Color { color(for: "pink") }
    public static var green: Color { color(for: "green") }
    public static var blue: Color { color(for: "blue") }
    public static var violet: Color { color(for: "violet") }
    public static var teal: Color { color(for: "teal") }
    public static var amber: Color { color(for: "amber") }
    public static let text2 = Color(red: 0.36, green: 0.38, blue: 0.43)
    public static let text3 = Color(red: 0.48, green: 0.50, blue: 0.55)
    public static let bg = Color(red: 0.957, green: 0.957, blue: 0.965)
    public static let surface = Color.white
    public static let hairline = Color(red: 0.933, green: 0.937, blue: 0.949)
    public static let chipBg = Color(red: 0.941, green: 0.945, blue: 0.953)
    public static let danger = Color(red: 0.898, green: 0.282, blue: 0.302)
    public static let success = Color(red: 0.075, green: 0.70, blue: 0.42)
    /// Sheet scrim (DESIGN §5) and card shadows.
    public static let scrim = Color.black.opacity(0.3)
    public static let shadow = Color.black
    /// Confetti yellow (DESIGN §6).
    public static let confettiYellow = Color(red: 1.0, green: 0.83, blue: 0.0)
    /// Welcome/onboarding surfaces (onboarding brief).
    public static let orangeTint = Color(red: 1.0, green: 0.93, blue: 0.89)
    public static let healthRed = Color(red: 1.0, green: 0.18, blue: 0.33)
    public static let healthRedLight = Color(red: 1.0, green: 0.26, blue: 0.40)
    public static let wondayTileBg = Color(red: 1.0, green: 0.93, blue: 0.87)
    public static let healthCardBg = Color(red: 0.96, green: 0.96, blue: 0.97)

    /// tint = C at 12–14% over white.
    public static func tint(_ token: String) -> Color { color(for: token).opacity(0.13) }
}

// DESIGN §2 — typography.
//
// Dynamic Type (AGENTS §3.8): every size goes through UIFontMetrics so text
// grows with the system setting. The cap keeps the biggest hero numbers
// readable at AX3 instead of letting them overflow their block.
public enum FillFont {
    @MainActor public static func scaled(_ size: CGFloat, weight: Font.Weight = .regular,
                                         relativeTo style: UIFont.TextStyle = .body) -> Font {
        let value = UIFontMetrics(forTextStyle: style).scaledValue(for: size)
        return .system(size: min(value, size * 2.0), weight: weight)
    }

    @MainActor public static func hero(_ long: Bool = false) -> Font {
        scaled(long ? 62 : 92, weight: .heavy, relativeTo: .largeTitle)
    }
    @MainActor public static var heroUnit: Font { scaled(15, weight: .semibold) }
    @MainActor public static var remaining: Font { scaled(21, weight: .heavy) }
    @MainActor public static var pageTitle: Font { scaled(30, weight: .heavy, relativeTo: .title1) }
    @MainActor public static var overviewTitle: Font { scaled(46, weight: .black, relativeTo: .largeTitle) }
    @MainActor public static var sentence: Font { scaled(33, weight: .heavy, relativeTo: .title1) }
    @MainActor public static var panelTitle: Font { scaled(26, weight: .heavy, relativeTo: .title2) }
    @MainActor public static var onbTitle: Font { scaled(38, weight: .black, relativeTo: .largeTitle) }
    @MainActor public static var welcomeTitle: Font { scaled(45, weight: .black, relativeTo: .largeTitle) }
    @MainActor public static var footValue: Font { scaled(24, weight: .heavy) }
    @MainActor public static var celebrateValue: Font { scaled(52, weight: .heavy, relativeTo: .largeTitle) }
    @MainActor public static func mono(_ size: CGFloat = 11) -> Font {
        scaled(size, weight: .bold, relativeTo: .caption1).monospaced()
    }
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
