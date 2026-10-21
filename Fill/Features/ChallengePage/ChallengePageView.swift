import SwiftUI
import SwiftData

// SPEC §7.3 — Challenge page. DESIGN §4 layout (393×852, scaled by height/852):
// y60 pill+day · y94 name · rule line · y172 day bars · y250 goal labels ·
// y272 goal line · first-win card RT+34 · fill from bottom (floor 196, PR 384)
// · hero positioned by the fill height · today pill on the band · footer at
// bottom 112 with per-reward variants · rescue card over a greyed fill.
public struct ChallengePageView: View {
    var challenge: Challenge
    var snapshot: Snapshot
    var dayStates: [DayState] = [] // parallel to window, oldest-first
    var manualMode: Bool = false
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bandPulse = true
    @State private var sharePayload: SharePayload?

    public enum DayState: Equatable { case won(manual: Bool), missed, today(ratio: Double), future }

    public var body: some View {
        GeometryReader { g in
            let scale = g.size.height / 852
            let fb = (196 + 384 * snapshot.base) * scale
            let lh = snapshot.layer > 0 ? max(30, 384 * snapshot.layer) * scale : 0
            let rescue = snapshot.outOfReach || snapshot.streakBroken
            ZStack(alignment: .bottom) {
                FillColor.surface.ignoresSafeArea()
                fillStack(scale: scale, fb: fb, lh: lh)
                    .grayscale(rescue ? 0.7 : 0)
                    .opacity(rescue ? 0.45 : 1)
                VStack(alignment: .leading, spacing: 0) {
                    headerRow.padding(.top, g.safeAreaInsets.top + 8 * scale)
                    HStack(alignment: .center, spacing: 12) {
                        Text(challenge.name).font(FillFont.scaled(24, weight: .heavy, relativeTo: .title1))
                            .lineLimit(1).minimumScaleFactor(0.7).truncationMode(.tail)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 12)
                        if showHeroLog { heroLogPill }
                    }
                    .padding(.horizontal, 20).padding(.top, 4)
                    Text(ruleLine()).font(FillFont.scaled(13, weight: .bold))
                        .foregroundStyle(FillColor.text3)
                        .padding(.horizontal, 20).padding(.top, 2)
                    if challenge.type != .once {
                        DayBars(total: barTotal(), wins: wonIdx(), manualWins: manualIdx(),
                                misses: missIdx(), todayIndex: todayIdx(),
                                todayRatio: snapshot.todayRatio, colorToken: challenge.colorToken)
                            .padding(.horizontal, 20).padding(.top, 25 * scale)
                    }
                    goalLine.padding(.horizontal, 20)
                        .padding(.top, (challenge.type == .once ? 78 : 38) * scale)
                    // Hero sits right under the target (goal) line.
                    heroBlock(inFill: heroInsideFill)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 16 * scale)
                    if showFirstWin {
                        firstWinCard.padding(.top, 22 * scale)
                    }
                    Spacer(minLength: 0)
                }
                if showBandPill {
                    todayPill()
                        .padding(.bottom, max(0, fb + lh / 2 - 12 * scale))
                        .padding(.trailing, 20)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                footer
                    .padding(.horizontal, 20).padding(.bottom, 112 * scale)
                if rescue {
                    RescueView(challenge: challenge, snapshot: snapshot)
                }
            }
        }
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.9))
                withAnimation(.easeInOut(duration: 0.9)) { bandPulse.toggle() }
            }
        }
    }

