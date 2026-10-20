import SwiftUI
import SwiftData
import BackgroundTasks
import OSLog

private let log = Logger(subsystem: "com.wonday.rewards", category: "app")

@main
struct FillApp: App {
    @State private var appState = AppState()

    /// One container for the app and the background task. Creating it twice
    /// would open two separate stacks.
    static let container: ModelContainer = makeContainer()

    static func makeContainer() -> ModelContainer {
        // DATABASE §2: synced + local stores. CloudKit off until M6 switch.
        // Membership mirrors StorePlan.synced / StorePlan.local (see D06).
        let synced = ModelConfiguration("Synced",
            schema: Schema([ChallengeRecord.self, RewardEntry.self, ManualLog.self]),
            url: URL.applicationSupportDirectory.appending(path: "Fill.store"),
            cloudKitDatabase: .none)
        let local = ModelConfiguration("Local",
            schema: Schema([MetricDay.self, AppSettings.self, NotificationLog.self]),
            url: URL.applicationSupportDirectory.appending(path: "FillLocal.store"),
            cloudKitDatabase: .none)
        do {
            return try ModelContainer(
                for: ChallengeRecord.self, RewardEntry.self, ManualLog.self,
                MetricDay.self, AppSettings.self, NotificationLog.self,
                configurations: synced, local)
        } catch {
            log.fault("ModelContainer failed: \(error.localizedDescription)")
        }
        // A corrupt store must not brick the app on launch: wipe both
        // stores and recreate once. Data is already unrecoverable here.
        let fm = FileManager.default
        for name in ["Fill.store", "FillLocal.store"] {
            let base = URL.applicationSupportDirectory.appending(path: name)
            for url in [base,
                        base.appendingPathExtension("-wal"),
                        base.appendingPathExtension("-shm")] {
                try? fm.removeItem(at: url)
            }
        }
        do {
            return try ModelContainer(
                for: ChallengeRecord.self, RewardEntry.self, ManualLog.self,
                MetricDay.self, AppSettings.self, NotificationLog.self,
                configurations: synced, local)
        } catch {
            log.fault("ModelContainer failed after reset: \(error.localizedDescription)")
            fatalError("Storage unavailable: \(error.localizedDescription)")
        }
    }

    init() {
        // IMPLEMENTATION §5.4 — register observers before the first frame,
        // not from onAppear (review Medium).
        HealthKitController.shared.registerBackgroundDelivery()
        // Background app refresh: refetch Health and run the same Evaluator
        // when iOS wakes us (H03). The old task only rescheduled itself.
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.wonday.rewards.refresh", using: nil) { task in
            guard let refresh = task as? BGAppRefreshTask else { return }
            refresh.expirationHandler = { refresh.setTaskCompleted(success: false) }
            Task { @MainActor in
                let context = ModelContext(FillApp.container)
                Repository(context: context).dedupe()
                await Evaluator.shared.refresh(context: context, app: AppState(), now: Date())
                FillApp.scheduleRefresh()
                refresh.setTaskCompleted(success: true)
            }
        }
    }

    static func scheduleRefresh() {
        let req = BGAppRefreshTaskRequest(identifier: "com.wonday.rewards.refresh")
        req.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(req)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.light) // v1 ships light UI only
        }
        .modelContainer(Self.container)
    }
}

struct RootView: View {
    @Environment(AppState.self) private var app
    @Query(filter: #Predicate<ChallengeRecord> { $0.archivedAt == nil },
           sort: \ChallengeRecord.createdAt) private var records: [ChallengeRecord]
    @Query private var settings: [AppSettings]
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var phase
    @State private var didLaunch = false

    private var onboardingDone: Bool { settings.first?.onboardingDone ?? false }
    #if DEBUG
    private var shotScreen: String? { ShotMode.screen }
    #else
    private var shotScreen: String? { nil }
    #endif

