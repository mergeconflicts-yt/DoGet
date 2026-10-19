import Foundation

// MARK: - Snapshot (IMPLEMENTATION §4)

public struct Snapshot: Equatable, Sendable {
    public var wins: Int
    public var misses: Int
    public var dayIndex: Int
    public var daysLeft: Int
    public var need: Int
    public var missesAllowed: Int
    public var todayValue: Double
    public var todayWon: Bool
    public var todayRatio: Double // capped 0.999
    public var outOfReach: Bool
    public var extendBy: Int
    public var streakBrokenOnDay: Int? // 1-based
    public var done: Bool
    public var base: Double
    public var layer: Double
    public var endDate: DayKey?
    public var moneyEarned: Decimal
    public var moneyLeft: Decimal
    public var perWin: Decimal // money per win, or item per-win savings
    public var best: Double = 0 // best single-day/run value (One time hero, P08)

    public var streakBroken: Bool { streakBrokenOnDay != nil }
}

public enum Engine {
    /// - Parameters:
    ///   - best: best single-day/run value so far (One time).
    ///   - now: current time; calendar: current calendar (injected for determinism).
    public static func snapshot(
        challenge c: Challenge,
        days: [DayResult],
        best: Double = 0,
        now: Date,
        calendar: Calendar
    ) -> Snapshot {
        // 1. Today + dayIndex (calendar only — winning never moves it, A24).
        let today = DayKey.from(date: now, calendar: calendar)
        let dayIndex = max(0, c.start.days(to: today))

        // 2. Merge duplicate days: keep higher value.
        var merged: [String: DayResult] = [:]
        for d in days {
            if d.date > today { continue } // ignore future-dated (device moved back)
            if let old = merged[d.date.key] {
                if d.value > old.value { merged[d.date.key] = d }
            } else {
                merged[d.date.key] = d
            }
        }
        func isWin(_ v: Double) -> Bool { v >= c.target }

        // Window length.
        let window: Int? = {
            switch c.type {
            case .flex: return c.y
            case .streak: return c.x
            case .once, .open: return nil
            }
        }()

        // 4. Past days: start ..< today, capped to window.
        var wins = 0, misses = 0
        var brokenDay: Int?
        let pastCount: Int = {
            if let w = window { return min(max(0, dayIndex), w) }
            return max(0, dayIndex)
        }()
        for i in 0..<pastCount {
            let key = c.start.adding(days: i)
            if let r = merged[key.key] {
                if isWin(r.value) { wins += 1 }
                else {
                    // Past day below target = miss (today handled separately).
                    misses += 1
                    if c.type == .streak, brokenDay == nil {
                        // Only counts if streak wasn't already complete at that point.
                        // Streak completes after x wins in a row; a miss before that breaks it.
                        brokenDay = i + 1
                    }
                }
            } else {
                misses += 1
                if c.type == .streak, brokenDay == nil { brokenDay = i + 1 }
            }
        }
        // If streak reached x wins with no miss, it isn't broken.
        if c.type == .streak, wins >= c.x { brokenDay = nil }

        // 5. Today.
        let todayInWindow: Bool = {
            if let w = window { return dayIndex < w }
            return true
        }()
        let todayValue = merged[today.key]?.value ?? 0
        let todayWon = todayInWindow && isWin(todayValue)
        if todayWon { wins += 1 }
        let todayRatio = c.target > 0 ? min(todayValue / c.target, 0.999) : 0

        // For streak: a miss today also breaks (today is neither win nor miss until
        // won or ended per SPEC — but a past-day miss breaks; today below target
        // does NOT break yet). So no brokenDay from today.

        // 6. Done.
        let done: Bool = {
            switch c.type {
            case .flex, .streak: return wins >= c.x
            case .once: return best >= c.target
            case .open:
                if c.reward.kind == .money, c.reward.payout == .jar {
                    return c.reward.amount * Decimal(wins) >= c.reward.jarTarget
                }
                return c.closed
            }
        }()

        // 7. Need + reach (flexible, not done).
        var need = 0, daysLeft = 0, outOfReach = false, extendBy = 0, missesAllowed = 0
        if c.type == .flex, !done {
            need = max(0, c.x - wins)
            let after = max(0, c.y - dayIndex - 1)
            daysLeft = after + ((todayInWindow && !todayWon) ? 1 : 0)
            outOfReach = need > daysLeft
            extendBy = outOfReach ? (need - daysLeft) : 0
            missesAllowed = max(0, daysLeft - need)
        } else if c.type == .streak, !done {
            need = max(0, c.x - wins)
        } else if c.type == .flex, done {
            need = 0; daysLeft = 0; missesAllowed = 0
        }

        // Broken streak flag: not done + has a broken day.
        var broken: Int? = nil
        if c.type == .streak, !done { broken = brokenDay }

        // 8. Progress (SPEC §6).
        var base = 0.0, layer = 0.0
        if done { base = 1; layer = 0 }
        else {
            switch c.type {
            case .flex, .streak:
                base = c.x > 0 ? Double(wins) / Double(c.x) : 0
                layer = c.x > 0 ? todayRatio / Double(c.x) : 0
            case .once:
                base = c.target > 0 ? min(best / c.target, 1) : 0
                layer = 0
            case .open:
                if c.reward.kind == .money, c.reward.payout == .jar, c.reward.jarTarget > 0 {
                    let t = (c.reward.jarTarget as NSDecimalNumber).doubleValue
                    let a = (c.reward.amount as NSDecimalNumber).doubleValue
                    base = min(a * Double(wins) / t, 1)
                    layer = todayRatio * a / t
                } else {
                    base = 0; layer = todayRatio
                }
            }
        }
        // Layer hidden when today won / done / OOR / broken / outside window.
        if todayWon || done || outOfReach || broken != nil || !todayInWindow { layer = 0 }

        // 10. End date.
        let endDate: DayKey? = {
            switch c.type {
            case .flex: return c.start.adding(days: c.y - 1)
            case .streak:
                if broken != nil || done { return done ? nil : nil }
                // not broken, not done: today + (need-1), or + need if today won
                let n = need
                if todayWon { return today.adding(days: n) }
                return today.adding(days: max(0, n - 1))
            case .once, .open: return nil
            }
        }()

        // 9+11. Money + perWin.
        let claimed = c.claimed && done
        var earned: Decimal = 0, left: Decimal = 0, perWin: Decimal = 0
        let r = c.reward
        if r.kind == .money {
            switch r.payout {
            case .each:
                earned = r.amount * Decimal(wins)
                left = c.type == .open ? 0 : r.amount * Decimal(max(0, c.x - wins))
                perWin = r.amount
            case .bonus:
                earned = r.amount * Decimal(wins) + (claimed ? r.bonus : 0)
                left = c.type == .open ? r.bonus : r.amount * Decimal(max(0, c.x - wins)) + (claimed ? 0 : r.bonus)
                perWin = r.amount
            case .end:
                earned = claimed ? r.amount : 0
                left = claimed ? 0 : r.amount
                perWin = 0
            case .jar:
                earned = claimed ? r.jarTarget : 0
                left = claimed ? 0 : r.jarTarget
                perWin = r.amount
            }
        } else {
            // Item: engine money is 0; savings tracked via Derive.
            earned = 0; left = 0
            if r.itemPayout == .save, c.x > 0, r.value > 0 {
                perWin = Derive.itemPerWin(value: r.value, x: c.x)
            }
        }

        // Streak endDate when done: SPEC P-states show DONE; keep nil.
        return Snapshot(wins: wins, misses: misses, dayIndex: dayIndex, daysLeft: daysLeft,
                        need: need, missesAllowed: missesAllowed,
                        todayValue: todayValue, todayWon: todayWon, todayRatio: todayRatio,
                        outOfReach: outOfReach, extendBy: extendBy,
                        streakBrokenOnDay: broken, done: done,
                        base: base, layer: layer, endDate: endDate,
                        moneyEarned: earned, moneyLeft: left, perWin: perWin,
                        best: best)
    }
}
