import SwiftUI
import SwiftData

#if DEBUG
// Headless visual verification: launch with `-FillShot <screen>` to render
// one screen with canned data, then capture via simctl screenshot.
// Screens: welcome, create, overview, challenge, rescue, celebration,
// daywon, logtoday, pager, pager-challenge, plus challenge scenarios:
// challenge-empty, challenge-one, challenge-half, challenge-done,
// challenge-broken, challenge-claimed, challenge-once, challenge-manual.
public enum ShotMode {
    public static var screen: String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-FillShot"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    @MainActor
    public static func seed(into context: ModelContext, oor: Bool = false) {
        // October 10K P02/A01 (or OOR/A05): F(20/30) steps orange money-each.
        let repo = Repository(context: context)
        let today = DayKey.from(date: Date(), calendar: .current)
        let start = today.adding(days: oor ? -20 : -12)
        let wins = 9, misses = oor ? 11 : 3
        let c = Challenge(name: "October 10K", colorToken: "orange", metric: .steps,
                          target: 10_000, type: .flex, x: 20, y: 30, start: start,
                          reward: .moneyEach(amount: 10_000))
        repo.insertChallenge(c)
        for i in 0..<(wins + misses) {
            repo.upsertMetricDay(metric: "steps", dayKey: start.adding(days: i).key,
                                 value: i < wins ? 10_000 : 0)
        }
        repo.upsertMetricDay(metric: "steps", dayKey: today.key, value: oor ? 0 : 7_842)
        for i in 0..<wins {
            repo.insertRewardEntry(challengeID: c.id, kind: "perWin",
                                   dayKey: start.adding(days: i).key, amount: 10_000,
                                   challengeName: "October 10K", colorToken: "orange")
        }
        // DGX Spark day-1 (P03).
        let g = Challenge(name: "DGX Spark", colorToken: "green", metric: .steps,
                          target: 10_000, type: .flex, x: 70, y: 90, start: today,
                          reward: Reward(kind: .item, category: .item, name: "DGX Spark",
                                         value: 700_000, itemPayout: .save))
        repo.insertChallenge(g)
        // Chai fund: open-ended per-win money (never runs out → rate row).
        let f = Challenge(name: "Chai fund", colorToken: "blue", metric: .steps,
                          target: 8_000, type: .open, x: 0, y: 0, start: today,
                          reward: .moneyEach(amount: 500))
        repo.insertChallenge(f)
        // Sleep week + Omakase final (W01 claimed look): 7 of 7, done.
        let s = Challenge(name: "Sleep week", colorToken: "teal", metric: .sleep,
                          target: 8, type: .streak, x: 7, y: 7, start: today.adding(days: -7),
                          reward: Reward(kind: .item, category: .food, name: "Omakase dinner",
                                         value: 6_000, itemPayout: .end),
                          claimed: true)
        repo.insertChallenge(s)
        for i in 0..<7 {
            repo.upsertMetricDay(metric: "sleep", dayKey: today.adding(days: -7 + i).key, value: 8)
        }
        repo.upsertMetricDay(metric: "sleep", dayKey: today.key, value: 8)
        repo.insertRewardEntry(challengeID: s.id, kind: "final", dayKey: today.key,
                               amount: 0, itemValue: 6_000, challengeName: "Sleep week",
                               colorToken: "teal", itemName: "Omakase dinner", category: "food")
        try? context.save()
    }

    @MainActor
    public static func doneChallenge() -> (Challenge, Snapshot) {
        let today = DayKey.from(date: Date(), calendar: .current)
        let c = Challenge(name: "Run club", colorToken: "amber", metric: .run,
                          target: 5.0, type: .flex, x: 12, y: 30,
                          start: today.adding(days: -12),
                          reward: .moneyEach(amount: 2_000))
        var days: [DayResult] = []
        for i in 0..<12 {
            days.append(DayResult(date: c.start.adding(days: i), value: 5.0, isFinal: true))
        }
        let s = Engine.snapshot(challenge: c, days: days, now: Date(), calendar: .current)
        return (c, s)
    }

    // MARK: - Challenge scenarios (one challenge per screen)

