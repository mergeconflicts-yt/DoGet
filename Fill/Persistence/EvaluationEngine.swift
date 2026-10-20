import Foundation
import SwiftData
#if SWIFT_PACKAGE
@testable import FillDomain
#endif

// IMPLEMENTATION §6 — the Evaluator loop, extracted from the app target so
// D07/D10/H03 can run against a real in-memory store with a fake Health source.
//
// Two things the old loop got wrong:
//  1. It started fetching at lastEvaluatedKey + 1, so later-in-the-day Health
//     data was never re-read. We now always re-fetch from yesterday (or the
//     last evaluated day, whichever is earlier).
//  2. It evaluated only from that run's in-memory cache, so stored days read
//     as 0 on later runs. We now build every challenge from MetricDay +
//     ManualLog rows (DATABASE §5).

public struct MetricValue: Sendable, Equatable {
    public var value: Double
    public var source: DataSource
    public init(_ value: Double, source: DataSource = .health) {
        self.value = value
        self.source = source
    }
}

public protocol MetricValueProviding: Sendable {
    func value(metric: Metric, day: DayKey, calendar: Calendar) async -> MetricValue
}

@MainActor
public struct EvaluatedPage {
    public var record: ChallengeRecord
    public var challenge: Challenge
    public var snapshot: Snapshot
    public var results: [DayResult]
}

public struct WonDay: Equatable, Sendable {
    public var challengeID: UUID
    public var name: String
    public var colorToken: String
    public var day: DayKey
    public var isToday: Bool
    public var amount: Decimal
    public var itemValue: Decimal
    public var amountText: String
    public var wins: Int
    public var kind: String? // perWin | itemSaving | nil
}

public struct EvaluationOutcome: Sendable {
    public var wonToday: WonDay?
    public var wonPast: [WonDay] = []
    public var newlyDone: [UUID] = []
    public var newlyOutOfReach: [UUID] = []
    public init() {}
}

@MainActor
public enum EvaluationEngine {

    // MARK: - Read model

    public static func pages(context: ModelContext, now: Date,
                             calendar: Calendar) -> [EvaluatedPage] {
        let repo = Repository(context: context)
        let records = repo.fetchActiveChallenges()
        let today = DayKey.from(date: now, calendar: calendar)

        let metricRows = (try? context.fetch(FetchDescriptor<MetricDay>())) ?? []
        let manualRows = (try? context.fetch(FetchDescriptor<ManualLog>())) ?? []
        var metricVals: [String: Double] = [:]
        var metricSrcs: [String: String] = [:]
        var finals: Set<String> = []
        for m in metricRows where m.dayKey <= today.key {
            metricVals["\(m.metricRaw)|\(m.dayKey)"] = m.value
            metricSrcs["\(m.metricRaw)|\(m.dayKey)"] = m.sourceRaw
            if m.isFinal { finals.insert("\(m.metricRaw)|\(m.dayKey)") }
        }
        var manualVals: [String: Double] = [:]
        for m in manualRows where m.dayKey <= today.key {
            manualVals["\(m.metricRaw)|\(m.dayKey)"] = m.value
        }

        return records.compactMap { rec in
            guard let c = toChallenge(rec) else { return nil }
            let prefix = "\(c.metric.rawValue)|"
            let md = Dictionary(uniqueKeysWithValues: metricVals
                .filter { $0.key.hasPrefix(prefix) }
                .map { (String($0.key.split(separator: "|")[1]), $0.value) })
            let ms = Dictionary(uniqueKeysWithValues: metricSrcs
                .filter { $0.key.hasPrefix(prefix) }
                .map { (String($0.key.split(separator: "|")[1]), $0.value) })
            let man = Dictionary(uniqueKeysWithValues: manualVals
                .filter { $0.key.hasPrefix(prefix) }
                .map { (String($0.key.split(separator: "|")[1]), $0.value) })
            let fin = Set(finals.filter { $0.hasPrefix(prefix) }
                .map { String($0.split(separator: "|")[1]) })
            let (results, best) = Mapping.dayResults(
                challenge: c, metricDays: md, metricSources: ms,
                finalDays: fin, manualLogs: man, today: today)
            let snap = Engine.snapshot(challenge: c, days: results, best: best,
                                       now: now, calendar: calendar)
            return EvaluatedPage(record: rec, challenge: c, snapshot: snap, results: results)
        }
    }

    // MARK: - Run

