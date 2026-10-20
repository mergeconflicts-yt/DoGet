import SwiftUI
import SwiftData

// SPEC §7.11 Settings (proposed): sheet from gear on Overview.
public struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var manual = false
    @State private var hour = 20

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule().fill(FillColor.hairline).frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
            Text(Copy.settings).font(FillFont.panelTitle)
            Button(Copy.connectHealth) {
                Task {
                    _ = await HealthKitController.shared.authorize()
                    await Evaluator.shared.refresh(context: context, app: app, now: app.now)
                }
            }.font(FillFont.scaled(16, weight: .semibold))
                .accessibilityLabel(Copy.connectHealth)
            Toggle(Copy.logByHandSetting, isOn: $manual)
                .onChange(of: manual) { _, v in
                    Repository(context: context).settings().manualMode = v
                    try? context.save()
                    Task { await Evaluator.shared.refresh(context: context, app: app, now: app.now) }
                }
                .accessibilityLabel(Copy.logByHandSetting)
            Stepper(Copy.nudgeTime(hour, 0), value: $hour, in: 7...21) // S02: 22–07 not selectable
                .onChange(of: hour) { _, v in
                    Repository(context: context).settings().nudgeHour = v
                    try? context.save()
                    Task { await Notifications.reschedule(context: context, now: app.now) } // S02
                }
                .accessibilityLabel(Copy.nudgeTime(hour, 0))
            // v1: no cloud backup (not even iCloud) — switch stays out until M6.
            Button(Copy.replayWelcome) {
                Repository(context: context).settings().onboardingDone = false
                try? context.save()
                dismiss()
            }.font(FillFont.scaled(16, weight: .semibold))
                .accessibilityLabel(Copy.replayWelcome)
            WondayFlow(spacing: 3) {
                WondayWord(size: 13, color: FillColor.text2, ring: FillColor.orange, track: FillColor.orangeTint)
                ForEach(["keeps", "your", "activity", "on", "this", "iPhone.", "It", "never", "uploads", "or", "shares", "Health", "data."], id: \.self) { w in
                    Text(w).font(FillFont.scaled(13)).foregroundStyle(FillColor.text2)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Copy.settingsFooter)
            Spacer()
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 30))
        .onAppear {
            let s = Repository(context: context).settings()
            manual = s.manualMode; hour = s.nudgeHour
        }
    }
}

// IMPLEMENTATION §11 — Debug menu (DEBUG only): shake / long-press logo.
#if DEBUG
public struct DebugMenuView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var app
    public var body: some View {
        List {
            Button("+1,000 steps today") { addSteps() }
            Button("Finish this challenge") { finishChallenge() }
            Button("Miss days until out of reach") { missUntilOutOfReach() }
            Button("Apple Health on/off") { toggleHealth() }
            Button("Replay onboarding") { replay() }
            Button("Seed demo data") { Seed.insert(into: context) }
            Button("Advance clock +1 day") { app.debugAdvanceDays += 1 }
        }
    }
    private var repo: Repository { Repository(context: context) }
    private func selectedRecord() -> ChallengeRecord? {
        let all = repo.fetchActiveChallenges()
        let i = app.selectedPage - 1
        guard i >= 0, i < all.count else { return nil }
        return all[i]
    }
    private func finishChallenge() {
        guard let rec = selectedRecord(), let c = toChallenge(rec) else { return }
        let today = DayKey.from(date: app.now, calendar: .current)
        if c.type == .open {
            rec.closedAt = Date()
        } else {
            let wins = c.type == .once ? 1 : max(1, c.x)
            rec.startKey = today.adding(days: -(wins - 1)).key
            for i in 0..<wins {
                let day = today.adding(days: -i)
                repo.upsertMetricDay(metric: c.metric.rawValue, dayKey: day.key, value: c.target)
                if day < today { repo.markFinal(dayKey: day.key) }
            }
        }
        try? context.save()
        app.dataVersion += 1
        app.celebrating = c.id
    }
    private func missUntilOutOfReach() {
        guard let rec = selectedRecord(), let c = toChallenge(rec), c.type == .flex else { return }
        let today = DayKey.from(date: app.now, calendar: .current)
        rec.startKey = today.adding(days: -(max(1, c.y) - 1)).key
        rec.outOfReachNotifiedAt = nil
        try? context.save()
        app.dataVersion += 1
    }
    private func addSteps() {
        let today = DayKey.from(date: Date(), calendar: .current)
        Repository(context: context).upsertMetricDay(metric: "steps", dayKey: today.key, value: 1000)
    }
    private func toggleHealth() {
        let s = Repository(context: context).settings()
        s.manualMode.toggle(); try? context.save()
    }
    private func replay() {
        Repository(context: context).settings().onboardingDone = false
        try? context.save()
    }
}
#endif