    var body: some View {
        Group {
            #if DEBUG
            if let shot = shotScreen {
                ShotHost(screen: shot)
            } else {
                mainContent
            }
            #else
            mainContent
            #endif
        }
        .onAppear {
            guard !didLaunch else { return }
            didLaunch = true
            #if DEBUG
            // Deterministic UI tests: start at the welcome screen.
            if ProcessInfo.processInfo.arguments.contains("-uiTestResetOnboarding") {
                let s = Repository(context: context).settings()
                s.onboardingDone = false
                try? context.save()
            }
            #endif
            let repo = Repository(context: context)
            repo.dedupe()
            _ = repo.settings() // ensure single row
            // Health observers are registered in FillApp.init; this closure
            // lets their completion wait for the Evaluator.
            HealthKitController.shared.onRefresh = { [context, app] in
                await Evaluator.shared.refresh(context: context, app: app, now: app.now)
            }
            FillApp.scheduleRefresh()
            refresh()
        }
        .onChange(of: phase) { _, p in if p == .active { refresh() } }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .fillHealthUpdate)) { _ in refresh() }
        .overlay(alignment: .bottom) {
            if let t = app.toast {
                if t == Copy.onbStartedToast {
                    WondayToast()
                } else {
                    Toast(text: t)
                }
            }
        }
        // Overlays are owned here (IMPLEMENTATION §8.4) so the Evaluator can
        // open them and so Create is presented exactly once app-wide (the
        // pager + overview both presenting it made Create dismiss itself).
        .fullScreenCover(isPresented: Binding(
            get: { app.showingCreate }, set: { app.showingCreate = $0 }
        )) {
            CreateView()
        }
        .sheet(isPresented: Binding(
            get: { app.showingSettings }, set: { app.showingSettings = $0 }
        )) {
            SettingsView().presentationDetents([.medium, .large])
        }
        .sheet(item: Binding(
            get: { app.showingLogToday }, set: { app.showingLogToday = $0 }
        )) { req in
            LogTodayView(metric: req.metric, target: req.target, colorToken: req.colorToken)
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(item: Binding(
            get: { app.dayWon.map { DayWonItem(id: $0.name + $0.amount, data: $0) } },
            set: { if $0 == nil { app.dayWon = nil } }
        )) { item in
            DayWonView(colorToken: colorForChallenge(named: item.data.name),
                       amountText: item.data.amount,
                       subText: Copy.dayWonSub(item.data.name, item.data.wins))
        }
        .fullScreenCover(item: Binding(
            get: { app.celebrating.map { CelebrationItem(id: $0) } },
            set: { if $0 == nil { app.celebrating = nil } }
        )) { item in
            celebrationHost(id: item.id)
        }
        #if DEBUG
        .sheet(isPresented: Binding(
            get: { app.showingDebug }, set: { app.showingDebug = $0 }
        )) { DebugMenuView() }
        #endif
    }

    @ViewBuilder
    private var mainContent: some View {
        if !onboardingDone {
            OnboardingView()
        } else if records.isEmpty {
            // Empty state: Overview + the same bottom bar the pager shows.
            OverviewView(challenges: [], snapshots: [:], onOpen: { _ in })
                .overlay(alignment: .bottom) {
                    BottomBar(pageLabel: Copy.allChallenges,
                              onAll: {},
                              onAdd: { app.showingCreate = true })
                }
        } else {
            PagerView()
        }
    }

    private func refresh() {
        Task {
            await Evaluator.shared.refresh(context: context, app: app, now: app.now)
        }
    }

    private func colorForChallenge(named: String) -> String {
        records.first { $0.name == named }?.colorToken ?? "orange"
    }

    @ViewBuilder
    private func celebrationHost(id: UUID) -> some View {
        if let page = PageBuilder.build(context: context, now: app.now).first(where: { $0.challenge.id == id }) {
            CelebrationView(challenge: page.challenge, snapshot: page.snapshot)
        } else {
            Color.clear
        }
    }
}

private struct DayWonItem: Identifiable {
    var id: String
    var data: (name: String, amount: String, wins: Int)
}

private struct CelebrationItem: Identifiable {
    var id: UUID
}