    public static func run(context: ModelContext,
                           provider: MetricValueProviding,
                           now: Date,
                           calendar: Calendar) async -> EvaluationOutcome {
        let repo = Repository(context: context)
        let settings = repo.settings()
        let today = DayKey.from(date: now, calendar: calendar)
        let yesterday = today.adding(days: -1)
        let records = repo.fetchActiveChallenges()

        // Old snapshots = what the user last saw, built from stored rows.
        let old = pages(context: context, now: now, calendar: calendar)
        let oldByID = Dictionary(uniqueKeysWithValues: old.map { ($0.challenge.id, $0) })

        // A day is final after 03:00 local (SPEC §11): mark it before fetching
        // so a run at 04:00 cannot change yesterday, while a run at 01:30 can.
        repo.markFinal(before: yesterday.key)
        if calendar.component(.hour, from: now) >= 3 {
            repo.markFinal(dayKey: yesterday.key)
        }
        try? context.save()

        // 1. Fetch from yesterday (or the last evaluated day, whichever is
        // earlier) through today, and save into MetricDay.
        if !settings.manualMode {
            let grouped = Dictionary(grouping: records, by: \.metricRaw)
            let stored = (try? context.fetch(FetchDescriptor<MetricDay>())) ?? []
            var finalRows: Set<String> = []
            for m in stored where m.isFinal { finalRows.insert("\(m.metricRaw)|\(m.dayKey)") }

            for (raw, recs) in grouped {
                guard let metric = Metric(rawValue: raw) else { continue }
                let earliest = recs.compactMap { DayKey(key: $0.startKey) }.min() ?? today
                var start: DayKey
                if let last = DayKey(key: settings.lastEvaluatedKey) {
                    // Start the day after the last evaluated day, but never
                    // later than yesterday: today's Health data changes all
                    // day, and yesterday can still change until 03:00.
                    start = min(last.adding(days: 1), yesterday)
                } else {
                    start = earliest
                }
                if start < earliest { start = earliest }
                if start > today { start = today }

                var d = start
                while d <= today {
                    let key = "\(raw)|\(d.key)"
                    if !finalRows.contains(key) {
                        let reading = await provider.value(metric: metric, day: d, calendar: calendar)
                        repo.upsertMetricDay(metric: raw, dayKey: d.key,
                                             value: reading.value,
                                             source: reading.source.rawValue)
                    }
                    if d == today { break }
                    d = d.adding(days: 1)
                }
            }
            settings.lastEvaluatedKey = today.key
        }

        // 2. Finalise days that were only just backfilled. Yesterday was
        // already finalised before the fetch when it was past 03:00.
        repo.markFinal(before: yesterday.key)
        if calendar.component(.hour, from: now) >= 3 {
            repo.markFinal(dayKey: yesterday.key)
        }
        try? context.save()

        // 3. New snapshots from the rows we just wrote.
        let new = pages(context: context, now: now, calendar: calendar)

        var outcome = EvaluationOutcome()
        let ledgerKeys = rewardLedgerKeys(context: context)

        for page in new {
            let c = page.challenge
            let oldPage = oldByID[c.id]
            let oldWon = Set((oldPage?.results ?? [])
                .filter { $0.value >= c.target }
                .map(\.date.key))

            let kind = ledgerKind(c)
            let allWins = winDays(page)
            let ledgerWins = contributingWins(page)

            // Per-win ledger: one entry per contributing win, with the amount
            // for that win number (item save uses the remainder on the last).
            if let kind {
                for (i, day) in ledgerWins.enumerated() {
                    let winNumber = i + 1
                    let amount: Decimal = kind == "perWin"
                        ? c.reward.amount
                        : Derive.itemSaved(value: c.reward.value, x: c.x, wins: winNumber)
                          - Derive.itemSaved(value: c.reward.value, x: c.x, wins: winNumber - 1)
                    let itemValue = kind == "itemSaving" ? c.reward.value : 0
                    let key = "\(c.id.uuidString)|\(kind)|\(day.date.key)"
                    if !ledgerKeys.contains(key) {
                        repo.insertRewardEntry(
                            challengeID: c.id, kind: kind, dayKey: day.date.key,
                            amount: amount, itemValue: itemValue,
                            currency: c.reward.currency,
                            isManual: day.source == .manual,
                            challengeName: c.name, colorToken: c.colorToken,
                            itemName: c.reward.name,
                            category: c.reward.category.rawValue)
                    }
                }
            }

            // Day won: today fires from the old/new comparison; a manual log
            // is handled by Log today itself (it has the same old snapshot).
            if page.snapshot.todayWon, !(oldPage?.snapshot.todayWon ?? false) {
                let amount = ledgerWins.first(where: { $0.date == today }).map { day in
                    ledgerAmount(c, kind: kind, day: day, wins: ledgerWins)
                } ?? 0
                outcome.wonToday = WonDay(
                    challengeID: c.id, name: c.name, colorToken: c.colorToken,
                    day: today, isToday: true, amount: amount,
                    itemValue: kind == "itemSaving" ? c.reward.value : 0,
                    amountText: dayWonText(c, amount: amount),
                    wins: page.snapshot.wins, kind: kind)
            }

            // Past days that turned into wins during the grace period.
            for day in allWins where day.date < today && !oldWon.contains(day.date.key) {
                let amount = ledgerAmount(c, kind: kind, day: day, wins: ledgerWins)
                outcome.wonPast.append(WonDay(
                    challengeID: c.id, name: c.name, colorToken: c.colorToken,
                    day: day.date, isToday: false, amount: amount,
                    itemValue: kind == "itemSaving" ? c.reward.value : 0,
                    amountText: dayWonText(c, amount: amount),
                    wins: page.snapshot.wins, kind: kind))
            }

            // Done: comparing old and new catches every reward type, not just
            // per-win rewards. Manual completion is handled by Log today.
            if page.snapshot.done, !(oldPage?.snapshot.done ?? false) {
                outcome.newlyDone.append(c.id)
            }

            // Out of reach: first time only (stamp persisted on the record).
            if page.snapshot.outOfReach, page.record.outOfReachNotifiedAt == nil {
                page.record.outOfReachNotifiedAt = now
                outcome.newlyOutOfReach.append(c.id)
            }
        }

        try? context.save()
        return outcome
    }

