import SwiftUI
import SwiftData

// IMPLEMENTATION §8.1 — horizontal pager: page 0 Overview, then one page
// per active challenge, oldest first. Bottom bar shows k/N. Sheets live on
// RootView (IMPLEMENTATION §8.4) so overlays are presented exactly once.
public struct PagerView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<ChallengeRecord> { $0.archivedAt == nil },
           sort: \ChallengeRecord.createdAt) private var records: [ChallengeRecord]
    @State private var pages: [PageData] = []

    public var body: some View {
        @Bindable var app = app
        ZStack(alignment: .bottom) {
            // One continuous backdrop behind everything, edge to edge:
            // stacking a separate strip here left a hairline seam on
            // some devices (two sections + a border look).
            pageBackdrop
                .ignoresSafeArea()
            TabView(selection: $app.selectedPage) {
                OverviewView(
                    challenges: pages.map(\.challenge),
                    snapshots: Dictionary(uniqueKeysWithValues: pages.map { ($0.challenge.id, $0.snapshot) }),
                    onOpen: { app.selectedPage = $0 + 1 }
                ).tag(0)
                ForEach(Array(pages.enumerated()), id: \.element.id) { i, p in
                    ChallengePageView(challenge: p.challenge, snapshot: p.snapshot,
                                      dayStates: p.states, manualMode: p.manualMode)
                        .tag(i + 1)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            BottomBar(pageLabel: app.selectedPage == 0 ? Copy.allChallenges :
                        "\(Copy.allChallenges) \(app.selectedPage)/\(pages.count)",
                       tint: barTint,
                       onAll: { app.selectedPage = 0 },
                       onAdd: { app.showingCreate = true })
        }
        .onAppear {
            pages = PageBuilder.build(context: context, now: app.now)
            selectNewIfNeeded()
        }
        .onChange(of: records.count) { _, _ in
            pages = PageBuilder.build(context: context, now: app.now)
            selectNewIfNeeded()
        }
        // Same-count mutations (rescue, claim, log saves, evaluator runs)
        // and debug clock advances also need fresh snapshots.
        .onChange(of: app.dataVersion) { _, _ in
            pages = PageBuilder.build(context: context, now: app.now)
            selectNewIfNeeded()
        }
        .onChange(of: app.debugAdvanceDays) { _, _ in
            pages = PageBuilder.build(context: context, now: app.now)
        }
    }

    /// Full-screen backdrop in the current page's bottom colour, so the
    /// home-indicator zone is one continuous section with the page's fill.
    /// The floating bar tints to the same page colour (ink on Overview).
    private var barTint: Color? {
        guard app.selectedPage >= 1, app.selectedPage <= pages.count else { return nil }
        return FillColor.color(for: pages[app.selectedPage - 1].challenge.colorToken)
    }
    @ViewBuilder private var pageBackdrop: some View {
        if app.selectedPage >= 1, app.selectedPage <= pages.count {
            let p = pages[app.selectedPage - 1]
            let rescue = p.snapshot.outOfReach || p.snapshot.streakBroken
            FillColor.color(for: p.challenge.colorToken)
                .grayscale(rescue ? 0.7 : 0)
                .opacity(rescue ? 0.45 : 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            FillColor.bg
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// C12: after Start the new page appears last and the pager scrolls to it.
    private func selectNewIfNeeded() {
        guard app.selectNewChallenge, !pages.isEmpty else { return }
        app.selectNewChallenge = false
        app.selectedPage = pages.count
    }
}