// MARK: header + rule
    private var headerRow: some View {
        HStack {
            ActivityPill(metric: challenge.metric.rawValue, text: pillText(),
                         colorToken: challenge.colorToken,
                         status: snapshot.outOfReach || snapshot.streakBroken ? .danger : .normal)
            Spacer()
            Text(dayText()).font(FillFont.mono(13))
                .foregroundStyle(FillColor.text3)
                .accessibilityLabel(dayText())
            Button(action: share) {
                Image(systemName: "square.and.arrow.up")
                    .font(FillFont.scaled(16, weight: .semibold))
                    .foregroundStyle(FillColor.text3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Copy.share)
        }
        .padding(.horizontal, 20)
        .sheet(item: $sharePayload) { p in
            ActivityView(items: p.items)
        }
    }

    private func share() {
        var items: [Any] = [ChallengeShare.text(challenge: challenge, snapshot: snapshot),
                            ChallengeShare.appURL]
        if let image = ChallengeShare.makeImage(challenge: challenge, snapshot: snapshot) {
            items.insert(image, at: 0)
        }
        sharePayload = SharePayload(items: items)
    }
    private func pillText() -> String {
        if snapshot.outOfReach { return Copy.outOfReach }
        if snapshot.streakBroken { return Copy.streakBroken }
        if snapshot.done { return challenge.claimed ? Copy.rewarded : Copy.completed }
        switch challenge.metric {
        case .steps: return Copy.pillSteps(Format.int(Int(challenge.target)))
        case .rings: return Copy.pillRings("\(Int(challenge.target))")
        case .exercise: return Copy.pillExercise("\(Int(challenge.target))")
        case .run: return Copy.pillRun(Format.metric(challenge.target, metric: .run))
        case .sleep: return Copy.pillSleep(Format.metric(challenge.target, metric: .sleep))
        case .calories: return Copy.pillCalories("\(Int(challenge.target))")
        }
    }
    private func dayText() -> String {
        if challenge.claimed && snapshot.done {
            return Copy.claimed
        } else if snapshot.done {
            return Derive.typeName(challenge.type) + Copy.finishedSuffix
        } else {
            switch challenge.type {
            case .flex: return Copy.dayFlex(snapshot.dayIndex + 1, of: challenge.y)
            case .streak: return Copy.dayStreak(snapshot.wins + 1, of: challenge.x)
            case .once: return Copy.anyDay
            case .open: return Copy.dayOpen(snapshot.wins)
            }
        }
    }
    private func ruleLine() -> String {
        switch challenge.type {
        case .flex: return Copy.ruleFlex(challenge.x, challenge.y)
        case .streak: return Copy.ruleStreak(challenge.x)
        case .once: return Copy.ruleOnce
        case .open:
            if challenge.reward.kind == .money, challenge.reward.payout == .jar {
                return Copy.ruleJar(Format.money(challenge.reward.jarTarget,
                                                 currency: challenge.reward.currency))
            }
            return Copy.ruleOpen
        }
    }

    // MARK: goal line (labels 22pt above the line)
    private var goalLine: some View {
        VStack(spacing: 9) {
            HStack {
                Text(maxRewardText()).font(FillFont.mono(10.5))
                    .foregroundStyle(FillColor.color(for: challenge.colorToken))
                Spacer()
                Text(goalRightText()).font(FillFont.mono(10.5))
                    .foregroundStyle(FillColor.color(for: challenge.colorToken))
            }
            Rectangle()
                .stroke(FillColor.color(for: challenge.colorToken).opacity(0.7),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .frame(height: 1.5)
        }
        .accessibilityHidden(true)
    }
    private func maxRewardText() -> String {
        let r = challenge.reward
        if r.kind == .money {
            switch r.payout {
            case .each:
                if challenge.type == .open {
                    return Copy.goalNoEndEach(Format.money(r.amount, currency: r.currency))
                }
                return Format.money(r.amount * Decimal(challenge.x), currency: r.currency)
            case .bonus: return Format.money(r.amount * Decimal(challenge.x) + r.bonus, currency: r.currency)
            case .end: return Format.money(r.amount, currency: r.currency)
            case .jar: return Format.money(r.jarTarget, currency: r.currency)
            }
        }
        if r.value > 0 { return "\(r.name) · \(Format.money(r.value, currency: r.currency))" }
        return r.name
    }
    private func goalRightText() -> String {
        if challenge.type == .flex, let e = snapshot.endDate { return Format.goalDate(e) }
        if challenge.type == .streak {
            return snapshot.done ? Copy.goalStreakDone : (snapshot.endDate.map(Format.goalDate) ?? "")
        }
        if challenge.reward.kind == .money, challenge.reward.payout == .jar { return Copy.goalJar }
        return ""
    }

    // MARK: fill (gel base from the bottom + today band on top)
    private func fillStack(scale: CGFloat, fb: CGFloat, lh: CGFloat) -> some View {
        let c = FillColor.color(for: challenge.colorToken)
        // Wave stays on (only done goes flat); Reduce Motion stills it.
        let wave = !snapshot.done
        return VStack(spacing: 0) {
            if lh > 0 {
                ZStack(alignment: .top) {
                    TodayStripes(color: c).frame(height: lh).opacity(bandPulse ? 1 : 0.65)
                    c.frame(height: 2)
                }.frame(height: lh)
            }
            GelFill(color: c, animated: !reduceMotion && wave, wave: wave)
                .frame(height: max(0, fb))
                .animation(reduceMotion ? nil : .timingCurve(0.3, 0.9, 0.3, 1, duration: 1.1), value: fb)
        }
    }

    // MARK: hero (white inside the fill when it fills most of the page,
    // else ink just above it)
    // The hero sits under the target line; white once the fill runs high.
    private var heroInsideFill: Bool {
        let fb = 196 + 384 * snapshot.base
        let lh = snapshot.layer > 0 ? max(30, 384 * snapshot.layer) : 0
        return fb + lh >= 420 // DESIGN §4
    }
    private func heroBlock(inFill: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(heroNumber()).font(FillFont.hero(heroNumber().count > 4))
                    .monospacedDigit()
                    .foregroundStyle(inFill ? .white : FillColor.color(for: challenge.colorToken))
                Text(heroUnit()).font(FillFont.heroUnit)
                    .foregroundStyle(inFill ? .white : FillColor.ink)
            }
            .lineLimit(1)
            heroLineView(inFill: inFill)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(heroNumber()) \(heroUnit()). \(heroLine())")
    }

    private func heroLineView(inFill: Bool) -> Text {
        let color = inFill ? Color.white : FillColor.ink
        let numberColor = inFill ? Color.white : FillColor.color(for: challenge.colorToken)
        // Flex active: "Need X wins in Y days" — numbers bold in hero color.
        if case .flex = challenge.type,
           !snapshot.done, !snapshot.outOfReach, snapshot.streakBrokenOnDay == nil {
            return (Text("Need ")
                .font(FillFont.scaled(21)).foregroundStyle(color) + Text("\(snapshot.need)")
                .font(FillFont.scaled(21, weight: .bold)).foregroundStyle(numberColor) + Text(" wins in ")
                .font(FillFont.scaled(21)).foregroundStyle(color) + Text("\(snapshot.daysLeft)")
                .font(FillFont.scaled(21, weight: .bold)).foregroundStyle(numberColor) + Text(" days")
                .font(FillFont.scaled(21)).foregroundStyle(color))
        }
        return Text(heroLine()).font(FillFont.remaining)
            .foregroundStyle(color)
    }
    private func heroNumber() -> String {
        switch challenge.type {
        case .flex, .streak: return "\(snapshot.wins)"
        case .once: return Format.metric(snapshot.best, metric: challenge.metric)
        case .open:
            if challenge.reward.kind == .money { return Format.money(snapshot.moneyEarned, currency: challenge.reward.currency) }
            return "\(snapshot.wins)"
        }
    }
    private func heroUnit() -> String {
        switch challenge.type {
        case .flex: return "of \(challenge.x) wins"
        case .streak: return "of \(challenge.x) days"
        case .once:
            return "of \(Format.metric(challenge.target, metric: challenge.metric)) \(MetricDefaults.unit(for: challenge.metric))"
        case .open:
            if challenge.reward.kind == .money, challenge.reward.payout == .jar {
                return "of \(Format.money(challenge.reward.jarTarget, currency: challenge.reward.currency))"
            }
            if challenge.reward.kind == .money { return "earned" }
            return "wins"
        }
    }
    private func heroLine() -> String {
        if snapshot.done {
            switch challenge.type {
            case .flex: return Copy.heroFlexDone(challenge.x)
            case .streak: return Copy.heroStreakDone(challenge.x)
            case .once:
                return Copy.heroOnceDone(
                    target: Format.metric(challenge.target, metric: challenge.metric),
                    unit: MetricDefaults.unit(for: challenge.metric),
                    run: challenge.metric == .run)
            case .open: return Copy.dayOpen(snapshot.wins)
            }
        }
        if snapshot.outOfReach {
            return Copy.heroOutOfReach(need: snapshot.need, daysLeft: snapshot.daysLeft)
        }
        if let broken = snapshot.streakBrokenOnDay { return Copy.brokenLine(broken) }
        switch challenge.type {
        case .flex:
            return Copy.heroFlexActive(need: snapshot.need, daysLeft: snapshot.daysLeft)
        case .streak: return Copy.heroStreakActive(need: snapshot.need)
        case .once:
            let left = max(0, challenge.target - snapshot.best)
            return Copy.heroOnceActive(
                left: Format.metric(left, metric: challenge.metric),
                unit: MetricDefaults.unit(for: challenge.metric),
                run: challenge.metric == .run)
        case .open:
            if challenge.reward.kind == .money, challenge.reward.payout == .jar {
                let amount = (challenge.reward.amount as NSDecimalNumber).doubleValue
                let target = (challenge.reward.jarTarget as NSDecimalNumber).doubleValue
                let saved = amount * Double(snapshot.wins)
                let left = max(0, target - saved)
                let winsNeeded = Int((left / max(amount, 1)).rounded(.up))
                let leftText = Format.money(Decimal(string: String(format: "%.0f", left)) ?? 0,
                                            currency: challenge.reward.currency)
                return Copy.heroJarLeft(leftText, wins: winsNeeded)
            }
            return Copy.dayOpen(snapshot.wins)
        }
    }

    // MARK: today pill (SPEC §7.3 item 9)
    // Today stays on the band; only the manual log action moves up.
    private var showTodayPill: Bool {
        challenge.type != .once && !snapshot.done && !snapshot.outOfReach
            && !snapshot.streakBroken
    }
    /// Manual: LOG MANUALLY pill always stays up (even after a win).
    /// The TODAY pill stays on the band.
    private var showHeroLog: Bool { showTodayPill && manualMode }
    private var showBandPill: Bool { showTodayPill }
    private var heroLogPill: some View {
        return Button(action: openLogToday) {
            Text(Copy.logManually)
                .font(FillFont.mono(10.5)).foregroundStyle(FillColor.color(for: challenge.colorToken))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.white, in: Capsule())
                .shadow(color: FillColor.shadow.opacity(0.12), radius: 6, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Copy.logManually)
    }
    private func todayPill() -> some View {
        let text = todayPillText
        return Text(text)
            .font(FillFont.mono(10.5)).foregroundStyle(FillColor.color(for: challenge.colorToken))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.white, in: Capsule())
            .lineLimit(1).minimumScaleFactor(0.7)
            .accessibilityLabel(text)
    }
    private var todayPillText: String {
        guard snapshot.todayWon else {
            return Copy.todayToGo(Notifications.remainingText(challenge: challenge,
                                                              todayValue: snapshot.todayValue))
        }
        if manualMode {
            let target = "\(Format.metric(challenge.target, metric: challenge.metric)) \(MetricDefaults.unit(for: challenge.metric).uppercased())"
            return Copy.todayGoalAchieved(target)
        }
        return Copy.todayWon
    }
    private func openLogToday() {
        app.showingLogToday = LogTodayRequest(metric: challenge.metric,
                                              target: challenge.target,
                                              colorToken: challenge.colorToken)
    }

    // MARK: first-win card (DESIGN §4: top = RT + 34)
    // One-time challenges never show it: a single attempt has no first win.
    // PREVIEW: disabled to see the page without the box (revert to re-enable).
    private var showFirstWin: Bool { false }
    private var firstWinCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Copy.firstWin).font(FillFont.mono(11))
                .foregroundStyle(FillColor.color(for: challenge.colorToken))
            Text(Copy.firstWinWhat(verb: MetricDefaults.verb(for: challenge.metric),
                                   target: Format.metric(challenge.target, metric: challenge.metric),
                                   unit: MetricDefaults.unit(for: challenge.metric)))
                .font(FillFont.scaled(17, weight: .bold))
            Text(firstWinGets).font(FillFont.scaled(15, weight: .medium))
                .foregroundStyle(FillColor.text2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 24)
            .stroke(FillColor.color(for: challenge.colorToken).opacity(0.55),
                    style: StrokeStyle(lineWidth: 2, dash: [8])))
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }
    private var firstWinGets: String {
        let r = challenge.reward
        if r.kind == .money, r.payout == .each || r.payout == .bonus {
            return Copy.firstWinGetsMoney(Format.money(r.amount, currency: r.currency))
        }
        if r.kind == .item, r.itemPayout == .save, r.value > 0 {
            return Copy.firstWinGetsSave(
                Format.money(Derive.itemPerWin(value: r.value, x: max(1, challenge.x)),
                             currency: r.currency), name: r.name)
        }
        return Copy.firstWinGetsOther(r.name)
    }

    // MARK: footer (SPEC §7.3 item 11)
    private var footer: some View {
        Group {
            if snapshot.done {
                Button(Copy.seeTrophy) { app.celebrating = challenge.id }
                    .font(FillFont.scaled(17, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(.white.opacity(0.2), in: Capsule())
                    .overlay(Capsule().stroke(.white, lineWidth: 1.5))
                    .accessibilityLabel(Copy.seeTrophy)
            } else if challenge.reward.kind == .item, challenge.reward.itemPayout == .save,
                      challenge.reward.value > 0,
                      challenge.type == .flex || challenge.type == .streak {
                footerGrid(left: Copy.savedTowardIt,
                           leftValue: Format.money(Derive.itemSaved(value: challenge.reward.value, x: challenge.x, wins: snapshot.wins), currency: challenge.reward.currency),
                           right: Copy.nextWin,
                           rightValue: Copy.plus(Format.money(Derive.itemNextWin(value: challenge.reward.value, x: challenge.x, wins: snapshot.wins), currency: challenge.reward.currency)))
            } else if challenge.reward.kind == .money,
                      challenge.reward.payout == .each || challenge.reward.payout == .bonus,
                      challenge.type != .open {
                footerGrid(left: Copy.earned,
                           leftValue: Format.money(snapshot.moneyEarned, currency: challenge.reward.currency),
                           right: Copy.nextWin,
                           rightValue: Copy.plus(Format.money(snapshot.perWin, currency: challenge.reward.currency)))
            } else if challenge.reward.kind == .money, challenge.type == .open {
                footerGrid(left: Copy.nextWin,
                           leftValue: Copy.plus(Format.money(snapshot.perWin, currency: challenge.reward.currency)),
                           right: nil, rightValue: nil)
            } else if challenge.reward.kind == .money, challenge.reward.payout == .end {
                footerGrid(left: Copy.rewardAtTheEnd,
                           leftValue: Format.money(challenge.reward.amount, currency: challenge.reward.currency),
                           right: nil, rightValue: nil)
            } else if challenge.type == .streak {
                footerGrid(left: Copy.missADay, leftValue: Copy.backToZero,
                           right: nil, rightValue: nil)
            } else if challenge.reward.kind == .item, challenge.type == .open {
                Button(Copy.imDoneClaim(challenge.reward.name)) { closeItem() }
                    .font(FillFont.scaled(17, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(.white.opacity(0.2), in: Capsule())
                    .overlay(Capsule().stroke(.white, lineWidth: 1.5))
                    .accessibilityLabel(Copy.imDoneClaim(challenge.reward.name))
            } else if challenge.reward.kind == .item, challenge.reward.value > 0 {
                footerGrid(left: Copy.worth,
                           leftValue: Format.money(challenge.reward.value, currency: challenge.reward.currency),
                           right: nil, rightValue: nil)
            } else if challenge.reward.kind == .item {
                footerGrid(left: Copy.rewardAtTheEnd,
                           leftValue: challenge.reward.name,
                           right: nil, rightValue: nil)
            } else {
                footerGrid(left: Copy.earned,
                           leftValue: Format.money(snapshot.moneyEarned, currency: challenge.reward.currency),
                           right: Copy.nextWin,
                           rightValue: Copy.plus(Format.money(snapshot.perWin, currency: challenge.reward.currency)))
            }
        }
    }
    private func footerGrid(left: String, leftValue: String, right: String?, rightValue: String?) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(left).font(FillFont.mono(10)).foregroundStyle(.white.opacity(0.7))
                footerValue(leftValue, alignment: .leading)
            }
            Spacer()
            if let right, let rightValue {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(right).font(FillFont.mono(10)).foregroundStyle(.white.opacity(0.7))
                    footerValue(rightValue, alignment: .trailing)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(left) \(leftValue)\(right.map { ", \($0) \(rightValue ?? "")" } ?? "")")
    }

    private func footerValue(_ s: String, alignment: HorizontalAlignment) -> some View {
        // "90,000 bucks" -> number big, bucks small so EARNED / NEXT WIN fit.
        if s.hasSuffix(" bucks") {
            let number = String(s.dropLast(" bucks".count))
            return AnyView(
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    if alignment == .trailing { Spacer(minLength: 0) }
                    Text(number).font(FillFont.footValue).monospacedDigit().foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text("bucks").font(FillFont.mono(11)).foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                    if alignment == .leading { Spacer(minLength: 0) }
                }
            )
        }
        return AnyView(
            Text(s).font(FillFont.footValue).monospacedDigit().foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
        )
    }

    /// No-end item "I'm done" (SPEC §6): closed date set → done → celebration.
    private func closeItem() {
        let id = challenge.id
        if let r = (try? context.fetch(FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate { $0.id == id })))?.first {
            r.closedAt = Date()
            try? context.save()
        }
        app.dataVersion += 1
        app.celebrating = id
    }

    // day bars helpers (indices)
    private func barTotal() -> Int {
        switch challenge.type {
        case .flex: return challenge.y
        case .streak: return challenge.x
        case .open: return max(7, snapshot.dayIndex + 1)
        case .once: return 0
        }
    }
    private func wonIdx() -> Set<Int> { dayStates.enumerated().compactMap { if case .won = $1 { return $0 } else { return nil } }.reduce(into: Set()) { $0.insert($1) } }
    private func manualIdx() -> Set<Int> { dayStates.enumerated().compactMap { if case .won(let m) = $1, m { return $0 } else { return nil } }.reduce(into: Set()) { $0.insert($1) } }
    private func missIdx() -> Set<Int> { dayStates.enumerated().compactMap { if case .missed = $1 { return $0 } else { return nil } }.reduce(into: Set()) { $0.insert($1) } }
    private func todayIdx() -> Int? { dayStates.firstIndex { if case .today = $0 { return true } else { return false } } }
}

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

// TodayBand stripes (DESIGN §1.1): repeating 45° stripes of C at 55%/35%
// over white, 6pt each, 2pt top border in C; pulse 1→0.65→1 over 1.8s.
struct TodayStripes: View {
    var color: Color
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            var stripe = Path()
            let period: CGFloat = 12
            var x = -size.height
            while x < size.width {
                stripe.move(to: CGPoint(x: x, y: 0))
                stripe.addLine(to: CGPoint(x: x + size.height, y: size.height))
                x += period
            }
            context.stroke(stripe, with: .color(color.opacity(0.55)), lineWidth: 6)
            var stripe2 = Path()
            x = -size.height + 6
            while x < size.width {
                stripe2.move(to: CGPoint(x: x, y: 0))
                stripe2.addLine(to: CGPoint(x: x + size.height, y: size.height))
                x += period
            }
            context.stroke(stripe2, with: .color(color.opacity(0.35)), lineWidth: 6)
        }
        .allowsHitTesting(false)
    }
}
