import Foundation
import SwiftData
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

// IMPLEMENTATION §6 — Evaluator. One entry point ("refresh today") used by
// foreground, Health observers, the background task, Log today, midnight and
// time-zone changes. Calls are merged: a call that arrives while a run is in
// flight (or within the 2s debounce) queues one more run instead of being
// dropped (review High 1 / Medium).
@MainActor
public final class Evaluator {
    public static let shared = Evaluator()
    private var lastRun: Date = .distantPast
    private var running = false
    private var queued = false
    private var queuedNow: Date?
    private init() {}

    @discardableResult
    public func refresh(context: ModelContext, app: AppState,
                        calendar: Calendar = .current, now: Date = Date()) async -> Bool {
        if running {
            queued = true
            queuedNow = now
            return false
        }
        running = true
        var ran = false
        var currentNow = now
        repeat {
            // Coalesce repeat calls: wait out the remainder of the 2s window
            // instead of returning without evaluating.
            let wait = 2 - Date().timeIntervalSince(lastRun)
            if ran, wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            lastRun = Date()
            await runRefresh(context: context, app: app, calendar: calendar, now: currentNow)
            ran = true
            if queued {
                queued = false
                currentNow = queuedNow ?? Date()
            }
        } while queued
        running = false
        return ran
    }

    private func runRefresh(context: ModelContext, app: AppState, calendar: Calendar, now: Date) async {
        let health = HealthProvider()
        let outcome = await EvaluationEngine.run(context: context, provider: health,
                                                 now: now, calendar: calendar)

        // SPEC §7.4–7.5: Day won then the celebration if this win completed
        // the challenge. Backfilled past wins still play Day won once.
        if let win = outcome.wonToday {
            app.showDayWon(name: win.name, amount: win.amountText, wins: win.wins)
            if outcome.newlyDone.contains(win.challengeID) {
                let doneID = win.challengeID
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2.3)) // R04
                    app.celebrating = doneID
                }
            }
        } else if let past = outcome.wonPast.last {
            app.showDayWon(name: past.name, amount: past.amountText, wins: past.wins)
            if outcome.newlyDone.contains(past.challengeID) {
                let doneID = past.challengeID
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2.3))
                    app.celebrating = doneID
                }
            }
        } else if let doneID = outcome.newlyDone.first {
            app.celebrating = doneID
        }

        app.dataVersion += 1
        await Notifications.notify(outcome: outcome, context: context, now: now, calendar: calendar)
        await Notifications.reschedule(context: context, now: now, calendar: calendar)

        // Onboarding "Not now": ask again once, after the first real win.
        if outcome.wonToday != nil || !outcome.wonPast.isEmpty {
            await Notifications.askAfterFirstWin(context: context)
        }
    }
}

// HealthKit with the Core Motion fallback for steps only (SPEC §9,
// IMPLEMENTATION §5.5). Read only.
private struct HealthProvider: MetricValueProviding {
    private let health = HealthKitSource()
    private let motion = MotionSource()

    func value(metric: Metric, day: DayKey, calendar: Calendar) async -> MetricValue {
        let hv = await health.value(metric: metric, day: day, calendar: calendar)
        if metric == .steps, hv <= 0 {
            let mv = await motion.value(metric: metric, day: day, calendar: calendar)
            if mv > 0 { return MetricValue(mv, source: .motion) }
        }
        return MetricValue(hv, source: .health)
    }
}