    /// empty: 0 wins + today band + first-win card. one: first win.
    /// half: 10 of 20. done: 20 of 20 + trophy footer.
    /// broken: streak with a miss + rescue card. claimed: done + REWARDED.
    /// once: one-time with a partial best, high fill, no wins yet.
    /// manual: same data as one, rendered with log-by-hand on.
    @MainActor
    public static func seedScenario(_ kind: String, into context: ModelContext) {
        let repo = Repository(context: context)
        let today = DayKey.from(date: Date(), calendar: .current)
        switch kind {
        case "empty":
            seedFlex(repo, context, today, name: "Fresh start", color: "blue",
                     x: 20, y: 30, startOffset: 0, wins: 0, misses: 0, todayValue: 7_842)
        case "one":
            seedFlex(repo, context, today, name: "First win", color: "green",
                     x: 20, y: 30, startOffset: -2, wins: 1, misses: 1, todayValue: 3_000)
        case "manual":
            seedFlex(repo, context, today, name: "Logged by hand", color: "amber",
                     x: 20, y: 30, startOffset: -2, wins: 1, misses: 1, todayValue: 3_000)
        case "half":
            seedFlex(repo, context, today, name: "Halfway there", color: "orange",
                     x: 20, y: 30, startOffset: -15, wins: 10, misses: 5, todayValue: 7_842)
        case "done":
            seedFlex(repo, context, today, name: "Finished twenty", color: "violet",
                     x: 20, y: 30, startOffset: -25, wins: 20, misses: 5, todayValue: 0)
        case "broken":
            let start = today.adding(days: -4)
            let c = Challenge(name: "Broken streak", colorToken: "teal", metric: .steps,
                              target: 10_000, type: .streak, x: 7, y: 7, start: start,
                              reward: .moneyEach(amount: 1_000))
            repo.insertChallenge(c)
            for i in 0..<4 {
                repo.upsertMetricDay(metric: "steps", dayKey: start.adding(days: i).key,
                                     value: i < 3 ? 10_000 : 0)
            }
            repo.upsertMetricDay(metric: "steps", dayKey: today.key, value: 2_000)
            for i in 0..<3 {
                repo.insertRewardEntry(challengeID: c.id, kind: "perWin",
                                       dayKey: start.adding(days: i).key, amount: 1_000,
                                       challengeName: c.name, colorToken: c.colorToken)
            }
            try? context.save()
        case "claimed":
            seedFlex(repo, context, today, name: "Trophy claimed", color: "pink",
                     x: 20, y: 30, startOffset: -25, wins: 20, misses: 5,
                     todayValue: 0, claimed: true)
        case "once":
            // One-time 10K steps, best 6,000 so far: high fill, no wins yet.
            let start = today.adding(days: -3)
            let c = Challenge(name: "First 10K", colorToken: "blue", metric: .steps,
                              target: 10_000, type: .once, x: 1, y: 0, start: start,
                              reward: Reward(kind: .money, payout: .end, amount: 50_000))
            repo.insertChallenge(c)
            repo.upsertMetricDay(metric: "steps", dayKey: start.adding(days: 1).key, value: 6_000)
            repo.upsertMetricDay(metric: "steps", dayKey: today.key, value: 2_000)
            try? context.save()
        default: break
        }
    }

    @MainActor
    private static func seedFlex(_ repo: Repository, _ context: ModelContext, _ today: DayKey,
                                 name: String, color: String,
                                 x: Int, y: Int, startOffset: Int, wins: Int, misses: Int,
                                 todayValue: Double, claimed: Bool = false) {
        let start = today.adding(days: startOffset)
        let c = Challenge(name: name, colorToken: color, metric: .steps, target: 10_000,
                          type: .flex, x: x, y: y, start: start,
                          reward: .moneyEach(amount: 10_000), claimed: claimed)
        repo.insertChallenge(c)
        for i in 0..<(wins + misses) {
            repo.upsertMetricDay(metric: "steps", dayKey: start.adding(days: i).key,
                                 value: i < wins ? 10_000 : 0)
        }
        repo.upsertMetricDay(metric: "steps", dayKey: today.key, value: todayValue)
        for i in 0..<wins {
            repo.insertRewardEntry(challengeID: c.id, kind: "perWin",
                                   dayKey: start.adding(days: i).key, amount: 10_000,
                                   challengeName: name, colorToken: color)
        }
        try? context.save()
    }
}

