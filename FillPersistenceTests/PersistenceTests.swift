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

    @Test func test_D07_backfillMarksFinal() throws {
        // lastEvaluated 3 days ago → fetch covers gap; past days final.
        let ctx = ModelContext(try makeContainer())
        let repo = Repository(context: ctx)
        let today = todayKey()
        let s = repo.settings()
        s.lastEvaluatedKey = today.adding(days: -3).key
        let c = Challenge(name: "B", metric: .steps, target: 10_000, type: .flex,
                          x: 20, y: 30, start: today.adding(days: -10),
                          reward: .moneyEach(amount: 1_000))
        repo.insertChallenge(c)
        var d = today.adding(days: -2)
        while d <= today {
            repo.upsertMetricDay(metric: "steps", dayKey: d.key, value: 10_000)
            if d == today { break }
            d = d.adding(days: 1)
        }
        let rows = try ctx.fetch(FetchDescriptor<MetricDay>())
        #expect(rows.count == 3) // 17, 18, 19-equivalent
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

    @Test func test_D10_itemSaveSumsExactly() throws {
        let ctx = ModelContext(try makeContainer())
        let repo = Repository(context: ctx)
        let today = todayKey()
        let start = today.adding(days: -70)
        let c = Challenge(name: "DGX", metric: .steps, target: 10_000, type: .flex,
                          x: 70, y: 90, start: start,
                          reward: Reward(kind: .item, category: .item, name: "DGX Spark",
                                         value: 700_000, itemPayout: .save))
        repo.insertChallenge(c)
        let per = Derive.itemPerWin(value: 700_000, x: 70)
        for i in 0..<70 {
            let wins = i + 1
            let amt = Derive.itemSaved(value: 700_000, x: 70, wins: wins)
                      - Derive.itemSaved(value: 700_000, x: 70, wins: wins - 1)
            repo.insertRewardEntry(challengeID: c.id, kind: "itemSaving",
                                   dayKey: start.adding(days: i).key, amount: amt,
                                   itemValue: 700_000)
        }
        let entries = try ctx.fetch(FetchDescriptor<RewardEntry>())
        #expect(entries.count == 70)
        let amounts = entries.map { $0.amount }
        #expect(amounts.dropLast().allSatisfy { $0 == per })
        // Last win saves the remainder; total exactly the value.
        #expect(amounts.reduce(0, +) == 700_000)
        repo.insertRewardEntry(challengeID: c.id, kind: "final", dayKey: today.key,
                               amount: 0, itemValue: 700_000)
        let money = try ctx.fetch(FetchDescriptor<RewardEntry>())
            .filter { $0.kindRaw != "itemSaving" }.map(\.amount).reduce(0, +)
        #expect(money == 0) // item savings never counted as money
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