    // MARK: - Helpers

    /// Every day that is a win for this challenge, in order.
    static func winDays(_ page: EvaluatedPage) -> [DayResult] {
        let c = page.challenge
        var days = page.results.filter { $0.date >= c.start && $0.value >= c.target }
        if c.type == .flex || c.type == .streak {
            let window = c.type == .flex ? c.y : c.x
            days = days.filter { c.start.days(to: $0.date) < window }
        }
        return days
    }

    /// Days that actually pay a per-win reward, capped at the challenge's x
    /// so money stops when the deal is done (the old loop kept adding after
    /// completion and past the window).
    static func contributingWins(_ page: EvaluatedPage) -> [DayResult] {
        let c = page.challenge
        guard c.type != .once else { return [] }
        guard ledgerKind(c) != nil else { return [] }
        var days = winDays(page)
        if c.type == .flex || c.type == .streak {
            days = Array(days.prefix(max(0, min(c.x, days.count))))
        }
        return days
    }

    private static func ledgerAmount(_ c: Challenge, kind: String?, day: DayResult,
                                     wins: [DayResult]) -> Decimal {
        guard let kind, let i = wins.firstIndex(where: { $0.date == day.date }) else { return 0 }
        if kind == "perWin" { return c.reward.amount }
        let n = i + 1
        return Derive.itemSaved(value: c.reward.value, x: c.x, wins: n)
             - Derive.itemSaved(value: c.reward.value, x: c.x, wins: n - 1)
    }

    static func ledgerKind(_ c: Challenge) -> String? {
        if c.reward.kind == .money,
           c.reward.payout == .each || c.reward.payout == .bonus {
            return "perWin"
        }
        if c.reward.kind == .item, c.reward.itemPayout == .save, c.reward.value > 0, c.x > 0 {
            return "itemSaving"
        }
        return nil
    }

    static func dayWonText(_ c: Challenge, amount: Decimal) -> String {
        if c.reward.kind == .money,
           c.reward.payout == .each || c.reward.payout == .bonus {
            return Copy.plus(Format.money(c.reward.amount, currency: c.reward.currency))
        }
        if c.reward.kind == .item, c.reward.itemPayout == .save, amount > 0 {
            return Copy.plus(Format.money(amount, currency: c.reward.currency))
        }
        return Copy.oneWin
    }

    private static func rewardLedgerKeys(context: ModelContext) -> Set<String> {
        let all = (try? context.fetch(FetchDescriptor<RewardEntry>())) ?? []
        return Set(all.map { "\($0.challengeID.uuidString)|\($0.kindRaw)|\($0.dayKey)" })
    }

    private static func hasMoment(context: ModelContext, key: String) -> Bool {
        let parts = key.split(separator: "|")
        guard parts.count == 3 else { return false }
        let cid = UUID(uuidString: String(parts[0])) ?? UUID()
        let day = String(parts[1])
        let kind = String(parts[2])
        let d = FetchDescriptor<NotificationLog>(
            predicate: #Predicate {
                $0.challengeID == cid && $0.dayKey == day && $0.kindRaw == kind
            })
        return !((try? context.fetch(d)) ?? []).isEmpty
    }

    private static func logMoment(context: ModelContext, challengeID: UUID,
                                  dayKey: String, kind: String) {
        let row = NotificationLog()
        row.challengeID = challengeID
        row.dayKey = dayKey
        row.kindRaw = kind
        context.insert(row)
    }
}
