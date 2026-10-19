import Foundation
import Observation

// SPEC §7.6 — Create draft logic (no UI imports; unit tested).
// Blanks fill strictly in order: 0 what you'll do, 1 how often, 2 reward.
@Observable @MainActor
public final class CreateModel {
    public var draft = Derive.Draft()
    public var filled: Set<Int> = [] // 0 what, 1 how often, 2 reward
    public var openPanel: Int? = nil
    public var hint: String? = nil
    /// Blank that shakes after tapping a locked blank (C02).
    public var shakeBlank: Int? = nil
    public var name: String = ""
    public var colorToken: String = "green"
    public var target: Double = 10_000
    public var metric: Metric = .steps
    /// H05: no stand-hour samples in 7 days → Rings disabled (manual mode exempt).
    public var noWatch = false

    public var factsEnds: String = "—"
    public var factsMisses: String = "—"
    public var factsMax: String = "—"

    public init() {
        // Defaults mirror the What panel's pre-selected state: without this,
        // Done on blank 0 with no chip tap fills the blank while draft.metric
        // stays nil, and the button keeps saying "Fill in 1 blank".
        draft.metric = .steps
        draft.target = 10_000
        // Money is the default reward kind.
        draft.rewardKind = .money
        draft.moneyPayout = .each
    }

    public func tapBlank(_ i: Int) {
        // Order lock: earlier blanks first (C02).
        for j in 0..<i where !filled.contains(j) {
            hint = "First set \"\(blankName(j))\"."
            shakeBlank = j
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                if shakeBlank == j { shakeBlank = nil }
            }
            return
        }
        hint = nil
        openPanel = i
    }
    public func blankName(_ i: Int) -> String {
        ["what you'll do", "how often", "your reward"][i]
    }
    public func done(_ i: Int) {
        // Don't mark a blank filled when its draft section is still empty
        // (e.g. Done with no tile/chip tap). Otherwise filled.count hits 3
        // while Derive.validate still reports "Fill in 1 blank".
        switch i {
        case 0:
            guard draft.metric != nil else { hint = "Pick what you'll do."; return }
        case 1:
            guard draft.type != nil else { hint = "Pick how often."; return }
        case 2:
            guard draft.rewardKind != nil else { hint = "Pick your reward."; return }
        default: break
        }
        filled.insert(i)
        openPanel = nil
        hint = nil
        refreshFacts()
        // Open next unfilled after 0.38s.
        let next = (0..<3).first { !filled.contains($0) }
        if let next {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.38))
                openPanel = next
            }
        }
    }
    public var buttonText: String {
        if filled.count < 3 { return "Fill in \(3 - filled.count) blank\(3 - filled.count == 1 ? "" : "s")" }
        return Derive.validate(draft) ?? "Start challenge"
    }
    public var valid: Bool { filled.count == 3 && Derive.validate(draft) == nil }
    /// Non-nil when the main button can't start: shown as a toast on tap.
    public var problem: String? {
        if filled.count < 3 { return buttonText }
        return Derive.validate(draft)
    }
    /// Auto name (SPEC §7.6): the item name, or "{target}{unit}".
    public var autoName: String {
        if let iname = draft.itemName, !iname.trimmingCharacters(in: .whitespaces).isEmpty {
            return iname
        }
        return MetricDefaults.autoName(target: target, metric: metric)
    }

    /// SPEC §7.6 facts row. Called whenever the draft changes.
    public func refreshFacts() {
        let today = DayKey.from(date: Date(), calendar: .current)
        switch draft.type {
        case .flex:
            if let y = draft.y {
                factsEnds = Format.date(today.adding(days: y - 1))
                if let x = draft.x { factsMisses = "\(max(0, y - x))" }
            }
        case .streak:
            if let x = draft.x {
                factsEnds = Format.date(today.adding(days: x - 1)); factsMisses = "0"
            }
        case .once: factsEnds = "Any day"; factsMisses = "—"
        case .open: factsEnds = "Never"; factsMisses = "—"
        case nil: factsEnds = "—"; factsMisses = "—"
        }
        // MOST YOU CAN WIN needs how-often + reward.
        if draft.type != nil, draft.rewardKind != nil {
            if draft.rewardKind == .money {
                let a = draft.amount ?? 0
                switch draft.moneyPayout {
                case .each: factsMax = Format.money(a * Decimal(draft.x ?? 0))
                case .bonus: factsMax = Format.money(a * Decimal(draft.x ?? 0) + (draft.bonus ?? 0))
                case .end: factsMax = Format.money(a)
                case .jar: factsMax = Format.money(draft.jarTarget ?? 0)
                case nil: factsMax = "—"
                }
            } else if let iname = draft.itemName, !iname.trimmingCharacters(in: .whitespaces).isEmpty {
                let v = draft.itemValue ?? 0
                factsMax = v > 0 ? "\(iname) · \(Format.money(v))" : iname
            } else { factsMax = "—" }
        } else { factsMax = "—" }
    }

    /// Money payouts allowed for the chosen type (SPEC §5).
    public var allowedPayouts: [MoneyPayout] {
        switch draft.type {
        case .flex, .streak: return [.each, .end, .bonus]
        case .once: return [.end]
        case .open: return [.each, .jar]
        case nil: return [.each, .end, .bonus, .jar]
        }
    }

    /// The reward the Start button creates.
    public func buildReward() -> Reward {
        let d = draft
        if d.rewardKind == .money {
            return Reward(kind: .money, payout: d.moneyPayout ?? .each,
                          amount: d.amount ?? 0, bonus: d.bonus ?? 0,
                          jarTarget: d.jarTarget ?? 0)
        }
        return Reward(kind: .item, category: d.itemCategory ?? .other,
                      name: d.itemName ?? "", value: d.itemValue ?? 0,
                      itemPayout: d.itemPayout ?? .end)
    }
}

