import Foundation

public enum Derive {
    // MARK: - Item save (SPEC §5): per = value ÷ x rounded whole; last win saves remainder.
    public static func itemPerWin(value: Decimal, x: Int) -> Decimal {
        guard x > 0, value > 0 else { return 0 }
        var per = value / Decimal(x)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &per, 0, .plain) // half up
        return max(0, rounded)
    }

    public static func itemSaved(value: Decimal, x: Int, wins: Int) -> Decimal {
        guard x > 0, value > 0 else { return 0 }
        if wins <= 0 { return 0 }
        if wins >= x { return value }
        // Rounding up per win can pass the price before the last win. Never
        // save more than the item is worth (the footer used to show a
        // negative NEXT WIN).
        return min(value, itemPerWin(value: value, x: x) * Decimal(wins))
    }

    /// NEXT WIN footer for item save: saved(w+1) - saved(w), never negative.
    public static func itemNextWin(value: Decimal, x: Int, wins: Int) -> Decimal {
        max(0, itemSaved(value: value, x: x, wins: wins + 1)
             - itemSaved(value: value, x: x, wins: wins))
    }

    // MARK: - Reward phrase (SPEC §5)
    public static func rewardPhrase(_ r: Reward, x: Int = 0) -> String {
        switch r.kind {
        case .money:
            switch r.payout {
            case .each:
                return "\(Format.money(r.amount, currency: r.currency)) each time"
            case .end:
                return "\(Format.money(r.amount, currency: r.currency)) at the end"
            case .bonus:
                return "\(Format.money(r.amount, currency: r.currency)) each time + \(Format.money(r.bonus, currency: r.currency)) at the end"
            case .jar:
                return "a jar that opens at \(Format.money(r.jarTarget, currency: r.currency))"
            }
        case .item:
            let name = r.name.trimmingCharacters(in: .whitespaces)
            let base: String = {
                switch r.category {
                case .trip:
                    return name.isEmpty ? "a trip" : "a trip to \(name)"
                case .food:
                    return name.isEmpty ? "a treat" : "a treat: \(name)"
                case .item:
                    return name.isEmpty ? "an item" : aAn(name)
                case .other:
                    // Other rewards are already proper names ("Concert"), so no article.
                    return name
                }
            }()
            let worth: String = r.value > 0
                ? " worth \(Format.money(r.value, currency: r.currency))" : ""
            if r.itemPayout == .save, r.value > 0, x > 0 {
                let per = Format.money(itemPerWin(value: r.value, x: x), currency: r.currency)
                return "\(base)\(worth), \(per) a win"
            }
            return "\(base)\(worth)"
        }
    }

    private static func startsWithVowel(_ s: String) -> Bool {
        guard let f = s.trimmingCharacters(in: .whitespaces).first else { return false }
        return "aeiouAEIOU".contains(f)
    }

    public static func aAn(_ name: String) -> String {
        "\(startsWithVowel(name) ? "an" : "a") \(name)"
    }

    public static func typeName(_ t: ChallengeType) -> String {
        switch t {
        case .flex: return "Flexible"
        case .streak: return "Streak"
        case .once: return "One time"
        case .open: return "No end"
        }
    }

    // MARK: - Level up (SPEC §6, A28–A31)
    /// Returns the next challenge, or nil when level up is not offered
    /// (No end, or rings already at 3). `today` is passed in because Domain
    /// never reads the clock.
    public static func levelUp(_ c: Challenge, today: DayKey) -> Challenge? {
        guard c.type != .open else { return nil }
        if c.metric == .rings, c.target >= 3 { return nil }

        let newTarget: Double = {
            switch c.metric {
            case .rings:
                return min(3, c.target + 1)
            case .run, .sleep:
                return (c.target * 1.1 * 10).rounded() / 10
            default:
                if c.target < 100 {
                    return c.target + max(1, (c.target * 0.1).rounded())
                }
                return (c.target * 1.1 / 500).rounded() * 500
            }
        }()

        return Challenge(
            id: UUID(),
            name: "\(c.name) · Level \(c.level + 1)",
            colorToken: ChallengePalette.next(after: c.colorToken),
            metric: c.metric,
            target: newTarget,
            type: c.type,
            x: c.x,
            y: c.y,
            start: today,
            reward: c.reward,
            level: c.level + 1
        )
    }

    /// Rescue → Extend: the only place allowed to change the window.
    public static func extended(_ c: Challenge, by days: Int) -> Challenge {
        var out = c
        out.y = max(c.y, c.y + days)
        return out
    }

    /// Rescue → Switch to flexible after a broken streak (A11): keep the wins,
    /// give the challenge five extra days.
    public static func switchedToFlex(_ c: Challenge) -> Challenge {
        var out = c
        out.type = .flex
        out.x = max(1, c.x)
        out.y = c.x + 5
        return out
    }

    // MARK: - Create validation (SPEC §7.6)
    public struct Draft: Equatable, Sendable {
        public var metric: Metric?
        public var target: Double?
        public var type: ChallengeType?
        public var x: Int?
        public var y: Int?
        // reward
        public var rewardKind: RewardKind?
        public var moneyPayout: MoneyPayout?
        public var amount: Decimal?
        public var bonus: Decimal?
        public var jarTarget: Decimal?
        public var itemCategory: RewardCategory?
        public var itemName: String?
        public var itemValue: Decimal?
        public var itemPayout: ItemPayout?
        public init() {}
    }

    /// Returns the first problem message, or nil when valid.
    /// Order per SPEC §7.6: blanks, reward, target, wins ≤ days, amount, jar.
    public static func validate(_ d: Draft) -> String? {
        if d.metric == nil || d.type == nil || d.rewardKind == nil {
            return Copy.fillBlanks(blanksLeft(d))
        }

        // 2. Reward (name for an item, amount for money). SPEC §7.6 checks
        // the reward before the target.
        if d.rewardKind == .item,
           (d.itemName ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
            return Copy.validationName()
        }
        if d.rewardKind == .money, (d.amount ?? 0) <= 0 {
            return Copy.validationAmount
        }

        // 3. Target.
        guard let m = d.metric, let t = d.target, t > 0 else {
            return Copy.validationTarget
        }
        if m == .rings, (t < 1 || t > 3) { return Copy.validationRings() }

        // 4. Wins fit in the days.
        if d.type == .flex {
            if d.x == nil || d.y == nil { return Copy.validationWinsDays }
            if let x = d.x, let y = d.y, x > y { return Copy.validationWinsFit }
        }
        if d.type == .streak, d.x == nil { return Copy.validationWinsDays }

        // 5. Amount was checked with the reward (step 2).

        // 6. Jar bigger than the amount.
        if d.rewardKind == .money, d.moneyPayout == .jar,
           (d.jarTarget ?? 0) <= (d.amount ?? 0) {
            return Copy.validationJar
        }
        return nil
    }

    private static func blanksLeft(_ d: Draft) -> Int {
        var n = 0
        if d.metric == nil { n += 1 }
        if d.type == nil { n += 1 }
        if d.rewardKind == nil { n += 1 }
        return n
    }
}
