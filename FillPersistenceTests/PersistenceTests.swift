import Testing
import Foundation
import SwiftData
@testable import FillPersistence
@testable import FillDomain

// DATABASE.md acceptance D01–D10 — in-memory ModelContainer. Today = real today;
// windows are built relative to it so tests are date-independent.

@MainActor
func makeContainer() throws -> ModelContainer {
    try ModelContainer(for: ChallengeRecord.self, RewardEntry.self, ManualLog.self,
                   MetricDay.self, AppSettings.self, NotificationLog.self,
                   configurations: ModelConfiguration(isStoredInMemoryOnly: true))
}

@MainActor
func todayKey(_ cal: Calendar = .current) -> DayKey {
    DayKey.from(date: Date(), calendar: cal)
}

func date(_ day: DayKey, hour: Int = 12, calendar: Calendar = .current) -> Date {
    calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day,
                                       hour: hour)) ?? Date()
}

/// Fake Health source: returns a fixed value per day key, or `fallback`.
struct FakeProvider: MetricValueProviding {
    var values: [String: Double] = [:]
    var fallback: Double = 0
    func value(metric: Metric, day: DayKey, calendar: Calendar) async -> MetricValue {
        MetricValue(values[day.key] ?? fallback)
    }
}

@MainActor
@Suite("Persistence D01-D11", .serialized)
struct PersistenceTests {
    @Test func test_D01_sharedMetricDay() throws {
        let ctx = ModelContext(try makeContainer())
        let repo = Repository(context: ctx)
        let today = todayKey()
        let mk: (String) -> Challenge = { name in
            Challenge(name: name, metric: .steps, target: 10_000, type: .flex,
                      x: 20, y: 30, start: today, reward: .moneyEach(amount: 1_000))
        }
        repo.insertChallenge(mk("A")); repo.insertChallenge(mk("B"))
        // Health gives 9,000 today → one MetricDay(steps, today).
        repo.upsertMetricDay(metric: "steps", dayKey: today.key, value: 9_000)
        let rows = try ctx.fetch(FetchDescriptor<MetricDay>())
        #expect(rows.count == 1)
        // Both snapshots see 9,000.
        for name in ["A", "B"] {
            let rec = try ctx.fetch(FetchDescriptor<ChallengeRecord>()).first { $0.name == name }!
            let c = toChallenge(rec)!
            let (res, _) = Mapping.dayResults(challenge: c, metricDays: [today.key: 9_000],
                metricSources: [:], finalDays: [], manualLogs: [:], today: today)
            let s = Engine.snapshot(challenge: c, days: res, now: Date(), calendar: .current)
            #expect(s.todayValue == 9_000)
        }
    }

    @Test func test_D02_manualLogMaxNeverLowered() throws {
        let ctx = ModelContext(try makeContainer())
        let repo = Repository(context: ctx)
        let today = todayKey()
        repo.upsertManualLog(metric: "steps", dayKey: today.key, value: 6_000)
        repo.upsertManualLog(metric: "steps", dayKey: today.key, value: 10_000)
        repo.upsertManualLog(metric: "steps", dayKey: today.key, value: 7_000)
        let rows = try ctx.fetch(FetchDescriptor<ManualLog>())
        #expect(rows.count == 1)
        #expect(rows.first?.value == 10_000) // totals, not added; never lowered
    }

    @Test func test_D03_onePerWinEntry() throws {
        let ctx = ModelContext(try makeContainer())
        let repo = Repository(context: ctx)
        let today = todayKey()
        let c = Challenge(name: "E", metric: .steps, target: 10_000, type: .flex,
                          x: 20, y: 30, start: today, reward: .moneyEach(amount: 10_000))
        repo.insertChallenge(c)
        // Evaluator runs 4 times for the same win.
        for _ in 0..<4 {
            repo.insertRewardEntry(challengeID: c.id, kind: "perWin", dayKey: today.key,
                                   amount: 10_000, challengeName: "E")
        }
        let rows = try ctx.fetch(FetchDescriptor<RewardEntry>())
        #expect(rows.count == 1)
    }

