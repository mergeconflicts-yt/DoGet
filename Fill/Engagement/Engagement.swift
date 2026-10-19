import Foundation
import SwiftData
import UserNotifications

// IMPLEMENTATION §6 — Evaluator: one entry "refresh today", 2s coalesce.
// Foreground / observer / background task / log-saved / midnight / tz change.
// A @MainActor class (all callers hop here); the 2s gate merges repeat calls.
@MainActor
public final class Evaluator {
    public static let shared = Evaluator()
    private var lastRun: Date = .distantPast
    private init() {}

    @discardableResult
    public func refresh(context: ModelContext, app: AppState,
                        calendar: Calendar = .current, now: Date = Date()) async -> Bool {
        if now.timeIntervalSince(lastRun) < 2 { return false } // merge calls within 2s
        lastRun = now
        await runRefresh(context: context, app: app, calendar: calendar, now: now)
        return true
    }

    private func runRefresh(context: ModelContext, app: AppState, calendar: Calendar, now: Date) async {
        let repo = Repository(context: context)
        let settings = repo.settings()
        let today = DayKey.from(date: now, calendar: calendar)

        // 1. Fetch: each metric used by active challenges, lastEvaluated..today.
        let records = repo.fetchActiveChallenges()
        let metrics = Set(records.compactMap { Metric(rawValue: $0.metricRaw) })
        let health = HealthKitSource()
        var metricCache: [String: Double] = [:]
        var manualCache: [String: Double] = [:]
        // (Manual + MetricDay reads simplified: fetch all rows for metrics.)
        let manualRows = (try? context.fetch(FetchDescriptor<ManualLog>())) ?? []
        for m in manualRows { manualCache["\(m.metricRaw)|\(m.dayKey)"] = m.value }
        for metric in metrics {
            var d: DayKey
            if settings.lastEvaluatedKey.isEmpty {
                d = records.filter { $0.metricRaw == metric.rawValue }
                    .compactMap { DayKey(key: $0.startKey) }.min() ?? today
            } else {
                d = (DayKey(key: settings.lastEvaluatedKey) ?? today).adding(days: 1)
            }
            while d <= today {
                let v: Double
                if settings.manualMode {
                    v = manualCache["\(metric.rawValue)|\(d.key)"] ?? 0
                } else {
                    let hv = await health.value(metric: metric, day: d, calendar: calendar)
                    // Steps only: Core Motion fallback when Health has nothing (§5.5).
                    if metric == .steps, hv == 0 {
                        let mv = await MotionSource().value(metric: metric, day: d, calendar: calendar)
                        if mv > 0 {
                            repo.upsertMetricDay(metric: metric.rawValue, dayKey: d.key, value: mv, source: "motion")
                        }
                        v = mv
                    } else {
                        v = hv
                        repo.upsertMetricDay(metric: metric.rawValue, dayKey: d.key, value: v)
                    }
                }
                metricCache["\(metric.rawValue)|\(d.key)"] = v
                if d == today { break }
                d = d.adding(days: 1)
            }
        }
        settings.lastEvaluatedKey = today.key

        // 2. Finalize: yesterday final after 03:00 local.
        let hour = calendar.component(.hour, from: now)
        if hour >= 3 {
            let y = today.adding(days: -1)
            let all = (try? context.fetch(FetchDescriptor<MetricDay>())) ?? []
            for m in all where m.dayKey == y.key { m.isFinal = true }
        }
        try? context.save()

        // 3–4. Evaluate + compare → Day won / done / OOR-first-time.
        var freshWin: (name: String, amount: String, wins: Int)?
        var freshDone: UUID?
        for r in records {
            guard let c = toChallenge(r) else { continue }
            let md = Dictionary(uniqueKeysWithValues: metricCache
                .filter { $0.key.hasPrefix("\(c.metric.rawValue)|") }
                .map { (String($0.key.split(separator: "|")[1]), $0.value) })
            let man = Dictionary(uniqueKeysWithValues: manualCache
                .filter { $0.key.hasPrefix("\(c.metric.rawValue)|") }
                .map { (String($0.key.split(separator: "|")[1]), $0.value) })
            let (results, best) = Mapping.dayResults(
                challenge: c, metricDays: md, metricSources: [:], finalDays: [],
                manualLogs: man, today: today)
            let snap = Engine.snapshot(challenge: c, days: results, best: best, now: now, calendar: calendar)
            // Out-of-reach first time: stamp so the notification fires once.
            if snap.outOfReach, r.outOfReachNotifiedAt == nil {
                r.outOfReachNotifiedAt = now
            }
            // Per-win ledger (D03: exactly one entry per won day).
            // A newly inserted entry for TODAY triggers Day won (SPEC §7.4).
            for res in results where res.value >= c.target && res.date <= today {
                let kinds: [(kind: String, amount: Decimal, itemValue: Decimal)] = {
                    var k: [(String, Decimal, Decimal)] = []
                    if c.reward.kind == .money,
                       c.reward.payout == .each || c.reward.payout == .bonus {
                        k.append(("perWin", c.reward.amount, 0))
                    }
                    if c.reward.kind == .item, c.reward.itemPayout == .save {
                        let amt = Derive.itemSaved(value: c.reward.value, x: c.x, wins: snap.wins)
                                  - Derive.itemSaved(value: c.reward.value, x: c.x, wins: snap.wins - 1)
                        k.append(("itemSaving", amt, c.reward.value))
                    }
                    return k
                }()
                for (kind, amount, itemValue) in kinds {
                    let isNew = !repo.hasRewardEntry(challengeID: c.id, kind: kind, dayKey: res.date.key)
                    repo.insertRewardEntry(challengeID: c.id, kind: kind, dayKey: res.date.key,
                                           amount: amount,
                                           itemValue: itemValue, currency: c.reward.currency,
                                           isManual: res.source == .manual,
                                           challengeName: c.name, colorToken: c.colorToken,
                                           itemName: c.reward.name, category: c.reward.category.rawValue)
                    if isNew, res.date == today {
                        let amountText: String = {
                            if c.reward.kind == .money,
                               c.reward.payout == .each || c.reward.payout == .bonus {
                                return "+\(Format.money(c.reward.amount, currency: c.reward.currency))"
                            }
                            if c.reward.kind == .item, c.reward.itemPayout == .save {
                                return "+\(Format.money(amount, currency: c.reward.currency))"
                            }
                            return "+1 win"
                        }()
                        freshWin = (c.name, amountText, snap.wins)
                        if snap.done { freshDone = c.id }
                    }
                }
            }
        }
        try? context.save()
        // 4b. Present moments (SPEC §7.4–7.5; R04: celebration follows Day won).
        if let w = freshWin {
            if freshDone != nil {
                app.showDayWon(name: w.name, amount: w.amount, wins: w.wins)
                let doneID = freshDone
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2.3)) // R04
                    app.celebrating = doneID
                }
            } else {
                app.showDayWon(name: w.name, amount: w.amount, wins: w.wins)
            }
        } else if let doneID = freshDone {
            app.celebrating = doneID
        }
        // 5. Reschedule nudges.
        await Notifications.reschedule(context: context, now: now)
    }
}