public struct ShotHost: View {
    var screen: String
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var app
    @State private var ready = false
    @State private var pages: [PageData] = []

    public var body: some View {
        Group {
            switch screen {
            case "welcome":
                OnboardingView()
            case "create":
                CreateView()
            case "overview":
                if ready {
                    OverviewView(challenges: pages.map(\.challenge),
                                 snapshots: Dictionary(uniqueKeysWithValues: pages.map { ($0.challenge.id, $0.snapshot) }))
                }
            case "challenge":
                if ready, let p = pages.first(where: { $0.challenge.name == "October 10K" }) {
                    ChallengePageView(challenge: p.challenge, snapshot: p.snapshot,
                                      dayStates: p.states, manualMode: false)
                }
            case "challenge-empty", "challenge-one", "challenge-half",
                 "challenge-done", "challenge-broken", "challenge-claimed",
                 "challenge-once", "challenge-manual":
                if ready {
                    let name = ["challenge-empty": "Fresh start", "challenge-one": "First win",
                                "challenge-half": "Halfway there", "challenge-done": "Finished twenty",
                                "challenge-broken": "Broken streak",
                                "challenge-claimed": "Trophy claimed",
                                "challenge-once": "First 10K",
                                "challenge-manual": "Logged by hand"][screen]
                    if let p = pages.first(where: { $0.challenge.name == name }) {
                        ChallengePageView(challenge: p.challenge, snapshot: p.snapshot,
                                          dayStates: p.states,
                                          manualMode: screen == "challenge-manual")
                    }
                }
            case "rescue":
                if ready, let p = pages.first(where: { $0.challenge.name == "October 10K" }) {
                    ChallengePageView(challenge: p.challenge, snapshot: p.snapshot,
                                      dayStates: p.states, manualMode: false)
                }
            case "celebration":
                CelebrationView(challenge: ShotMode.doneChallenge().0,
                                snapshot: ShotMode.doneChallenge().1)
            case "daywon":
                DayWonView(colorToken: "green", amountText: "+₹1,000",
                           subText: "Savings jar · 87 wins")
            case "logtoday":
                LogTodayView(metric: .steps, target: 10_000, colorToken: "orange")
            case "pager":
                PagerView()
            case "pager-oor":
                PagerView()
            case "pager-challenge":
                PagerView()
                    .onAppear { app.selectedPage = 1 }
            default:
                Text("unknown shot \(screen)")
            }
            // Never empty: onAppear does not reliably fire on an empty Group,
            // which left every seeded shot stuck blank.
            if !ready { Color.clear }
        }
        .onAppear {
            guard !ready else { return }
            if screen == "rescue" || screen == "pager-oor" {
                wipe(context)
                ShotMode.seed(into: context, oor: true)
            } else if screen.hasPrefix("challenge-") {
                wipe(context)
                ShotMode.seedScenario(String(screen.dropFirst("challenge-".count)), into: context)
            } else if screen != "welcome" && screen != "create" && screen != "celebration"
                        && screen != "daywon" && screen != "logtoday" {
                wipe(context)
                ShotMode.seed(into: context)
            }
            pages = PageBuilder.build(context: context)
            ready = true
        }
    }

    /// Seeded shots share one store across launches (same metric + overlapping
    /// days), so stale rows inflate wins. Wipe first for deterministic shots.
    @MainActor
    private func wipe(_ context: ModelContext) {
        for r in (try? context.fetch(FetchDescriptor<ChallengeRecord>())) ?? [] { context.delete(r) }
        for r in (try? context.fetch(FetchDescriptor<MetricDay>())) ?? [] { context.delete(r) }
        for r in (try? context.fetch(FetchDescriptor<RewardEntry>())) ?? [] { context.delete(r) }
        for r in (try? context.fetch(FetchDescriptor<ManualLog>())) ?? [] { context.delete(r) }
        try? context.save()
    }
}
#endif
