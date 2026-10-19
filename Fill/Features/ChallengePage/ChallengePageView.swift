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
    /// Offscreen snapshots render with this false so their .task never
    /// re-renders (would recurse forever).
    var shareEnabled: Bool = true
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bandPulse = true
    @State private var shareImage: UIImage?

    public enum DayState: Equatable { case won(manual: Bool), missed, today(ratio: Double), future }

    public var body: some View {
        GeometryReader { g in
            let scale = g.size.height / 852
            let fb = (196 + 384 * snapshot.base) * scale
            let lh = snapshot.layer > 0 ? max(30, 384 * snapshot.layer) * scale : 0
            let fh = fb + lh
            let rescue = snapshot.outOfReach || snapshot.streakBroken
            ZStack(alignment: .bottom) {
                FillColor.surface.ignoresSafeArea()
                fillStack(scale: scale, fb: fb, lh: lh)
                    .grayscale(rescue ? 0.7 : 0)
                    .opacity(rescue ? 0.45 : 1)
                VStack(alignment: .leading, spacing: 0) {
                    headerRow.padding(.top, g.safeAreaInsets.top + 8 * scale)
                    Text(challenge.name).font(FillFont.pageTitle)
                        .padding(.horizontal, 20).padding(.top, 4)
                        .accessibilityAddTraits(.isHeader)
                    Text(ruleLine()).font(.system(size: 13, weight: .bold))
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
                    if showFirstWin {
                        heroBlock
                            .padding(.horizontal, 20)
                            .padding(.top, 30 * scale)
                        firstWinCard.padding(.top, 22 * scale)
                    }
                    Spacer(minLength: 0)
                }
                // Hero: inside the fill (white) when high, else just above it.
                // On an empty page it lives above the first-win card instead.
                if !showFirstWin {
                    heroBlock
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, heroBottom(fh: fh, scale: scale))
                }
                if showTodayPill {
                    todayPill.padding(.bottom, max(0, fb + lh / 2 - 12))
                        .padding(.trailing, 20)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                if showLogToday {
                    logTodayButton.padding(.bottom, max(0, fb + lh / 2 - 28))
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
            Text(dayText()).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FillColor.text3)
                .accessibilityLabel(dayText())
            if let img = shareImage {
                ShareLink(item: ShareImage(image: img),
                          message: Text(shareMessage()),
                          preview: SharePreview(challenge.name, image: Image(uiImage: img))) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FillColor.text3)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(Copy.shareProgress)
            }
        }.padding(.horizontal, 20)
        .task(id: shareVersion) {
            guard shareEnabled else { return }
            shareImage = ShareContent.renderImage(
                challenge: challenge, snapshot: snapshot,
                dayStates: dayStates, manualMode: manualMode)
        }
    }
    /// Re-render the card whenever visible progress changes.
    private var shareVersion: String {
        "\(snapshot.wins)-\(snapshot.todayValue)-\(snapshot.done)-\(challenge.claimed)-\(snapshot.moneyEarned)-\(snapshot.todayWon)-\(challenge.colorToken)"
    }
    /// Caption + progress + link (link only once Copy.appStoreLink is real).
    private func shareMessage() -> String {
        var m = "\(Copy.shareCaption)\n\(challenge.name) — \(pillText())\n\(heroNumber()) \(heroUnit()). \(heroLine())\n\(Copy.playingFor) \(maxRewardText()). \(Copy.viaFill)"
        if let url = URL(string: Copy.appStoreLink),
           url.scheme == "http" || url.scheme == "https" {
            m += "\n\(url.absoluteString)"
        }
        return m
    }
    private func pillText() -> String {
        if snapshot.outOfReach { return Copy.outOfReach }
        if snapshot.streakBroken { return Copy.streakBroken }
        if snapshot.done { return challenge.claimed ? Copy.rewarded : Copy.completed }
        switch challenge.metric {
        case .steps: return "\(Format.int(Int(challenge.target))) STEPS"
        case .rings: return "\(Int(challenge.target)) RINGS"
        case .exercise: return "\(Int(challenge.target)) MIN EXERCISE"
        case .run: return "\(Format.metric(challenge.target, metric: .run)) KM RUN"
        case .sleep: return "\(Format.metric(challenge.target, metric: .sleep)) H SLEEP"
        case .calories: return "\(Int(challenge.target)) KCAL"
        }
    }
    private func dayText() -> String {
        var t: String
        switch challenge.type {
        case .flex: t = "Day \(snapshot.dayIndex + 1) of \(challenge.y)"
        case .streak: t = "Day \(snapshot.wins + 1) of \(challenge.x)"
        case .once: t = "Any day"
        case .open: t = "\(snapshot.wins) wins so far"
        }
        if snapshot.done { t = "\(typeName()) · finished" }
        else if challenge.claimed { t = Copy.rewarded }
        if manualMode { t += " \(Copy.byHandShort)" }
        return t
    }
    private func typeName() -> String {
        switch challenge.type {
        case .flex: return "Flexible"; case .streak: return "Streak"
        case .once: return "One time"; case .open: return "No end"
        }
    }
    private func ruleLine() -> String {
        switch challenge.type {
        case .flex: return "Flexible · \(challenge.x) of \(challenge.y) days"
        case .streak: return "Streak · \(challenge.x) days in a row"
        case .once: return "One time · \(Format.metric(challenge.target, metric: challenge.metric)) \(challenge.metric.rawValue)"
        case .open:
            if challenge.reward.kind == .money, challenge.reward.payout == .jar {
                return "No end · jar opens at \(Format.money(challenge.reward.jarTarget))"
            }
            return "No end · until you stop"
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
            case .each: return "\(Format.money(r.amount * Decimal(challenge.x), currency: r.currency))"
            case .bonus: return "\(Format.money(r.amount * Decimal(challenge.x) + r.bonus, currency: r.currency))"
            case .end: return Format.money(r.amount, currency: r.currency)
            case .jar: return Format.money(r.jarTarget, currency: r.currency)
            }
        }
        if r.value > 0 { return "\(r.name) · \(Format.money(r.value, currency: r.currency))" }
        return r.name
    }
    private func goalRightText() -> String {
        if challenge.type == .flex, let e = snapshot.endDate { return Format.goalDate(e) }
        if challenge.type == .streak { return snapshot.done ? "DONE" : (snapshot.endDate.map(Format.goalDate) ?? "") }
        if challenge.reward.kind == .money, challenge.reward.payout == .jar { return "JAR OPENS" }
        return ""
    }

    // MARK: fill + today band
    private func fillStack(scale: CGFloat, fb: CGFloat, lh: CGFloat) -> some View {
        let c = FillColor.color(for: challenge.colorToken)
        return VStack(spacing: 0) {
            if lh > 0 {
                ZStack(alignment: .top) {
                    TodayStripes(color: c).frame(height: lh).opacity(bandPulse ? 1 : 0.65)
                    c.frame(height: 2)
                }.frame(height: lh)
            }
            c.frame(height: max(0, fb))
        }
    }

    // MARK: hero (DESIGN §4: inside the fill when fh ≥ 420, else above it)
    private func heroBottom(fh: CGFloat, scale: CGFloat) -> CGFloat {
        if fh >= 420 * scale { return max(0, fh - 140 * scale) }
        var b = fh + 16 * scale
        if showTodayPill { b += 54 * scale }
        if showLogToday { b += 78 * scale }
        return b
    }
    private var heroInsideFill: Bool {
        let scale: CGFloat = 1
        let fb = 196 + 384 * snapshot.base
        let lh = snapshot.layer > 0 ? max(30, 384 * snapshot.layer) : 0
        return fb + lh >= 420 * scale
    }
    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(heroNumber()).font(FillFont.hero(heroNumber().count > 4))
                    .monospacedDigit()
                    .foregroundStyle(heroInsideFill ? .white : FillColor.color(for: challenge.colorToken))
                Text(heroUnit()).font(FillFont.heroUnit)
                    .foregroundStyle(heroInsideFill ? .white : FillColor.ink)
            }
            .lineLimit(1)
            Text(heroLine()).font(FillFont.remaining)
                .foregroundStyle(heroInsideFill ? .white : FillColor.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(heroNumber()) \(heroUnit()). \(heroLine())")
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
        case .once: return "of \(Format.metric(challenge.target, metric: challenge.metric)) \(challenge.metric.rawValue)"
        case .open:
            if challenge.reward.kind == .money, challenge.reward.payout == .jar {
                return "of \(Format.money(challenge.reward.jarTarget, currency: challenge.reward.currency))"
            }
            return "earned"
        }
    }
    private func heroLine() -> String {
        if snapshot.done {
            if challenge.type == .streak { return "\(challenge.x) days in a row. Done." }
            return "Done."
        }
        if snapshot.outOfReach { return "\(snapshot.need) wins needed, \(snapshot.daysLeft) days left" }
        if let broken = snapshot.streakBrokenOnDay { return Copy.brokenLine(broken) }
        switch challenge.type {
        case .flex: return "\(snapshot.need) wins to go in \(snapshot.daysLeft) days"
        case .streak: return "\(snapshot.need) days to go"
        case .once:
            let left = max(0, challenge.target - snapshot.best)
            let noun = challenge.metric == .run ? "run" : "day"
            return "\(Format.metric(left, metric: challenge.metric)) \(challenge.metric.rawValue) to go in one \(noun)"
        case .open:
            if challenge.reward.kind == .money, challenge.reward.payout == .jar {
                let amount = (challenge.reward.amount as NSDecimalNumber).doubleValue
                let target = (challenge.reward.jarTarget as NSDecimalNumber).doubleValue
                let saved = amount * Double(snapshot.wins)
                let left = max(0, target - saved)
                let winsNeeded = Int((left / max(amount, 1)).rounded(.up))
                return "\(Format.money(Decimal(string: String(format: "%.0f", left)) ?? 0, currency: challenge.reward.currency)) to go in \(winsNeeded) wins"
            }
            return "keep going"
        }
    }

    // MARK: today pill + log today button (SPEC §7.3 item 9)
    private var showTodayPill: Bool {
        challenge.type != .once && !snapshot.done && !snapshot.outOfReach
            && !snapshot.streakBroken && !manualMode
    }
    private var todayPill: some View {
        let text = todayPillText
        return Text(text)
            .font(FillFont.mono(10.5)).foregroundStyle(FillColor.color(for: challenge.colorToken))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.white, in: Capsule())
            .accessibilityLabel(text)
    }
    private var todayPillText: String {
        guard snapshot.todayWon else { return "TODAY · \(remainingToday()) TO GO" }
        if case .won(let manual)? = dayStates.first(where: {
            if case .today = $0 { return true }
            return false
        }), manual { return "\(Copy.todayWon) \(Copy.byHand)" }
        return Copy.todayWon
    }
    private var showLogToday: Bool {
        manualMode && !snapshot.done && !snapshot.outOfReach && !snapshot.streakBroken && challenge.type != .once
    }
    private var logTodayButton: some View {
        Button("Log today \(Format.metric(snapshot.todayValue, metric: challenge.metric)) / \(Format.metric(challenge.target, metric: challenge.metric))") {
            app.showingLogToday = LogTodayRequest(metric: challenge.metric,
                                                  target: challenge.target,
                                                  colorToken: challenge.colorToken)
        }
        .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
        .frame(maxWidth: .infinity).frame(height: 56)
        .background(FillColor.ink, in: RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 20)
        .accessibilityLabel("Log today")
    }
    private func remainingToday() -> String {
        Notifications.remainingText(challenge: challenge, todayValue: snapshot.todayValue)
    }

    // MARK: first-win card (DESIGN §4: top = RT + 34)
    private var showFirstWin: Bool {
        snapshot.wins == 0 && !snapshot.done && !snapshot.outOfReach && !snapshot.streakBroken
    }
    private var firstWinCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Copy.firstWin).font(FillFont.mono(11))
                .foregroundStyle(FillColor.color(for: challenge.colorToken))
            Text("\(MetricDefaults.verb(for: challenge.metric)) \(Format.metric(challenge.target, metric: challenge.metric)) \(MetricDefaults.unit(for: challenge.metric)) today")
                .font(.system(size: 17, weight: .bold))
            Text(firstWinGets).font(.system(size: 15, weight: .medium))
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
            return "and get \(Format.money(r.amount, currency: r.currency))"
        }
        if r.kind == .item, r.itemPayout == .save, r.value > 0 {
            return "and get \(Format.money(Derive.itemPerWin(value: r.value, x: max(1, challenge.x)), currency: r.currency)) toward \(r.name)"
        }
        return "and you are one step closer to \(r.name)"
    }

    // MARK: footer (SPEC §7.3 item 11)
    private var footer: some View {
        Group {
            if snapshot.done {
                Button(Copy.seeTrophy) { app.celebrating = challenge.id }
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(.white.opacity(0.2), in: Capsule())
                    .overlay(Capsule().stroke(.white, lineWidth: 1.5))
                    .accessibilityLabel(Copy.seeTrophy)
            } else if challenge.reward.kind == .item, challenge.reward.itemPayout == .save, challenge.reward.value > 0 {
                footerGrid(left: Copy.savedTowardIt,
                           leftValue: Format.money(Derive.itemSaved(value: challenge.reward.value, x: challenge.x, wins: snapshot.wins), currency: challenge.reward.currency),
                           right: Copy.nextWin,
                           rightValue: "+\(Format.money(Derive.itemNextWin(value: challenge.reward.value, x: challenge.x, wins: snapshot.wins), currency: challenge.reward.currency))")
            } else if challenge.reward.kind == .money,
                      challenge.reward.payout == .each || challenge.reward.payout == .bonus,
                      challenge.type != .open {
                footerGrid(left: Copy.earned,
                           leftValue: Format.money(snapshot.moneyEarned, currency: challenge.reward.currency),
                           right: Copy.nextWin,
                           rightValue: "+\(Format.money(snapshot.perWin, currency: challenge.reward.currency))")
            } else if challenge.reward.kind == .money, challenge.type == .open {
                footerGrid(left: Copy.nextWin,
                           leftValue: "+\(Format.money(snapshot.perWin, currency: challenge.reward.currency))",
                           right: nil, rightValue: nil)
            } else if challenge.reward.kind == .money, challenge.reward.payout == .end {
                footerGrid(left: Copy.rewardAtTheEnd,
                           leftValue: Format.money(challenge.reward.amount, currency: challenge.reward.currency),
                           right: nil, rightValue: nil)
            } else if challenge.type == .streak {
                footerGrid(left: Copy.missADay, leftValue: Copy.backToZero,
                           right: nil, rightValue: nil)
            } else if challenge.reward.kind == .item, challenge.reward.value > 0 {
                footerGrid(left: Copy.worth,
                           leftValue: Format.money(challenge.reward.value, currency: challenge.reward.currency),
                           right: nil, rightValue: nil)
            } else if challenge.reward.kind == .item, challenge.type == .open {
                Button(Copy.imDoneClaim(challenge.reward.name)) { closeItem() }
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(.white.opacity(0.2), in: Capsule())
                    .overlay(Capsule().stroke(.white, lineWidth: 1.5))
                    .accessibilityLabel(Copy.imDoneClaim(challenge.reward.name))
            } else {
                footerGrid(left: Copy.earned,
                           leftValue: Format.money(snapshot.moneyEarned, currency: challenge.reward.currency),
                           right: Copy.nextWin,
                           rightValue: "+\(Format.money(snapshot.perWin, currency: challenge.reward.currency))")
            }
        }
    }
    private func footerGrid(left: String, leftValue: String, right: String?, rightValue: String?) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(left).font(FillFont.mono(10)).foregroundStyle(.white.opacity(0.7))
                Text(leftValue).font(FillFont.footValue).monospacedDigit().foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer()
            if let right, let rightValue {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(right).font(FillFont.mono(10)).foregroundStyle(.white.opacity(0.7))
                    Text(rightValue).font(FillFont.footValue).monospacedDigit().foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(left) \(leftValue)\(right.map { ", \($0) \(rightValue ?? "")" } ?? "")")
    }

    /// No-end item "I'm done" (SPEC §6): closed date set → done → celebration.
    private func closeItem() {
        let id = challenge.id
        if let r = (try? context.fetch(FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate { $0.id == id })))?.first {
            r.closedAt = Date()
            try? context.save()
        }
        app.celebrating = challenge.id
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