    @Test func test_D04_restartKeepsLedger() throws {
        let ctx = ModelContext(try makeContainer())
        let repo = Repository(context: ctx)
        let today = todayKey()
        let start = today.adding(days: -10)
        var c = Challenge(name: "R", metric: .steps, target: 10_000, type: .flex,
                          x: 20, y: 30, start: start, reward: .moneyEach(amount: 1_000))
        let rec = repo.insertChallenge(c)
        for i in 0..<5 {
            repo.insertRewardEntry(challengeID: c.id, kind: "perWin",
                                   dayKey: start.adding(days: i).key, amount: 1_000)
        }
        // Restart from today.
        rec.startKey = today.key; rec.restartCount += 1
        rec.claimedAt = nil; rec.closedAt = nil; rec.outOfReachNotifiedAt = nil
        try ctx.save()
        let entries = try ctx.fetch(FetchDescriptor<RewardEntry>())
        #expect(entries.count == 5) // history kept
        c.start = today
        let (res, _) = Mapping.dayResults(challenge: c, metricDays: [:], metricSources: [:],
                                          finalDays: [], manualLogs: [:], today: today)
        let s = Engine.snapshot(challenge: c, days: res, now: Date(), calendar: .current)
        #expect(s.wins == 0)
    }

    @Test func test_D05_scrapKeepsRewards() throws {
        let ctx = ModelContext(try makeContainer())
        let repo = Repository(context: ctx)
        let today = todayKey()
        let c = Challenge(name: "S", metric: .steps, target: 10_000, type: .flex,
                          x: 20, y: 30, start: today, reward: .moneyEach(amount: 2_000))
        let rec = repo.insertChallenge(c)
        repo.insertRewardEntry(challengeID: c.id, kind: "perWin", dayKey: today.key,
                               amount: 2_000, challengeName: "S")
        rec.archivedAt = Date()
        try ctx.save()
        #expect(repo.fetchActiveChallenges().isEmpty) // hidden from pager
        let entries = try ctx.fetch(FetchDescriptor<RewardEntry>())
        #expect(entries.count == 1) // still counted
        #expect(entries.map(\.amount).reduce(0, +) == 2_000)
    }

    @Test func test_D06_noHealthInSyncedStore() {
        // DATABASE §2: Health/Motion values never sync.
        #expect(!StorePlan.synced.contains("MetricDay"))
        #expect(StorePlan.synced.sorted() == ["ChallengeRecord", "ManualLog", "RewardEntry"])
        #expect(StorePlan.local.contains("MetricDay"))
    }

