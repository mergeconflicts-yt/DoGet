import Foundation

public enum Derive {
    // MARK: - Item save (SPEC §5): per = value ÷ x rounded whole; last win saves remainder.
    public static func itemPerWin(value: Decimal, x: Int) -> Decimal {
        guard x > 0 else { return 0 }
        var per = value / Decimal(x)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &per, 0, .plain) // half up
        return rounded
    }

    public static func itemSaved(value: Decimal, x: Int, wins: Int) -> Decimal {
        guard x > 0, value > 0 else { return 0 }
        if wins >= x { return value }
        if wins <= 0 { return 0 }
        return itemPerWin(value: value, x: x) * Decimal(wins)
    }

    /// NEXT WIN footer for item save: saved(w+1) - saved(w).
    public static func itemNextWin(value: Decimal, x: Int, wins: Int) -> Decimal {
        itemSaved(value: value, x: x, wins: wins + 1) - itemSaved(value: value, x: x, wins: wins)
    }

    // MARK: - Reward phrase (SPEC §5)
    public static func rewardPhrase(_ r: Reward, x: Int = 0) -> String {
        let worth: String = r.kind == .item && r.value > 0
            ? " worth \(Format.money(r.value, currency: r.currency))" : ""
        switch r.kind {
        case .money:
            switch r.payout {
            case .each: return "\(Format.money(r.amount, currency: r.currency)) a win"
            case .end: return Format.money(r.amount, currency: r.currency)
            case .bonus: return "\(Format.money(r.amount, currency: r.currency)) a win + \(Format.money(r.bonus, currency: r.currency)) bonus"
            case .jar: return "jar opens at \(Format.money(r.jarTarget, currency: r.currency))"
            }
        case .item:
            let article = startsWithVowel(r.name) ? "an" : "a"
            let cat: String = {
                switch r.category {
                case .trip: return "trip to \(r.name)"
                case .food: return r.name
                case .item: return r.name
                case .other: return r.name
                }
            }()
            if r.itemPayout == .save, r.value > 0, x > 0 {
                return "\(article) \(cat)\(worth), \(Format.money(itemPerWin(value: r.value, x: x), currency: r.currency)) a win"
            }
            return "\(article) \(cat)\(worth)"
        }
    }

    private static func startsWithVowel(_ s: String) -> Bool {
        guard let f = s.trimmingCharacters(in: .whitespaces).first else { return false }
        return "aeiouAEIOU".contains(f)
    }

    public static func aAn(_ name: String) -> String {
        "\(startsWithVowel(name) ? "an" : "a") \(name)"
    }

    // MARK: - Create validation (SPEC §7.6, order: blanks, reward, target, wins≤days, amount, jar>amount)
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
    public static func validate(_ d: Draft) -> String? {
        if d.metric == nil || d.type == nil || d.rewardKind == nil { return "Fill in \(blanksLeft(d)) blank\(blanksLeft(d) == 1 ? "" : "s")" }
        if let m = d.metric, let t = d.target {
            if t <= 0 { return "Set a target" }
            if m == .rings, (t < 1 || t > 3) { return "Rings target is 1 to 3" }
        } else { return "Set a target" }
        if d.type == .flex {
            if let x = d.x, let y = d.y, x > y { return "Wins must fit in the days" }
            if d.x == nil || d.y == nil { return "Set wins and days" }
        }
        if d.rewardKind == .money {
            let amt = d.amount ?? 0
            if amt <= 0 { return "Set an amount" }
            if d.moneyPayout == .jar, (d.jarTarget ?? 0) <= amt { return "Jar must be bigger" }
        } else {
            if (d.itemName ?? "").trimmingCharacters(in: .whitespaces).isEmpty { return "Name your reward" }
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
