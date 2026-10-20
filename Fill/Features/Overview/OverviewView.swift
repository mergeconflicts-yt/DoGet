import SwiftUI

// SPEC §7.2 — Overview (page 0): Challenges title, gear → Settings;
// In progress + Completed sections, one band per challenge; empty state.
// The bottom bar and sheets are owned by RootView/PagerView.
public struct OverviewView: View {
    var challenges: [Challenge]
    var snapshots: [UUID: Snapshot] = [:]
    var onOpen: (Int) -> Void = { _ in }
    @Environment(AppState.self) private var app
    @State private var section = Copy.sectionInProgress

    public var body: some View {
        ZStack {
            FillColor.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    if challenges.isEmpty {
                        Text(Copy.noChallenges).font(.system(size: 17, weight: .medium))
                            .padding(.horizontal, 20).padding(.top, 24)
                        Button(Copy.firstChallenge) { app.showingCreate = true }
                            .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 24).padding(.vertical, 16)
                            .background(FillColor.ink, in: Capsule())
                            .padding(.horizontal, 20)
                            .accessibilityLabel(Copy.firstChallenge)
                    } else {
                        HStack(spacing: 0) {
                            sectionBtn(Copy.sectionInProgress, count: activeChallenges.count)
                            sectionBtn(Copy.sectionCompleted, count: completedChallenges.count)
                        }
                        .padding(4).background(FillColor.chipBg, in: Capsule())
                        .padding(.horizontal, 20)
                        if showingInProgress {
                            sectionList(activeChallenges, empty: Copy.sectionEmptyInProgress)
                        } else {
                            sectionList(completedChallenges, empty: Copy.sectionEmptyCompleted)
                        }
                    }
                    Spacer(minLength: 120)
                }
            }
        }
    }

    private var showingInProgress: Bool { section != Copy.sectionCompleted }

    private func sectionBtn(_ t: String, count: Int) -> some View {
        Button("\(t) (\(count))") { section = t }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(section == t ? .white : FillColor.ink)
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(section == t ? FillColor.ink : .clear, in: Capsule())
            .accessibilityLabel("\(t), \(count)")
    }

    private func sectionList(_ items: [(offset: Int, element: Challenge)], empty: String) -> some View {
        Group {
            if items.isEmpty {
                Text(empty).font(.system(size: 17, weight: .medium))
                    .foregroundStyle(FillColor.text2)
                    .padding(.horizontal, 20).padding(.top, 24)
            } else {
                ForEach(items, id: \.element.id) { i, c in
                    OverviewBand(challenge: c, snapshot: snapshots[c.id]) {
                        onOpen(i)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var header: some View {
        HStack {
            Text(Copy.allChallenges).font(FillFont.overviewTitle)
                .accessibilityAddTraits(.isHeader)
                #if DEBUG
                .onLongPressGesture { app.showingDebug = true }
                .accessibilityHint("Long press for debug menu")
                #endif
            Spacer()
            Button(action: { app.showingSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20)).foregroundStyle(FillColor.ink)
                    .frame(width: 44, height: 44)
                    .background(FillColor.chipBg, in: Circle())
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 20).padding(.top, 8)
    }

    /// Challenges still going, with original pager indices.
    private var activeChallenges: [(offset: Int, element: Challenge)] {
        Array(challenges.enumerated()).filter { !(snapshots[$0.element.id]?.done ?? false) }
    }

    /// Finished challenges, with original pager indices.
    private var completedChallenges: [(offset: Int, element: Challenge)] {
        Array(challenges.enumerated()).filter { snapshots[$0.element.id]?.done ?? false }
    }
}

// One band per challenge (DESIGN §5 Band): 92pt, radius 24, tint bg, fill to
// base, lighter today segment; text dark, turning white where the fill passes
// under it (dark layer + white layer clipped to the fill width).
public struct OverviewBand: View {
    var challenge: Challenge
    var snapshot: Snapshot?
    var onOpen: () -> Void = {}
    public var body: some View {
        let base = snapshot?.base ?? 0
        let layer = snapshot?.layer ?? 0
        let pc = Int((base * 100).rounded())
        Button(action: onOpen) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 24).fill(FillColor.tint(challenge.colorToken))
                GeometryReader { g in
                    // Corners always match the box (24 everywhere). A visible
                    // fill is never narrower than the corner diameter: below
                    // 48pt the corners collapse into each other and stop
                    // looking like the box.
                    let baseW = base <= 0 ? 0 : max(g.size.width * base, 48)
                    let layerW = g.size.width * layer
                    HStack(spacing: 0) {
                        FillColor.color(for: challenge.colorToken)
                            .frame(width: baseW)
                        // A tiny today sliver reads as a stray edge line, so
                        // hide it instead of rendering an artifact.
                        if layerW >= 6 && baseW + layerW >= 24 {
                            FillColor.color(for: challenge.colorToken).opacity(0.4)
                                .frame(width: layerW)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                bandText(widthFill: base, dark: true)
                GeometryReader { g in
                    // Full-size white copy (identical layout to the dark
                    // layer), visibility limited to the fill by a mask.
                    // (Width-constraining the copy re-wraps the text, which
                    // is what overlapped.)
                    let baseW = base <= 0 ? 0 : max(g.size.width * base, 48)
                    bandText(widthFill: base, dark: false)
                        .frame(width: g.size.width, height: g.size.height)
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: baseW)
                        }
                }
                .allowsHitTesting(false)
            }
            .frame(height: 92)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(challenge.name), \(rightText(pc: pc))")
    }
    private func bandText(widthFill: Double, dark: Bool) -> some View {
        let base = widthFill
        let pc = Int((base * 100).rounded())
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(challenge.name).font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(dark ? FillColor.ink : .white)
                Text(bandSub()).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(dark ? FillColor.text2 : .white.opacity(0.75))
            }
            Spacer()
            Text(rightText(pc: pc)).font(FillFont.mono(13))
                .foregroundStyle(dark ? FillColor.color(for: challenge.colorToken) : .white)
        }
        .padding(.horizontal, 18)
        .accessibilityHidden(true)
    }
    private func bandSub() -> String {
        guard let s = snapshot else { return "" }
        switch challenge.type {
        case .flex: return "Flexible · \(s.wins) of \(challenge.x) wins · today \(Int(s.todayRatio * 100))%"
        case .streak: return "Streak · \(s.wins) of \(challenge.x) days · today \(Int(s.todayRatio * 100))%"
        case .once: return "One time · best so far"
        case .open:
            if challenge.reward.kind == .money, challenge.reward.payout == .jar {
                return "Jar · \(Format.money(s.moneyEarned)) of \(Format.money(challenge.reward.jarTarget))"
            }
            return "No end · \(s.wins) wins"
        }
    }
    private func rightText(pc: Int) -> String {
        if snapshot?.done == true { return "DONE · TROPHY" }
        if snapshot?.outOfReach == true || snapshot?.streakBroken == true { return "tap to fix" }
        return "\(pc)% OF GOAL"
    }
}
