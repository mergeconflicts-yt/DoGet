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
        GeometryReader { g in
            ZStack(alignment: .bottom) {
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
                // Pages are clipped to the safe area by the pager, so the
                // bottom-most colour is bled here, outside the page.
                bleedStrip
                    .frame(height: g.safeAreaInsets.bottom)
                    .padding(.bottom, -g.safeAreaInsets.bottom)
                BottomBar(pageLabel: app.selectedPage == 0 ? Copy.allChallenges :
                            "\(Copy.allChallenges) \(app.selectedPage)/\(pages.count)",
                          onAll: { app.selectedPage = 0 },
                          onAdd: { app.showingCreate = true })
            }
        }
        .onAppear {
            pages = PageBuilder.build(context: context, now: app.now)
            selectNewIfNeeded()
        }
        .onChange(of: records.count) { _, _ in
            pages = PageBuilder.build(context: context, now: app.now)
            selectNewIfNeeded()
        }
    }

    /// Matches the current page's bottom colour so the home-indicator strip
    /// continues the page's fill to the physical bottom of the screen.
    @ViewBuilder private var bleedStrip: some View {
        if app.selectedPage >= 1, app.selectedPage <= pages.count {
            let p = pages[app.selectedPage - 1]
            let rescue = p.snapshot.outOfReach || p.snapshot.streakBroken
            FillColor.color(for: p.challenge.colorToken)
                .grayscale(rescue ? 0.7 : 0)
                .opacity(rescue ? 0.45 : 1)
                .frame(maxWidth: .infinity)
        } else {
            FillColor.bg.frame(maxWidth: .infinity)
        }
    }

    /// C12: after Start the new page appears last and the pager scrolls to it.
    private func selectNewIfNeeded() {
        guard app.selectNewChallenge, !pages.isEmpty else { return }
        app.selectNewChallenge = false
        app.selectedPage = pages.count
    }
}
