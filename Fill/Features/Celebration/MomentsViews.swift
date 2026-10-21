import SwiftUI
import SwiftData
import UIKit

// SPEC §7.9 — Log today (manual mode): stepper (tap to type),
// 50% / 80% / Goal-reached chips, honesty note, connect-health, Save.
// Saving sets today's total (never lowers); win → manual win + Day won.
public struct LogTodayView: View {
    var metric: Metric
    var target: Double
    var colorToken: String
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var value: Double = 0
    @State private var loaded = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule().fill(FillColor.hairline).frame(width: 40, height: 5)
                .frame(maxWidth: .infinity).accessibilityHidden(true)
            Text(Copy.logToday).font(FillFont.panelTitle)
            FillStepper(
                value: Format.metric(value, metric: metric),
                unit: MetricDefaults.unit(for: metric),
                colorToken: colorToken,
                onMinus: { value = max(0, value - step()) },
                onPlus: { value += step() },
                onSet: { v in value = max(0, v) })
            HStack(spacing: 8) {
                logChip(Copy.half) { value = (target * 0.5).rounded(.up) }
                logChip(Copy.eighty) { value = (target * 0.8).rounded(.up) }
                logChip(Copy.goalReached, selected: value >= target) { value = target }
            }
            Text(Copy.honest)
                .font(FillFont.scaled(14)).foregroundStyle(FillColor.text2)
            Button(Copy.connectInstead) { connectHealth() }
                .font(FillFont.scaled(15, weight: .semibold))
                .accessibilityLabel(Copy.connectInstead)
            Text(Copy.logConnectNote)
                .font(FillFont.scaled(12))
                .foregroundStyle(FillColor.text2)
                .accessibilityLabel(Copy.logConnectNote)
            Button(Copy.save) { save() }
                .font(FillFont.scaled(17, weight: .bold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(FillColor.ink, in: Capsule())
                .accessibilityLabel(Copy.save)
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(FillColor.surface, in: RoundedRectangle(cornerRadius: 30))
        .onAppear {
            guard !loaded else { return }
            loaded = true
            let today = DayKey.from(date: app.now, calendar: .current)
            let rows = (try? context.fetch(FetchDescriptor<ManualLog>(
                predicate: #Predicate { $0.metricRaw == metric.rawValue && $0.dayKey == today.key }))) ?? []
            value = rows.first?.value ?? 0
        }
    }
    private func logChip(_ text: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(FillFont.scaled(14, weight: .semibold))
                .foregroundStyle(selected ? .white : FillColor.ink)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(selected ? FillColor.color(for: colorToken) : FillColor.chipBg,
                            in: Capsule())
        }
        .accessibilityLabel(text)
    }
    private func step() -> Double {
        switch metric {
        case .steps: return 500
        case .rings: return 1
        case .exercise: return 5
        case .run, .sleep: return 0.5
        case .calories: return 50
        }
    }
    private func save() {
        let today = DayKey.from(date: app.now, calendar: .current)
        // Capture what the user saw before this save so a win that happens
        // *because* of this manual log still shows Day won (SPEC §7.9/M02).
        let before = PageBuilder.build(context: context, now: app.now)
            .filter { $0.challenge.metric == metric }
        let beforeByID = Dictionary(uniqueKeysWithValues: before.map {
            ($0.challenge.id, $0.snapshot.todayWon)
        })
        // D02/M03: sets today's total, never lowers (Repository upsert).
        Repository(context: context).upsertManualLog(metric: metric.rawValue,
                                                     dayKey: today.key, value: value)
        let after = PageBuilder.build(context: context, now: app.now)
            .filter { $0.challenge.metric == metric }
        let newWins = after.filter { p in
            p.snapshot.todayWon && !(beforeByID[p.challenge.id] ?? false)
        }
        app.showToast(Copy.saved)
        dismiss()
        Task { @MainActor in
            await Evaluator.shared.refresh(context: context, app: app, now: app.now)
            app.dataVersion += 1
            guard let p = newWins.first else { return }
            let kind = EvaluationEngine.ledgerKind(p.challenge)
            let amount = kind == "itemSaving" ? p.snapshot.perWin : p.challenge.reward.amount
            app.showDayWon(name: p.challenge.name,
                           amount: EvaluationEngine.dayWonText(p.challenge, amount: amount),
                           wins: p.snapshot.wins)
            if p.snapshot.done {
                let id = p.challenge.id
                try? await Task.sleep(for: .seconds(2.3))
                app.celebrating = id
            }
        }
    }
    /// M04: Health prompt / Health app path; manual mode off only on success.
    private func connectHealth() {
        // Already denied once: iOS won't show the sheet again — open the
        // Health app so categories can be turned on. Stay put, keep manual.
        if HealthKitController.shared.hasBeenAsked,
           !HealthKitController.shared.isAuthorized {
            if let healthURL = URL(string: "x-apple-health://"),
               UIApplication.shared.canOpenURL(healthURL) {
                UIApplication.shared.open(healthURL)
            } else if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            return
        }
        Task { @MainActor in
            let granted = await HealthKitController.shared.authorize()
            guard granted else { return }
            Repository(context: context).settings().manualMode = false
            try? context.save()
            await Evaluator.shared.refresh(context: context, app: app, now: app.now)
            dismiss()
        }
    }
}

// SPEC §7.4 — Day won overlay: fills with challenge color 2.6s,
// DAY WON + amount/+1 win + count, success haptic.
public struct DayWonView: View {
    var colorToken: String
    var amountText: String
    var subText: String
    public var body: some View {
        ZStack {
            FillColor.color(for: colorToken).ignoresSafeArea()
            VStack(spacing: 8) {
                Text(Copy.dayWon).font(FillFont.mono(14)).tracking(1.6).foregroundStyle(.white)
                Text(amountText).font(FillFont.scaled(72, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(.white).minimumScaleFactor(0.6).lineLimit(1)
                Text(subText).font(FillFont.scaled(18, weight: .medium)).foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
        }
        .sensoryFeedback(.success, trigger: amountText)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Copy.dayWon). \(amountText). \(subText)")
    }
}

// SPEC §7.5 — Celebration: color rises, confetti (white, near-black,
// yellow, challenge color), CHALLENGE COMPLETE, trophy with count-up and
// ring text, reward + is yours, stats per type, Claim → Rewarded ✓
// (closes 0.9s later).
public struct CelebrationView: View {
    var challenge: Challenge
    var snapshot: Snapshot
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var claimed = false
    @State private var leveledUp = false
    @State private var countUp: Double = 0
    @State private var trophyShown = false

    public var body: some View {
        ZStack {
            FillColor.color(for: challenge.colorToken).ignoresSafeArea()
            if !reduceMotion { ConfettiView(colorToken: challenge.colorToken) }
            VStack(spacing: 14) {
                Text(Copy.challengeComplete).font(FillFont.mono(14)).tracking(1.6)
                    .foregroundStyle(.white).padding(.top, 40)
                Spacer()
                trophy
                    .scaleEffect(trophyShown || reduceMotion ? 1 : 0.3)
                    .opacity(trophyShown || reduceMotion ? 1 : 0)
                Text(rewardText()).font(FillFont.celebrateValue).monospacedDigit()
                    .foregroundStyle(.white).minimumScaleFactor(0.5).lineLimit(1)
                Text(Copy.isYours).font(FillFont.scaled(17, weight: .medium)).foregroundStyle(.white)
                stats
                    .font(FillFont.scaled(13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Button(isClaimed ? Copy.rewardedCheck : Copy.claimReward) { claim() }
                    .font(FillFont.scaled(17, weight: .bold))
                    .foregroundStyle(isClaimed ? FillColor.success : FillColor.ink)
                    .frame(maxWidth: .infinity).frame(height: 60)
                    .background(.white, in: Capsule())
                    .disabled(isClaimed)
                    .accessibilityLabel(isClaimed ? Copy.rewardedCheck : Copy.claimReward)
                if let next = levelUp {
                    Button(levelUpText(next)) { startLevel(next) }
                        .font(FillFont.scaled(16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(.white.opacity(0.2), in: Capsule())
                        .overlay(Capsule().stroke(.white, lineWidth: 1.5))
                        .disabled(leveledUp)
                        .accessibilityLabel(levelUpText(next))
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .sensoryFeedback(trigger: claimed) { _, _ in .success }
        .sensoryFeedback(.impact(weight: .light), trigger: trophyShown)
        .onAppear { claimed = challenge.claimed }
        .task {
            // DESIGN §6: trophy pop after 0.55s; count-up 1.1s ease-out.
            if reduceMotion {
                countUp = 1; trophyShown = true
                return
            }
            try? await Task.sleep(for: .seconds(0.55))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { trophyShown = true }
            withAnimation(.easeOut(duration: 1.1)) { countUp = 1 }
        }
    }

    private var isClaimed: Bool { claimed || challenge.claimed }

    // Trophy: number + unit, name · type · date as ring text around it.
    private var trophy: some View {
        let n = displayCount
        return ZStack {
            RingText(text: ringText.uppercased(), radius: 96)
                .foregroundStyle(.white.opacity(0.8))
            VStack(spacing: 2) {
                Text(n).font(FillFont.scaled(60, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(.white).minimumScaleFactor(0.5).lineLimit(1)
                Text(trophyUnit).font(FillFont.mono(12)).tracking(1.2)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(width: 220, height: 220)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(n) \(trophyUnit)")
    }
    private var ringText: String {
        Copy.ringText(challenge.name, Derive.typeName(challenge.type),
                      Format.date(snapshot.endDate ?? challenge.start))
    }
    private var displayCount: String {
        switch challenge.type {
        case .flex, .streak:
            return "\(Int((Double(snapshot.wins) * countUp).rounded()))"
        case .open:
            if challenge.reward.kind == .money {
                return Format.money(snapshot.moneyEarned * Decimal(countUp), currency: challenge.reward.currency)
            }
            return "\(Int((Double(snapshot.wins) * countUp).rounded()))"
        case .once:
            return Format.metric(challenge.target * countUp, metric: challenge.metric)
        }
    }
    private var trophyUnit: String {
        switch challenge.type {
        case .flex: return Copy.unitWins
        case .streak: return Copy.unitInARow
        case .once: return MetricDefaults.unit(for: challenge.metric).uppercased()
        case .open:
            if challenge.reward.kind == .money, challenge.reward.payout == .jar { return Copy.unitSaved }
            return Copy.unitWins
        }
    }
    private var stats: Text {
        switch challenge.type {
        case .flex:
            return Text(Copy.statsFlex(wins: snapshot.wins, misses: snapshot.misses,
                                       days: snapshot.dayIndex + 1))
        case .streak:
            return Text(Copy.statsStreak(challenge.x))
        case .once:
            return Text(Copy.statsOnce(Format.metric(challenge.target, metric: challenge.metric),
                                       MetricDefaults.unit(for: challenge.metric),
                                       run: challenge.metric == .run))
        case .open:
            if challenge.reward.kind == .money, challenge.reward.payout == .jar {
                return Text(Copy.statsJar(snapshot.wins,
                    Format.money(challenge.reward.jarTarget, currency: challenge.reward.currency)))
            }
            if challenge.reward.kind == .money {
                return Text(Copy.statsOpenEach(snapshot.wins,
                    Format.money(snapshot.moneyEarned, currency: challenge.reward.currency)))
            }
            return Text(Copy.statsOpenItem(snapshot.wins, challenge.reward.name))
        }
    }
    private func rewardText() -> String {
        let r = challenge.reward
        if r.kind == .money {
            switch r.payout {
            case .each, .bonus: return Format.money(snapshot.moneyEarned, currency: r.currency)
            case .end: return Format.money(r.amount, currency: r.currency)
            case .jar: return Format.money(r.jarTarget, currency: r.currency)
            }
        }
        return r.value > 0 ? "\(r.name) · \(Format.money(r.value, currency: r.currency))" : r.name
    }

    /// SPEC §6: offered only when Derive.levelUp returns a challenge.
    private var levelUp: Challenge? {
        Derive.levelUp(challenge, today: DayKey.from(date: app.now, calendar: .current))
    }
    private func levelUpText(_ next: Challenge) -> String {
        Copy.levelUpButton(Format.metric(next.target, metric: next.metric),
                           MetricDefaults.unit(for: next.metric))
    }
    private func startLevel(_ next: Challenge) {
        guard !leveledUp else { return }
        leveledUp = true
        Repository(context: context).insertChallenge(next, parentID: challenge.id)
        app.dataVersion += 1
        app.selectNewChallenge = true
        dismiss()
        app.showToast(Copy.levelUpToast(next.level,
                                        Format.metric(next.target, metric: next.metric),
                                        MetricDefaults.unit(for: next.metric)))
    }

    private func claim() {
        guard !isClaimed else { return }
        let id = challenge.id
        if let r = (try? context.fetch(FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate { $0.id == id })))?.first {
            guard r.claimedAt == nil else { claimed = true; return }
            r.claimedAt = Date()
            // DATABASE §4.2 — Claim reward always writes exactly one `final`.
            let reward = challenge.reward
            let amount: Decimal = {
                if reward.kind == .item { return 0 }
                switch reward.payout {
                case .each: return 0
                case .bonus: return reward.bonus
                case .end: return reward.amount
                case .jar: return reward.jarTarget
                }
            }()
            Repository(context: context).insertRewardEntry(
                challengeID: id, kind: "final",
                dayKey: DayKey.from(date: Date(), calendar: .current).key,
                amount: amount,
                itemValue: reward.kind == .item ? reward.value : 0,
                currency: reward.currency,
                challengeName: challenge.name, colorToken: challenge.colorToken,
                itemName: reward.name, category: reward.category.rawValue)
            try? context.save()
        }
        claimed = true
        app.dataVersion += 1
        let toast = Copy.claimToast(rewardText())
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.9)) // SPEC §7.5
            dismiss()
            app.showToast(toast)
        }
    }
}

// Ring text around the trophy (mockups IMG_5616, 5640).
struct RingText: View {
    var text: String
    var radius: CGFloat
    var fontSize: CGFloat = 12
    public var body: some View {
        let chars = Array(text.enumerated())
        let count = max(1, chars.count)
        return ZStack {
            ForEach(chars, id: \.offset) { i, ch in
                Text(String(ch))
                    .font(FillFont.scaled(fontSize, weight: .bold))
                    .rotationEffect(.degrees(360 * Double(i) / Double(count)))
                    .offset(y: -radius)
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: radius * 2 + 24, height: radius * 2 + 24)
        .accessibilityHidden(true)
    }
}

// Confetti (DESIGN §6): 70 pieces, white + near-black + yellow + challenge
// color, 1.8–3.4s falls, random spin. Canvas + TimelineView.
struct ConfettiView: View {
    var colorToken: String
    private struct Piece: Identifiable, Equatable {
        var id: Int
        var x: Double, y: Double, vy: Double, vx: Double, spin: Double, size: Double, colorIndex: Int
        static func == (a: Piece, b: Piece) -> Bool { a.id == b.id }
    }
    private let pieces: [Piece] = (0..<70).map { i in
        Piece(id: i, x: .random(in: 0...1), y: .random(in: -1.2...0.0),
              vy: .random(in: 0.25...0.5), vx: .random(in: -0.05...0.05),
              spin: .random(in: 0...360), size: .random(in: 4...8),
              colorIndex: Int.random(in: 0..<4))
    }
    private var start = Date()
    public var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSince(start)
                let c = FillColor.color(for: colorToken)
                let colors: [Color] = [.white, FillColor.ink, FillColor.confettiYellow, c]
                for p in pieces {
                    let y = (p.y + p.vy * min(t, 3.4)) * size.height
                    guard y < size.height + 10, t < 3.4 else { continue }
                    let x = (p.x + p.vx * t) * size.width
                    var inner = ctx
                    inner.translateBy(x: x, y: y)
                    inner.rotate(by: .degrees(p.spin + t * 200))
                    inner.fill(Path(CGRect(x: -p.size / 2, y: -p.size / 4,
                                           width: p.size, height: p.size / 2)),
                               with: .color(colors[p.colorIndex]))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
