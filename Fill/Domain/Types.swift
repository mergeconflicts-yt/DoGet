import Foundation

// MARK: - Enums (raw values are what gets stored)

public enum Metric: String, Codable, Equatable, Sendable, CaseIterable {
    case steps, rings, exercise, run, sleep, calories
}

public enum ChallengeType: String, Codable, Equatable, Sendable {
    case flex, streak, once, open
}

public enum RewardKind: String, Codable, Equatable, Sendable {
    case money, item
}

public enum RewardCategory: String, Codable, Equatable, Sendable {
    case trip, food, item, other // "item" labelled Buy in UI
}

public enum MoneyPayout: String, Codable, Equatable, Sendable {
    case each, end, bonus, jar
}

public enum ItemPayout: String, Codable, Equatable, Sendable {
    case end, save
}

public enum DataSource: String, Codable, Equatable, Sendable {
    case health, motion, manual
}

// MARK: - DayKey: calendar date, no time, no zone (SPEC §2, §11)

public struct DayKey: Codable, Equatable, Sendable, Comparable, Hashable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year; self.month = month; self.day = day
    }

    public var key: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public init?(key: String) {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        self.init(year: p[0], month: p[1], day: p[2])
    }

    /// "which date is it here" from a timestamp + current calendar.
    public static func from(date: Date, calendar: Calendar) -> DayKey {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return DayKey(year: c.year ?? 2000, month: c.month ?? 1, day: c.day ?? 1)
    }

    /// Whole-day math on a fixed Gregorian UTC calendar so DST never matters (A33).
    private static var utcCal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    private func utcDate() -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        return DayKey.utcCal.date(from: c)!
    }

    private static func fromUTCDate(_ d: Date) -> DayKey {
        let c = utcCal.dateComponents([.year, .month, .day], from: d)
        return DayKey(year: c.year!, month: c.month!, day: c.day!)
    }

    public func adding(days: Int) -> DayKey {
        let d = DayKey.utcCal.date(byAdding: .day, value: days, to: utcDate())!
        return DayKey.fromUTCDate(d)
    }

    /// Whole days from self to other.
    public func days(to other: DayKey) -> Int {
        DayKey.utcCal.dateComponents([.day], from: utcDate(), to: other.utcDate()).day ?? 0
    }

    /// Midnight-to-midnight range in the given calendar (for HealthKit queries).
    public func timeRange(in calendar: Calendar) -> Range<Date> {
        var comp = DateComponents()
        comp.year = year; comp.month = month; comp.day = day
        let start = calendar.date(from: comp)!
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return start..<end
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        lhs.key < rhs.key
    }
}

// MARK: - Reward

public struct Reward: Codable, Equatable, Sendable {
    public var kind: RewardKind
    public var currency: String // INR by default
    // money
    public var payout: MoneyPayout
    public var amount: Decimal // per-win (each/bonus/jar) or total (end)
    public var bonus: Decimal
    public var jarTarget: Decimal
    // item
    public var category: RewardCategory
    public var name: String
    public var value: Decimal // 0 = no value
    public var itemPayout: ItemPayout

    public init(
        kind: RewardKind, currency: String = "INR",
        payout: MoneyPayout = .each, amount: Decimal = 0, bonus: Decimal = 0, jarTarget: Decimal = 0,
        category: RewardCategory = .other, name: String = "", value: Decimal = 0,
        itemPayout: ItemPayout = .end
    ) {
        self.kind = kind; self.currency = currency
        self.payout = payout; self.amount = amount; self.bonus = bonus; self.jarTarget = jarTarget
        self.category = category; self.name = name; self.value = value; self.itemPayout = itemPayout
    }

    public static func moneyEach(amount: Decimal, currency: String = "INR") -> Reward {
        Reward(kind: .money, currency: currency, payout: .each, amount: amount)
    }
}

// MARK: - Challenge

public struct Challenge: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var colorToken: String
    public var metric: Metric
    public var target: Double
    public var type: ChallengeType
    public var x: Int // wins needed (flex/streak); 1 once; 0 open
    public var y: Int // window (flex); == x streak; 0 once/open
    public var start: DayKey
    public var reward: Reward
    public var level: Int
    public var claimed: Bool
    public var closed: Bool // No-end item "I'm done"
    public var archived: Bool

    public init(id: UUID = UUID(), name: String, colorToken: String = "orange",
                metric: Metric, target: Double, type: ChallengeType,
                x: Int, y: Int, start: DayKey, reward: Reward,
                level: Int = 1, claimed: Bool = false, closed: Bool = false, archived: Bool = false) {
        self.id = id; self.name = name; self.colorToken = colorToken
        self.metric = metric; self.target = target; self.type = type
        self.x = x; self.y = y; self.start = start; self.reward = reward
        self.level = level; self.claimed = claimed; self.closed = closed; self.archived = archived
    }
}

// MARK: - DayResult

public struct DayResult: Codable, Equatable, Sendable {
    public var date: DayKey
    public var value: Double
    public var source: DataSource
    public var isFinal: Bool

    public init(date: DayKey, value: Double, source: DataSource = .health, isFinal: Bool = false) {
        self.date = date; self.value = value; self.source = source; self.isFinal = isFinal
    }
}