// MARK: - Metric defaults (SPEC §3)

public enum MetricDefaults {
    public static func target(for m: Metric) -> Double {
        switch m {
        case .steps: return 10_000
        case .rings: return 3
        case .exercise: return 30
        case .run: return 5
        case .sleep: return 8
        case .calories: return 500
        }
    }
    /// Picker label (SPEC §3): "Steps", "Close rings", …
    public static func label(for m: Metric) -> String {
        switch m {
        case .steps: return "Steps"
        case .rings: return "Close rings"
        case .exercise: return "Exercise"
        case .run: return "Run"
        case .sleep: return "Sleep"
        case .calories: return "Calories"
        }
    }
    /// Sentence suffix (SPEC §3): steps "a day", run "in one run", sleep "a night".
    public static func suffix(for m: Metric) -> String {
        switch m {
        case .steps, .rings, .exercise, .calories: return "a day"
        case .run: return "in one run"
        case .sleep: return "a night"
        }
    }
    /// Short unit for the auto name and the first-win line: "10,000 steps", "5.0 km".
    public static func unit(for m: Metric) -> String {
        switch m {
        case .steps: return "steps"
        case .rings: return "rings"
        case .exercise: return "min"
        case .run: return "km"
        case .sleep: return "hours"
        case .calories: return "kcal"
        }
    }
    /// Verb used in sentences (SPEC §3): walk, close, exercise for, run, sleep, burn.
    public static func verb(for m: Metric) -> String {
        switch m {
        case .steps: return "Walk"
        case .rings: return "Close"
        case .exercise: return "Exercise for"
        case .run: return "Run"
        case .sleep: return "Sleep"
        case .calories: return "Burn"
        }
    }
    /// "{target} {unit}" — the Create name placeholder and the auto name (SPEC §7.6).
    public static func autoName(target t: Double, metric m: Metric) -> String {
        "\(Format.metric(t, metric: m)) \(unit(for: m))"
    }
    public static func step(metric m: Metric, target t: Double, up: Bool) -> Double {
        let d: Double = {
            switch m {
            case .steps: return 500
            case .rings: return 1
            case .exercise: return 5
            case .run, .sleep: return 0.5
            case .calories: return 50
            }
        }()
        let v = t + (up ? d : -d)
        if m == .rings { return min(3, max(1, v)) } // C13: clamp 1–3
        return max(d, v)
    }
    public static func presets(for m: Metric) -> [Double] {
        switch m {
        case .steps: return [5_000, 8_000, 10_000, 12_000]
        case .rings: return [1, 2, 3]
        case .exercise: return [20, 30, 45, 60]
        case .run: return [3, 5, 10, 21.1]
        case .sleep: return [7, 7.5, 8]
        case .calories: return [300, 500, 700]
        }
    }
    public static func presetLabel(metric m: Metric, value v: Double) -> String {
        switch m {
        case .steps: return "\(Int(v / 1_000))K"
        case .run, .sleep: return Format.metric(v, metric: m)
        default: return "\(Int(v))"
        }
    }
    /// Stepper value (number only) and its unit label (mockups IMG_5621–5624).
    public static func stepperValue(target t: Double, metric m: Metric) -> String {
        Format.metric(t, metric: m)
    }
    public static func stepperUnit(metric m: Metric) -> String {
        switch m {
        case .steps: return "steps a day"
        case .rings: return "rings a day"
        case .exercise: return "min a day"
        case .run: return "km in one run"
        case .sleep: return "hours a night"
        case .calories: return "kcal a day"
        }
    }
}
