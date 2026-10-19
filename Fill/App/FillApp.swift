import SwiftUI
import SwiftData
import BackgroundTasks
import OSLog

private let log = Logger(subsystem: "app.fill.do", category: "app")

@main
struct FillApp: App {
    @State private var appState = AppState()

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
            fatalError("Storage unavailable: \(error.localizedDescription)")
        }
    }

    init() {
        // Background app refresh: refetch Health history when iOS wakes us (H03).
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "app.fill.do.refresh", using: nil) { task in
            guard let refresh = task as? BGAppRefreshTask else { return }
            refresh.expirationHandler = { refresh.setTaskCompleted(success: false) }
            Task {
                // NOTE: background context refresh needs the shared container;
                // the main actor path below covers foreground; this keeps the
                // task claimed and reschedules it.
                Self.scheduleRefresh()
                refresh.setTaskCompleted(success: true)
            }
        }
    }

    static func scheduleRefresh() {
        let req = BGAppRefreshTaskRequest(identifier: "app.fill.do.refresh")
        req.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(req)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.light) // v1 ships light UI only
        }
        .modelContainer(Self.makeContainer())
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
            if let shot = shotScreen {
                ShotHost(screen: shot)
            } else if !onboardingDone {
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
        .onAppear {
            guard !didLaunch else { return }
            didLaunch = true
            let repo = Repository(context: context)
            repo.dedupe()
            _ = repo.settings() // ensure single row
            // IMPLEMENTATION §5.4 — observers before the first frame.
            HealthKitController.shared.registerBackgroundDelivery()
            FillApp.scheduleRefresh()
            refresh()
        }
        .onChange(of: phase) { _, p in if p == .active { refresh() } }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .fillHealthUpdate)) { _ in refresh() }
        .overlay(alignment: .bottom) {
            if let t = app.toast { Toast(text: t) }
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
                       subText: "\(item.data.name) · \(item.data.wins) wins")
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

    private func refresh() {
        Task { await Evaluator.shared.refresh(context: context, app: app, now: app.now) }
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
