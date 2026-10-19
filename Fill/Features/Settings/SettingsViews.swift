import SwiftUI
import SwiftData

// SPEC §7.11 Settings (proposed): sheet from gear on Overview.
public struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var manual = false
    @State private var backup = false
    @State private var hour = 20

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule().fill(FillColor.hairline).frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
            Text("Settings").font(FillFont.panelTitle)
            Button("Connect Apple Health") {
                Task {
                    _ = await HealthKitController.shared.authorize()
                    await Evaluator.shared.refresh(context: context, app: app, now: app.now)
                }
            }.font(.system(size: 16, weight: .semibold))
                .accessibilityLabel("Connect Apple Health")
            Toggle("Log by hand", isOn: $manual)
                .onChange(of: manual) { _, v in
                    Repository(context: context).settings().manualMode = v
                    try? context.save()
                    Task { await Evaluator.shared.refresh(context: context, app: app, now: app.now) }
                }
                .accessibilityLabel("Log by hand")
            Stepper("Nudge time: \(hour):00", value: $hour, in: 7...21) // S02: 22–07 not selectable
                .onChange(of: hour) { _, v in
                    Repository(context: context).settings().nudgeHour = v
                    try? context.save()
                    Task { await Notifications.reschedule(context: context, now: app.now) } // S02
                }
                .accessibilityLabel("Nudge time")
            Toggle("Back up to iCloud", isOn: $backup)
                .onChange(of: backup) { _, v in
                    Repository(context: context).settings().iCloudBackup = v
                    try? context.save()
                }
                .accessibilityLabel("Back up to iCloud")
            Button("Replay welcome") {
                Repository(context: context).settings().onboardingDone = false
                try? context.save()
                dismiss()
            }.font(.system(size: 16, weight: .semibold))
                .accessibilityLabel("Replay welcome")
            Text("fill. keeps your activity on this iPhone. It never uploads or shares Health data.")
                .font(.system(size: 13)).foregroundStyle(FillColor.text2)
            Spacer()
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 30))
        .onAppear {
            let s = Repository(context: context).settings()
            manual = s.manualMode; backup = s.iCloudBackup; hour = s.nudgeHour
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
            Button("Finish this challenge") {}
            Button("Miss days until out of reach") {}
            Button("Apple Health on/off") { toggleHealth() }
            Button("Replay onboarding") { replay() }
            Button("Seed demo data") { Seed.insert(into: context) }
            Button("Advance clock +1 day") { app.debugAdvanceDays += 1 }
        }
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