    @Test func test_D07_backfillRunsEvaluatorAndMarksFinal() async throws {
        // lastEvaluated 3 days ago → the real Evaluator fetches 17, 18 and 19,
        // rewards each past win with its own dayKey, and finalises 17.
        let ctx = ModelContext(try makeContainer())
        let repo = Repository(context: ctx)
        let cal = Calendar.current
        let today = todayKey(cal)
        let s = repo.settings()
        s.lastEvaluatedKey = today.adding(days: -3).key
        let c = Challenge(name: "B", metric: .steps, target: 10_000, type: .flex,
                          x: 20, y: 30, start: today.adding(days: -10),
                          reward: .moneyEach(amount: 1_000))
        repo.insertChallenge(c)
        let outcome = await EvaluationEngine.run(
            context: ctx, provider: FakeProvider(fallback: 10_000),
            now: date(today), calendar: cal)
        let rows = try ctx.fetch(FetchDescriptor<MetricDay>())
        #expect(rows.count == 3)
        #expect(rows.map(\.dayKey).sorted() ==
                [today.adding(days: -2).key, today.adding(days: -1).key, today.key].sorted())
        #expect(rows.first { $0.dayKey == today.adding(days: -2).key }?.isFinal == true)
        #expect(rows.first { $0.dayKey == today.key }?.isFinal == false)
        let entries = try ctx.fetch(FetchDescriptor<RewardEntry>())
        #expect(entries.count == 3)
        #expect(Set(entries.map(\.dayKey)) ==
                Set([today.adding(days: -2).key, today.adding(days: -1).key, today.key]))
        #expect(outcome.wonToday != nil)
    }

    @Test func test_D08_dedupeKeepsMaxOldest() throws {
        let ctx = ModelContext(try makeContainer())
        let repo = Repository(context: ctx)
        let today = todayKey()
        let cid = UUID()
        let e1 = RewardEntry(); e1.challengeID = cid; e1.kindRaw = "perWin"
        e1.dayKey = today.key; e1.amount = 1_000; e1.createdAt = Date(timeIntervalSince1970: 100)
        let e2 = RewardEntry(); e2.challengeID = cid; e2.kindRaw = "perWin"
        e2.dayKey = today.key; e2.amount = 1_000; e2.createdAt = Date(timeIntervalSince1970: 200)
        ctx.insert(e1); ctx.insert(e2)
        let m1 = MetricDay(); m1.metricRaw = "steps"; m1.dayKey = today.key; m1.value = 5_000
        let m2 = MetricDay(); m2.metricRaw = "steps"; m2.dayKey = today.key; m2.value = 9_000
        ctx.insert(m1); ctx.insert(m2)
        try ctx.save()
        repo.dedupe()
        let entries = try ctx.fetch(FetchDescriptor<RewardEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.createdAt == Date(timeIntervalSince1970: 100)) // oldest
        let metrics = try ctx.fetch(FetchDescriptor<MetricDay>())
        #expect(metrics.count == 1)
        #expect(metrics.first?.value == 9_000) // max
    }

    @Test func test_D09_claimEachWritesZeroFinal() throws {
        let ctx = ModelContext(try makeContainer())
        let repo = Repository(context: ctx)
        let today = todayKey()
        let c = Challenge(name: "C", metric: .steps, target: 10_000, type: .flex,
                          x: 1, y: 30, start: today, reward: .moneyEach(amount: 5_000))
        repo.insertChallenge(c)
        repo.insertRewardEntry(challengeID: c.id, kind: "perWin", dayKey: today.key, amount: 5_000)
        // Claim: one final entry amount 0; MONEY REWARDED unchanged.
        repo.insertRewardEntry(challengeID: c.id, kind: "final", dayKey: today.key, amount: 0)
        let entries = try ctx.fetch(FetchDescriptor<RewardEntry>())
        let money = entries.filter { $0.kindRaw != "itemSaving" }.map(\.amount).reduce(0, +)
        #expect(entries.count == 2)
        #expect(money == 5_000)
    }

    @Test func test_D10_itemSaveSumsExactly() async throws {
        // 70 wins through the real Evaluator: one itemSaving per win, the last
        // one the remainder, summing to exactly ₹7,00,000.
        let ctx = ModelContext(try makeContainer())
        let repo = Repository(context: ctx)
        let cal = Calendar.current
        let today = todayKey(cal)
        let start = today.adding(days: -69)
        let c = Challenge(name: "DGX", metric: .steps, target: 10_000, type: .flex,
                          x: 70, y: 90, start: start,
                          reward: Reward(kind: .item, category: .item, name: "DGX Spark",
                                         value: 700_000, itemPayout: .save))
        repo.insertChallenge(c)
        repo.settings().lastEvaluatedKey = today.adding(days: -70).key
        _ = await EvaluationEngine.run(
            context: ctx, provider: FakeProvider(fallback: 10_000),
            now: date(today), calendar: cal)
        let entries = try ctx.fetch(FetchDescriptor<RewardEntry>())
            .filter { $0.kindRaw == "itemSaving" }
        #expect(entries.count == 70)
        #expect(entries.map(\.amount).reduce(0, +) == 700_000)
        let per = Derive.itemPerWin(value: 700_000, x: 70)
        #expect(entries.sorted { $0.dayKey < $1.dayKey }.dropLast().allSatisfy { $0.amount == per })
        // Claim writes one final entry with the item value.
        repo.insertRewardEntry(challengeID: c.id, kind: "final", dayKey: today.key,
                               amount: 0, itemValue: 700_000)
        let finals = try ctx.fetch(FetchDescriptor<RewardEntry>())
            .filter { $0.kindRaw == "final" }
        #expect(finals.count == 1)
        #expect(finals.first?.amount == 0)
        #expect(finals.first?.itemValue == 700_000)
    }

    @Test func test_A25_timeZoneMoveKeepsDays() async throws {
        var kolkata = Calendar(identifier: .gregorian)
        kolkata.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        var utc8 = Calendar(identifier: .gregorian)
        utc8.timeZone = TimeZone(identifier: "Asia/Shanghai")!

        let ctx = ModelContext(try makeContainer())
        let repo = Repository(context: ctx)
        let d15 = DayKey(year: 2026, month: 10, day: 15)
        let c = Challenge(name: "TZ", metric: .steps, target: 10_000, type: .flex,
                          x: 20, y: 30, start: d15, reward: .moneyEach(amount: 1_000))
        repo.insertChallenge(c)
        var values: [String: Double] = [:]
        for i in 0..<5 { values[d15.adding(days: i).key] = 10_000 }
        // 22:00 on 19 Oct in IST.
        _ = await EvaluationEngine.run(
            context: ctx, provider: FakeProvider(values: values, fallback: 0),
            now: date(DayKey(year: 2026, month: 10, day: 19), hour: 22, calendar: kolkata),
            calendar: kolkata)
        // 00:30 on 20 Oct after moving to UTC+8.
        let outcome = await EvaluationEngine.run(
            context: ctx, provider: FakeProvider(values: values, fallback: 0),
            now: date(DayKey(year: 2026, month: 10, day: 20), hour: 0, calendar: utc8),
            calendar: utc8)
        let rows = try ctx.fetch(FetchDescriptor<MetricDay>())
        #expect(rows.count == 6) // 15–20, one row each
        let pages = EvaluationEngine.pages(
            context: ctx,
            now: date(DayKey(year: 2026, month: 10, day: 20), hour: 0, calendar: utc8),
            calendar: utc8)
        #expect(pages.first?.snapshot.dayIndex == 5)
        #expect(pages.first?.snapshot.wins == 5)
        #expect(outcome.wonToday == nil) // 20 Oct has no steps yet
    }

    @Test func test_A26_yesterdayGraceBeforeThree() async throws {
        let ctx = ModelContext(try makeContainer())
        let repo = Repository(context: ctx)
        let cal = Calendar.current
        let today = todayKey(cal)
        let yesterday = today.adding(days: -1)
        let c = Challenge(name: "Grace", metric: .steps, target: 10_000, type: .flex,
                          x: 20, y: 30, start: today.adding(days: -5),
                          reward: .moneyEach(amount: 1_000))
        repo.insertChallenge(c)
        repo.upsertMetricDay(metric: "steps", dayKey: yesterday.key, value: 9_000)
        repo.settings().lastEvaluatedKey = yesterday.key
        let outcome = await EvaluationEngine.run(
            context: ctx, provider: FakeProvider(values: [yesterday.key: 10_200]),
            now: date(today, hour: 1, calendar: cal), calendar: cal)
        let row = try ctx.fetch(FetchDescriptor<MetricDay>())
            .first { $0.dayKey == yesterday.key }
        #expect(row?.value == 10_200)
        #expect(row?.isFinal == false) // still inside the grace window
        #expect(outcome.wonPast.contains { $0.day == yesterday && $0.amount == 1_000 })
    }

    @Test func test_A27_yesterdayFinalAfterThree() async throws {
        let ctx = ModelContext(try makeContainer())
        let repo = Repository(context: ctx)
        let cal = Calendar.current
        let today = todayKey(cal)
        let yesterday = today.adding(days: -1)
        let c = Challenge(name: "Final", metric: .steps, target: 10_000, type: .flex,
                          x: 20, y: 30, start: today.adding(days: -5),
                          reward: .moneyEach(amount: 1_000))
        repo.insertChallenge(c)
        repo.upsertMetricDay(metric: "steps", dayKey: yesterday.key, value: 9_000)
        repo.settings().lastEvaluatedKey = yesterday.key
        _ = await EvaluationEngine.run(
            context: ctx, provider: FakeProvider(values: [yesterday.key: 12_000]),
            now: date(today, hour: 4, calendar: cal), calendar: cal)
        let row = try ctx.fetch(FetchDescriptor<MetricDay>())
            .first { $0.dayKey == yesterday.key }
        #expect(row?.value == 9_000) // late sync after 03:00 is ignored
        #expect(row?.isFinal == true)
    }

    @Test func test_H03_backgroundWinSurvivesClosedApp() async throws {
        // The background task runs the same Evaluator; this is the state it
        // leaves behind for the page after launch.
        let ctx = ModelContext(try makeContainer())
        let repo = Repository(context: ctx)
        let cal = Calendar.current
        let today = todayKey(cal)
        let c = Challenge(name: "Closed", metric: .steps, target: 10_000, type: .flex,
                          x: 20, y: 30, start: today, reward: .moneyEach(amount: 1_000))
        repo.insertChallenge(c)
        let outcome = await EvaluationEngine.run(
            context: ctx, provider: FakeProvider(fallback: 10_000),
            now: date(today, hour: 20, calendar: cal), calendar: cal)
        #expect(outcome.wonToday?.amount == 1_000)
        let pages = EvaluationEngine.pages(
            context: ctx, now: date(today, hour: 20, calendar: cal), calendar: cal)
        #expect(pages.first?.snapshot.todayWon == true)
        #expect(try ctx.fetch(FetchDescriptor<RewardEntry>()).count == 1)
    }

    @Test func test_D11_insertPersistsClaimState() throws {
        let ctx = ModelContext(try makeContainer())
        let repo = Repository(context: ctx)
        let today = todayKey()
        let c = Challenge(name: "K", metric: .steps, target: 10_000, type: .flex,
                          x: 20, y: 30, start: today, reward: .moneyEach(amount: 1_000),
                          claimed: true)
        let rec = repo.insertChallenge(c)
        #expect(rec.claimedAt != nil)
        #expect(toChallenge(rec)?.claimed == true)
    }
}