// IMPLEMENTATION §7 + SPEC §10 — local notifications only.
public enum Notifications {
    /// Ask once after the first real win when onboarding was skipped.
    @MainActor
    public static func askAfterFirstWin(context: ModelContext) async {
        let settings = Repository(context: context).settings()
        guard !settings.notificationsAsked else { return }
        #if canImport(UIKit)
        guard UIApplication.shared.applicationState == .active else { return }
        #endif
        settings.notificationsAsked = true
        try? context.save()
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: Nudges
    @MainActor
    public static func reschedule(context: ModelContext, now: Date = Date(),
                                  calendar: Calendar = .current) async {
        // Nudge: one calendar trigger per challenge per day at nudge time (ID
        // "nudge.<id>.<day>"). Never for sleep; removed on win/done/OOR/broken;
        // max 2/day (NotificationLog); quiet 22–07.
        let center = UNUserNotificationCenter.current()
        let repo = Repository(context: context)
        let settings = repo.settings()
        let hour = settings.nudgeHour, minute = settings.nudgeMinute
        let today = DayKey.from(date: now, calendar: calendar)
        let pages = PageBuilder.build(context: context, now: now, calendar: calendar)
        let activeIDs = Set(pages.map { $0.challenge.id.uuidString })

        // Remove pending nudges that no longer belong: scrapped challenges,
        // old days, and challenges that are won/done/OOR/broken.
        let pending = await center.pendingNotificationRequests()
        let keep = Set(pages.compactMap { p -> String? in
            guard nudgeEligible(p, now: now, hour: hour, minute: minute, calendar: calendar) else { return nil }
            return "nudge.\(p.challenge.id.uuidString).\(today.key)"
        })
        let stale = pending.map(\.identifier).filter { id in
            guard id.hasPrefix("nudge.") else { return false }
            let parts = id.split(separator: ".")
            guard parts.count >= 3 else { return true }
            let uuid = String(parts[1])
            return !activeIDs.contains(uuid) || !keep.contains(id)
        }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        let nudgeDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
        guard now < nudgeDate else { return } // already past today's nudge

        for p in pages {
            guard nudgeEligible(p, now: now, hour: hour, minute: minute, calendar: calendar),
                  sentCount(context: context, challengeID: p.challenge.id, day: today.key) < 2,
                  let body = nudgeBody(challenge: p.challenge, snap: p.snapshot)
            else { continue }
            let content = UNMutableNotificationContent()
            content.title = Copy.nudgeTitle(p.challenge.name,
                remainingText(challenge: p.challenge, todayValue: p.snapshot.todayValue))
            content.body = body
            var comps = DateComponents()
            comps.hour = hour; comps.minute = minute
            let id = "nudge.\(p.challenge.id.uuidString).\(today.key)"
            let req = UNNotificationRequest(identifier: id, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
            try? await center.add(req)
            logKind(context: context, challengeID: p.challenge.id, day: today.key, kind: "nudge")
        }
    }

    private static func nudgeEligible(_ p: PageData, now: Date, hour: Int, minute: Int,
                                      calendar: Calendar) -> Bool {
        guard p.challenge.metric != .sleep, // N05
              !p.snapshot.todayWon, !p.snapshot.done,
              !p.snapshot.outOfReach, p.snapshot.streakBrokenOnDay == nil,
              hour >= 7 && hour < 22 // quiet hours 22:00–07:00
        else { return false }
        let nudge = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
        return now < nudge
    }

    // MARK: Event notifications (Day won / Complete / Out of reach)
    @MainActor
    public static func notify(outcome: EvaluationOutcome, context: ModelContext,
                              now: Date, calendar: Calendar) async {
        let center = UNUserNotificationCenter.current()
        let hour = calendar.component(.hour, from: now)
        let quiet = hour >= 22 || hour < 7

        func post(_ id: String, title: String, body: String,
                  challengeID: UUID, day: DayKey, kind: String) async {
            guard sentCount(context: context, challengeID: challengeID, day: day.key) < 2 else { return }
            guard !hasKind(context: context, challengeID: challengeID, day: day.key, kind: kind) else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let trigger: UNNotificationTrigger?
            if quiet {
                var comps = DateComponents()
                comps.hour = 7; comps.minute = 0
                trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            } else {
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            }
            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try? await center.add(req)
            logKind(context: context, challengeID: challengeID, day: day.key, kind: kind)
        }

        for w in ([outcome.wonToday].compactMap { $0 } + outcome.wonPast) {
            await post("dayWon.\(w.challengeID.uuidString).\(w.day.key)",
                       title: w.name,
                       body: Copy.notifDayWonBody(w.amountText),
                       challengeID: w.challengeID, day: w.day, kind: "dayWon")
        }
        for id in outcome.newlyDone {
            guard let rec = record(context: context, id: id), let c = toChallenge(rec) else { continue }
            let day = DayKey.from(date: now, calendar: calendar)
            let reward = rewardName(c.reward)
            await post("complete.\(id.uuidString).\(day.key)",
                       title: c.name,
                       body: Copy.notifCompleteBody(reward),
                       challengeID: id, day: day, kind: "complete")
        }
        for id in outcome.newlyOutOfReach {
            guard let rec = record(context: context, id: id), let c = toChallenge(rec) else { continue }
            let day = DayKey.from(date: now, calendar: calendar)
            await post("oor.\(id.uuidString).\(day.key)",
                       title: c.name,
                       body: Copy.notifOutOfReachBody,
                       challengeID: id, day: day, kind: "outOfReach")
        }
    }

    private static func record(context: ModelContext, id: UUID) -> ChallengeRecord? {
        (try? context.fetch(FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate { $0.id == id })))?.first
    }

    private static func rewardName(_ r: Reward) -> String {
        if r.kind == .money { return Format.money(r.amount, currency: r.currency) }
        if r.value > 0 { return "\(r.name) · \(Format.money(r.value, currency: r.currency))" }
        return r.name
    }

    private static func sentCount(context: ModelContext, challengeID: UUID, day: String) -> Int {
        let cid = challengeID
        let d = FetchDescriptor<NotificationLog>(
            predicate: #Predicate { $0.challengeID == cid && $0.dayKey == day })
        return ((try? context.fetch(d)) ?? []).count
    }

    private static func hasKind(context: ModelContext, challengeID: UUID, day: String, kind: String) -> Bool {
        let cid = challengeID
        let d = FetchDescriptor<NotificationLog>(
            predicate: #Predicate { $0.challengeID == cid && $0.dayKey == day && $0.kindRaw == kind })
        return !((try? context.fetch(d)) ?? []).isEmpty
    }

    private static func logKind(context: ModelContext, challengeID: UUID, day: String, kind: String) {
        guard !hasKind(context: context, challengeID: challengeID, day: day, kind: kind) else { return }
        let row = NotificationLog()
        row.challengeID = challengeID; row.dayKey = day; row.kindRaw = kind
        context.insert(row)
        try? context.save()
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
            if challenge.reward.kind == .money,
               challenge.reward.payout == .each || challenge.reward.payout == .bonus {
                return Copy.nudgeWinMoney(Format.money(challenge.reward.amount,
                                                       currency: challenge.reward.currency))
            }
            if challenge.reward.kind == .item, challenge.reward.itemPayout == .save {
                return Copy.nudgeWinMoney(Format.money(snap.perWin,
                                                       currency: challenge.reward.currency))
            }
            return Copy.nudgeWinDay
        }()
        switch challenge.metric {
        case .steps:
            let mins = Int(((left / 100).rounded(.up) / 5).rounded(.up) * 5)
            return Copy.nudgeSteps(minutes: mins, win: win)
        case .run:
            return Copy.nudgeRun(target: Format.metric(challenge.target, metric: .run), win: win)
        case .rings:
            return Copy.nudgeRings(win: win)
        case .exercise:
            return Copy.nudgeExercise(left: Int(left), win: win)
        case .calories:
            return Copy.nudgeCalories(left: Int(left), win: win)
        case .sleep:
            return nil
        }
    }
}