// IMPLEMENTATION §7 + SPEC §10 — local notifications only.
public enum Notifications {
    @MainActor
    public static func reschedule(context: ModelContext, now: Date = Date()) async {
        // Nudge: one calendar trigger per challenge per day at nudge time (ID
        // "nudge.<id>.<day>" so it can be replaced/removed). Never for sleep;
        // removed on win/done/OOR; max 2/day (NotificationLog); quiet 22–07.
        let center = UNUserNotificationCenter.current()
        let repo = Repository(context: context)
        let settings = repo.settings()
        let hour = settings.nudgeHour, minute = settings.nudgeMinute
        let today = DayKey.from(date: now, calendar: .current)
        let pages = PageBuilder.build(context: context)
        for p in pages {
            let id = "nudge.\(p.challenge.id.uuidString).\(today.key)"
            guard p.challenge.metric != .sleep, // N05
                  !p.snapshot.todayWon, !p.snapshot.done,
                  !p.snapshot.outOfReach, p.snapshot.streakBrokenOnDay == nil,
                  hour >= 7 && hour < 22, // quiet hours 22:00–07:00
                  sentCount(context: context, challengeID: p.challenge.id, day: today.key) < 2,
                  let body = nudgeBody(challenge: p.challenge, snap: p.snapshot)
            else {
                center.removePendingNotificationRequests(withIdentifiers: [id])
                continue
            }
            let content = UNMutableNotificationContent()
            content.title = "\(p.challenge.name) · \(remainingText(challenge: p.challenge, todayValue: p.snapshot.todayValue)) to go"
            content.body = body
            var comps = DateComponents()
            comps.hour = hour; comps.minute = minute
            let req = UNNotificationRequest(identifier: id, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
            try? await center.add(req)
            logKind(context: context, challengeID: p.challenge.id, day: today.key, kind: "nudge")
        }
    }

    private static func sentCount(context: ModelContext, challengeID: UUID, day: String) -> Int {
        let cid = challengeID
        let d = FetchDescriptor<NotificationLog>(
            predicate: #Predicate { $0.challengeID == cid && $0.dayKey == day })
        return ((try? context.fetch(d)) ?? []).count
    }

    private static func logKind(context: ModelContext, challengeID: UUID, day: String, kind: String) {
        let cid = challengeID
        let d = FetchDescriptor<NotificationLog>(
            predicate: #Predicate { $0.challengeID == cid && $0.dayKey == day && $0.kindRaw == kind })
        if ((try? context.fetch(d)) ?? []).isEmpty {
            let row = NotificationLog()
            row.challengeID = challengeID; row.dayKey = day; row.kindRaw = kind
            context.insert(row)
            try? context.save()
        }
        // Prune rows older than 14 days (DATABASE §4.6).
        if let all = try? context.fetch(FetchDescriptor<NotificationLog>()) {
            let cutoff = Date().addingTimeInterval(-14 * 24 * 3600)
            for row in all where row.deliveredAt < cutoff { context.delete(row) }
            try? context.save()
        }
    }

    /// "2,158 STEPS" / "5.0 KM" — shared with the challenge page pill.
    public static func remainingText(challenge: Challenge, todayValue: Double) -> String {
        let left = max(0, challenge.target - todayValue)
        switch challenge.metric {
        case .steps: return "\(Format.int(Int(left))) STEPS"
        case .exercise: return "\(Int(left)) MINUTES"
        case .run: return "\(Format.metric(left, metric: .run)) KM"
        case .sleep: return "\(Format.metric(left, metric: .sleep)) HOURS"
        case .calories: return "\(Int(left)) KCAL"
        case .rings: return "\(Int(left)) RINGS"
        }
    }

    /// Nudge body per metric (SPEC §10). Steps → minutes walking (left÷100, up to 5).
    public static func nudgeBody(challenge: Challenge, snap: Snapshot) -> String? {
        if challenge.metric == .sleep { return nil } // N05
        let left = max(0, challenge.target - snap.todayValue)
        let win: String = {
            if challenge.reward.kind == .money, (challenge.reward.payout == .each || challenge.reward.payout == .bonus) {
                return " wins \(Format.money(challenge.reward.amount)) today"
            }
            if challenge.reward.kind == .item, challenge.reward.itemPayout == .save {
                return " wins \(Format.money(snap.perWin)) today"
            }
            return " wins the day"
        }()
        switch challenge.metric {
        case .steps:
            let mins = Int(((left / 100).rounded(.up) / 5).rounded(.up) * 5)
            return "A \(mins)-minute walk\(win)."
        case .run:
            return "One \(Format.metric(challenge.target, metric: .run)) km run\(win)."
        case .rings:
            return "Close your rings\(win)."
        case .exercise:
            return "\(Int(left)) minutes of exercise\(win)."
        case .calories:
            return "Burn \(Int(left)) kcal\(win)."
        case .sleep:
            return nil
        }
    }
}
