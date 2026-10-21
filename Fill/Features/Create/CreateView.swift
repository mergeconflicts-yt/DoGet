import SwiftUI
import SwiftData

// SPEC §7.6 + DESIGN §5 + mockups IMG_5620–5628 — Create: full screen in the
// chosen color, × + NEW CHALLENGE, one sentence with 3 blanks filled strictly
// in order (dashed/pulsing → white pill), facts row, name + 8 colors, main
// button; each blank opens a bottom panel (white sheet, scrim, Done).

public struct CreateView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var model = CreateModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var header: some View {
        ZStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark").font(FillFont.scaled(16, weight: .bold))
                    .foregroundStyle(.white).frame(width: 44, height: 44)
                    .background(.white.opacity(0.2), in: Circle())
            }
            .accessibilityLabel(Copy.close)
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(Copy.newChallenge).font(FillFont.mono(12)).tracking(1.4)
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.top, 10)
    }

    // MARK: - Sentence (I'll [what] [suffix] [how often] to win [reward])

    private var sentence: some View {
        FlowLayout(spacing: 8) {
            Text("I'll").font(FillFont.sentence).foregroundStyle(.white)
            blank(0, label: Copy.blankWhat)
            if model.filled.contains(0) {
                Text(MetricDefaults.suffix(for: model.metric))
                    .font(FillFont.sentence).foregroundStyle(.white)
            }
            blank(1, label: Copy.blankHowOften)
            Text("to win").font(FillFont.sentence).foregroundStyle(.white)
            blank(2, label: Copy.blankReward)
        }
        .accessibilityElement(children: .combine)
    }

    private func blank(_ i: Int, label: String) -> some View {
        let isFilled = model.filled.contains(i)
        let locked = (0..<i).contains { !model.filled.contains($0) }
        return Button {
            model.tapBlank(i)
        } label: {
            Text(isFilled ? filledText(i) : label)
                .font(FillFont.scaled(isFilled ? 24 : 26, weight: .heavy))
                .lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(isFilled ? FillColor.color(for: model.colorToken)
                                          : .white.opacity(locked ? 0.35 : 0.75))
                .padding(.horizontal, isFilled ? 16 : 18).padding(.vertical, 9)
                .background {
                    if isFilled {
                        Capsule().fill(.white)
                            .shadow(color: FillColor.shadow.opacity(0.12), radius: 6, y: 6)
                    } else {
                        Capsule()
                            .stroke(.white.opacity(locked ? 0.35 : 0.55),
                                    style: StrokeStyle(lineWidth: 2.5, dash: [8]))
                    }
                }
        }
        .buttonStyle(.plain)
        .opacity(!isFilled && !locked && !reduceMotion ? (pulseOn ? 1 : 0.6) : 1)
        .modifier(ShakeEffect(animatableData: shakeTarget == i ? shakeTrigger : 0))
        .onChange(of: model.shakeBlank) { _, new in
            guard let new, !reduceMotion else { return }
            shakeTarget = new
            shakeTrigger = 0
            withAnimation(.easeInOut(duration: 0.5)) { shakeTrigger = 1 }
        }
        .accessibilityLabel(isFilled ? filledText(i) : label)
        .accessibilityHint(locked ? Copy.lockedHint(model.blankName(i)) : "")
    }

    @State private var pulseOn = true
    @State private var shakeTrigger: CGFloat = 0
    @State private var shakeTarget: Int? = nil

    public var body: some View {
        let c = FillColor.color(for: model.colorToken)
        ZStack(alignment: .bottom) {
            c.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                header
                sentence
                factsRow
                if let h = model.hint {
                    Text(h).font(FillFont.scaled(15, weight: .semibold))
                        .foregroundStyle(.white)
                        .accessibilityLabel(h)
                }
                Spacer(minLength: 0)
                nameRow
                colorRow
                startButton
            }
            .padding(.horizontal, 22).padding(.bottom, 16)
            if let p = model.openPanel {
                panelScrim
                panel(p)
            }
        }
        .sensoryFeedback(.warning, trigger: model.hint)
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.9))
                withAnimation(.easeInOut(duration: 0.9)) { pulseOn.toggle() }
            }
        }
    }

    private func filledText(_ i: Int) -> String {
        switch i {
        case 0: return actText()
        case 1: return ruleText()
        case 2: return Derive.rewardPhrase(model.buildReward(), x: model.draft.x ?? 0)
        default: return ""
        }
    }
    private func actText() -> String {
        let target = Format.metric(model.target, metric: model.metric)
        switch model.metric {
        case .steps: return Copy.actSteps(target)
        case .rings: return Copy.actRings("\(Int(model.target))")
        case .exercise: return Copy.actExercise("\(Int(model.target))")
        case .run: return Copy.actRun(target)
        case .sleep: return Copy.actSleep(target)
        case .calories: return Copy.actCalories(target)
        }
    }
    private func ruleText() -> String {
        switch model.draft.type {
        case .flex: return Copy.createRuleFlex(model.draft.x ?? 20, model.draft.y ?? 30)
        case .streak: return Copy.createRuleStreak(model.draft.x ?? 30)
        case .once: return Copy.createRuleOnce
        case .open: return Copy.createRuleOpen
        case nil: return Copy.blankHowOften
        }
    }

    // MARK: - Facts row (MOST YOU CAN WIN · ENDS · MISSES ALLOWED)

    private var factsRow: some View {
        HStack(spacing: 10) {
            factTile(Copy.mostYouCanWin, model.factsMax, flex: 1.35)
            factTile(Copy.ends, model.factsEnds, flex: 0.75)
            factTile(Copy.missesAllowed, model.factsMisses, flex: 1)
        }
    }
    private func factTile(_ title: String, _ value: String, flex: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(FillFont.mono(9)).tracking(0.4)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Text(value).font(FillFont.scaled(16, weight: .bold)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity * flex, alignment: .leading)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }

    // MARK: - Name + colors + main button

    private var nameRow: some View {
        VStack(spacing: 0) {
            TextField(model.draft.metric == nil ? "" : model.autoName, text: Binding(
                get: { model.name },
                set: { model.setName($0) }))
                .font(FillFont.scaled(16, weight: .semibold)).foregroundStyle(.white)
                .autocorrectionDisabled().textInputAutocapitalization(.words)
                .padding(.vertical, 10)
                .accessibilityLabel(Copy.challengeNameLabel)
            Rectangle().fill(.white.opacity(0.35)).frame(height: 1)
        }
    }

    private var colorRow: some View {
        HStack(spacing: 10) {
            ForEach(FillColor.palette, id: \.self) { t in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { model.colorToken = t }
                } label: {
                    Circle().fill(FillColor.color(for: t))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(.white, lineWidth: model.colorToken == t ? 3 : 0))
                        .overlay(Circle().stroke(FillColor.shadow.opacity(0.06), lineWidth: 1))
                }
                .accessibilityLabel(Copy.colorLabel(t))
            }
            Spacer(minLength: 0)
        }
    }

    private var startButton: some View {
        Button(model.buttonText) {
            if model.valid { start() }
            else if let p = model.problem { app.showToast(p) }
        }
        .font(FillFont.scaled(17, weight: .bold))
        .foregroundStyle(FillColor.color(for: model.colorToken))
        .frame(maxWidth: .infinity).frame(height: 60)
        .background(.white.opacity(model.valid ? 1 : 0.6), in: Capsule())
        .padding(.bottom, 8)
        .accessibilityLabel(model.buttonText)
    }

    // MARK: - Panels (bottom sheet + scrim)

    private var panelScrim: some View {
        FillColor.scrim.ignoresSafeArea()
            .onTapGesture { model.openPanel = nil }
            .accessibilityLabel(Copy.closePanel)
    }

    private func panel(_ i: Int) -> some View {
        VStack(spacing: 0) {
            Capsule().fill(FillColor.hairline).frame(width: 40, height: 5)
                .padding(.top, 10).accessibilityHidden(true)
            Text([Copy.whatYouWillDo, Copy.howOften, Copy.yourReward][i])
                .font(FillFont.panelTitle).foregroundStyle(FillColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 4)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if i == 0 { whatPanel }
                    if i == 1 { howOftenPanel }
                    if i == 2 { rewardPanel }
                }
                .padding(.horizontal, 20).padding(.top, 8)
            }
            .frame(maxHeight: 480)
            .scrollDismissesKeyboard(.interactively)
            Button(Copy.done) { model.done(i) }
                .font(FillFont.scaled(17, weight: .bold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(FillColor.color(for: model.colorToken), in: Capsule())
                .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 14)
                .accessibilityLabel(Copy.done)
        }
        .background(FillColor.surface, in: RoundedRectangle(cornerRadius: 30))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func labeled(_ label: String, _ view: some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(FillFont.mono(10)).tracking(0.8)
                .foregroundStyle(FillColor.text3)
            view
        }
    }

    // MARK: - What you'll do (metric chips + stepper + presets)

    private var whatPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                FlowLayout(spacing: 8) {
                    ForEach(Metric.allCases, id: \.self) { m in
                        let disabled = m == .rings && model.noWatch
                        Button {
                            model.metric = m; model.draft.metric = m
                            model.target = MetricDefaults.target(for: m)
                            model.draft.target = model.target
                            model.refreshFacts()
                        } label: {
                            Chip(text: MetricDefaults.label(for: m),
                                 selected: model.draft.metric == m,
                                 colorToken: model.colorToken)
                        }
                        .buttonStyle(.plain)
                        .opacity(disabled ? 0.4 : 1)
                        .accessibilityLabel(disabled
                            ? "\(MetricDefaults.label(for: m)), \(Copy.needsAppleWatch)"
                            : MetricDefaults.label(for: m))
                        .disabled(disabled)
                    }
                }
                if model.noWatch {
                    Text("\(MetricDefaults.label(for: .rings)) · \(Copy.needsAppleWatch)")
                        .font(FillFont.scaled(13, weight: .semibold))
                        .foregroundStyle(FillColor.text2)
                }
            }
            .onAppear { checkWatch() }
            if model.draft.metric == nil {
                // Nothing pre-selected: the stepper and presets appear once
                // the person taps a metric chip above.
                Text(Copy.pickWhat)
                    .font(FillFont.scaled(15, weight: .semibold))
                    .foregroundStyle(.white)
                    .accessibilityLabel(Copy.pickWhat)
            } else {
            labeled(Copy.targetLabel, FillStepper(
                value: MetricDefaults.stepperValue(target: model.target, metric: model.metric),
                unit: MetricDefaults.stepperUnit(metric: model.metric),
                colorToken: model.colorToken,
                onMinus: {
                    model.target = MetricDefaults.step(metric: model.metric, target: model.target, up: false)
                    model.draft.target = model.target; model.refreshFacts()
                },
                onPlus: {
                    model.target = MetricDefaults.step(metric: model.metric, target: model.target, up: true)
                    model.draft.target = model.target; model.refreshFacts()
                },
                onSet: { v in
                    model.target = model.metric == .rings ? min(3, max(1, v.rounded())) : max(1, v)
                    model.draft.target = model.target; model.refreshFacts()
                }))
            PresetChips(
                labels: MetricDefaults.presets(for: model.metric)
                    .map { MetricDefaults.presetLabel(metric: model.metric, value: $0) },
                selectedIndex: MetricDefaults.presets(for: model.metric)
                    .firstIndex(of: model.target),
                colorToken: model.colorToken) { i in
                model.target = MetricDefaults.presets(for: model.metric)[i]
                model.draft.target = model.target; model.refreshFacts()
            }
            }
        }
    }

    private func checkWatch() {
        Task { @MainActor in
            let manual = (try? context.fetch(FetchDescriptor<AppSettings>()).first?.manualMode) ?? false
            model.noWatch = manual ? false : !(await HealthKitController.shared.hasWatchData())
        }
    }

    // MARK: - How often (type tiles + steppers)

    private var howOftenPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                Tile(title: Copy.tileFlex, sub: Copy.tileFlexSub, selected: model.draft.type == .flex,
                     colorToken: model.colorToken) { pickType(.flex) }
                Tile(title: Copy.tileStreak, sub: Copy.tileStreakSub, selected: model.draft.type == .streak,
                     colorToken: model.colorToken) { pickType(.streak) }
                Tile(title: Copy.tileOnce, sub: Copy.tileOnceSub, selected: model.draft.type == .once,
                     colorToken: model.colorToken) { pickType(.once) }
                Tile(title: Copy.tileOpen, sub: Copy.tileOpenSub, selected: model.draft.type == .open,
                     colorToken: model.colorToken) { pickType(.open) }
            }
            if model.draft.type == .flex {
                HStack(spacing: 10) {
                    FillStepper(value: "\(model.draft.x ?? 20)", unit: Copy.winsUnit,
                                colorToken: model.colorToken,
                                onMinus: { model.draft.x = max(1, (model.draft.x ?? 20) - 1); model.refreshFacts() },
                                onPlus: { model.draft.x = min(365, (model.draft.x ?? 20) + 1); model.refreshFacts() },
                                onSet: { v in model.draft.x = min(365, max(1, Int(v.rounded()))); model.refreshFacts() })
                    FillStepper(value: "\(model.draft.y ?? 30)", unit: Copy.daysUnit,
                                colorToken: model.colorToken,
                                onMinus: { model.draft.y = max((model.draft.x ?? 20), (model.draft.y ?? 30) - 1); model.refreshFacts() },
                                onPlus: { model.draft.y = min(365, (model.draft.y ?? 30) + 1); model.refreshFacts() },
                                onSet: { v in model.draft.y = min(365, max(1, Int(v.rounded()))); model.refreshFacts() })
                }
            }
            if model.draft.type == .streak {
                FillStepper(value: "\(model.draft.x ?? 30)", unit: Copy.daysUnit,
                            colorToken: model.colorToken,
                            onMinus: { model.draft.x = max(1, (model.draft.x ?? 30) - 1); model.draft.y = model.draft.x; model.refreshFacts() },
                            onPlus: { model.draft.x = min(365, (model.draft.x ?? 30) + 1); model.draft.y = model.draft.x; model.refreshFacts() },
                            onSet: { v in model.draft.x = min(365, max(1, Int(v.rounded()))); model.draft.y = model.draft.x; model.refreshFacts() })
                PresetChips(labels: ["7", "14", "30"],
                            selectedIndex: [7, 14, 30].firstIndex(of: model.draft.x ?? 0),
                            colorToken: model.colorToken) { i in
                    model.draft.x = [7, 14, 30][i]; model.draft.y = model.draft.x
                    model.refreshFacts()
                }
            }
        }
    }

    private func pickType(_ t: ChallengeType) {
        model.pickType(t)
    }

    // MARK: - Your reward (kind chips + money/item panels)

    private var rewardPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach([
                    (Copy.rewardMoney, "banknote", RewardKind.money, RewardCategory.other),
                    (Copy.rewardTrip, "airplane", RewardKind.item, RewardCategory.trip),
                    (Copy.rewardFood, "fork.knife", RewardKind.item, RewardCategory.food),
                    (Copy.rewardBuy, "bag", RewardKind.item, RewardCategory.item),
                    (Copy.rewardOther, "star.fill", RewardKind.item, RewardCategory.other),
                ], id: \.0) { t in
                    kindChip(t.0, icon: t.1, kind: t.2, category: t.3)
                }
            }
            if model.draft.rewardKind == .money { moneyPanel }
            else if model.draft.rewardKind == .item { itemPanel }
            else {
                Text(Copy.pickReward)
                    .font(FillFont.scaled(14)).foregroundStyle(FillColor.text2)
            }
        }
    }

    private func kindChip(_ title: String, icon: String, kind: RewardKind, category: RewardCategory) -> some View {
        let selected = model.draft.rewardKind == kind &&
            (kind == .money || model.draft.itemCategory == category)
        return Button {
            model.draft.rewardKind = kind
            if kind == .item { model.draft.itemCategory = category }
            if kind == .money, model.draft.moneyPayout == nil
                || !model.allowedPayouts.contains(model.draft.moneyPayout ?? .each) {
                model.draft.moneyPayout = model.allowedPayouts.first
            }
            model.refreshFacts()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(FillFont.scaled(16, weight: .semibold))
                Text(title).font(FillFont.scaled(13, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? .white : FillColor.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selected ? FillColor.color(for: model.colorToken) : FillColor.chipBg,
                        in: Capsule())
        }
        .accessibilityLabel(title)
    }

    private var moneyPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            FlowLayout(spacing: 8) {
                ForEach(model.allowedPayouts, id: \.self) { p in
                    Button(payoutLabel(p)) {
                        model.draft.moneyPayout = p; model.refreshFacts()
                    }
                    .font(FillFont.scaled(14, weight: .semibold))
                    .foregroundStyle(model.draft.moneyPayout == p ? .white : FillColor.ink)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(model.draft.moneyPayout == p ? FillColor.color(for: model.colorToken) : FillColor.chipBg,
                                in: Capsule())
                    .accessibilityLabel(payoutLabel(p))
                }
            }
            labeled(Copy.amountLabel, FillStepper(
                value: Format.money(model.draft.amount ?? 0),
                unit: model.draft.moneyPayout == .end ? Copy.payoutEnd : Copy.payoutEach,
                colorToken: model.colorToken,
                onMinus: { model.draft.amount = max(0, (model.draft.amount ?? 0) - moneyStep()); model.refreshFacts() },
                onPlus: { model.draft.amount = (model.draft.amount ?? 0) + moneyStep(); model.refreshFacts() },
                onSet: { v in model.draft.amount = max(0, Decimal(v)); model.refreshFacts() }))
            PresetChips(labels: moneyPresets().map(shortMoney),
                        selectedIndex: moneyPresets().firstIndex(of: model.draft.amount ?? -1),
                        colorToken: model.colorToken) { i in
                model.draft.amount = moneyPresets()[i]; model.refreshFacts()
            }
            if model.draft.moneyPayout == .bonus {
                labeled(Copy.bonusLabel, FillStepper(
                    value: Format.money(model.draft.bonus ?? 0), unit: Copy.payoutEnd,
                    colorToken: model.colorToken,
                    onMinus: { model.draft.bonus = max(0, (model.draft.bonus ?? 0) - moneyStep()); model.refreshFacts() },
                    onPlus: { model.draft.bonus = (model.draft.bonus ?? 0) + moneyStep(); model.refreshFacts() },
                    onSet: { v in model.draft.bonus = max(0, Decimal(v)); model.refreshFacts() }))
            }
            if model.draft.moneyPayout == .jar {
                labeled(Copy.jarTargetLabel, FillStepper(
                    value: Format.money(model.draft.jarTarget ?? 0), unit: Copy.goalJar,
                    colorToken: model.colorToken,
                    onMinus: { model.draft.jarTarget = max(0, (model.draft.jarTarget ?? 0) - moneyStep()); model.refreshFacts() },
                    onPlus: { model.draft.jarTarget = (model.draft.jarTarget ?? 0) + moneyStep(); model.refreshFacts() },
                    onSet: { v in model.draft.jarTarget = max(0, Decimal(v)); model.refreshFacts() }))
            }
        }
    }
    private func payoutLabel(_ p: MoneyPayout) -> String {
        switch p {
        case .each: return Copy.payoutEach
        case .end: return model.draft.type == .once ? Copy.payoutOnce : Copy.payoutEnd
        case .bonus: return Copy.payoutBonus
        case .jar: return Copy.payoutJar
        }
    }
    private func moneyStep() -> Decimal {
        model.draft.moneyPayout == .end ? 5_000 : 500
    }
    private func moneyPresets() -> [Decimal] {
        // SPEC §7.6: per-win ₹500/₹1K/₹10K; end ₹25K/₹50K/₹1L.
        model.draft.moneyPayout == .end ? [25_000, 50_000, 100_000] : [500, 1_000, 10_000]
    }
    private func shortMoney(_ v: Decimal) -> String {
        let n = (v as NSDecimalNumber).intValue
        if n >= 100_000 { return "₹\(n / 100_000)L" }
        if n >= 1_000 { return "₹\(n / 1_000)K" }
        return "₹\(n)"
    }

    private var itemPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField(itemPlaceholder, text: Binding(
                get: { model.draft.itemName ?? "" },
                set: { model.setItemName($0) }))
                .font(FillFont.scaled(16, weight: .semibold))
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(FillColor.chipBg, in: RoundedRectangle(cornerRadius: 16))
                .autocorrectionDisabled()
                .accessibilityLabel(Copy.rewardNameLabel)
            labeled(Copy.itemWorth, FillStepper(
                value: Format.money(model.draft.itemValue ?? 0), unit: Copy.worth,
                colorToken: model.colorToken,
                onMinus: { model.draft.itemValue = max(0, (model.draft.itemValue ?? 0) - 1_000); model.refreshFacts() },
                onPlus: { model.draft.itemValue = (model.draft.itemValue ?? 0) + 1_000; model.refreshFacts() },
                onSet: { v in model.draft.itemValue = max(0, Decimal(v)); model.refreshFacts() }))
            labeled(Copy.howYouGetIt, howYouGetIt)
        }
    }
    private var itemPlaceholder: String {
        switch model.draft.itemCategory {
        case .trip: return Copy.itemTripPlaceholder
        case .food: return Copy.itemFoodPlaceholder
        case .item: return Copy.itemBuyPlaceholder
        default: return Copy.itemOtherPlaceholder
        }
    }
    @ViewBuilder private var howYouGetIt: some View {
        if (model.draft.itemValue ?? 0) <= 0 {
            Text(Copy.addPrice)
                .font(FillFont.scaled(14)).foregroundStyle(FillColor.text2)
        } else if model.draft.type == .once || model.draft.type == .open || model.draft.type == nil {
            itemSplitTile(.end)
        } else {
            HStack(spacing: 10) {
                itemSplitTile(.end)
                itemSplitTile(.save)
            }
        }
    }
    private func itemSplitTile(_ p: ItemPayout) -> some View {
        let v = model.draft.itemValue ?? 0
        let x = model.draft.x ?? 0
        let title: String = p == .end
            ? Copy.allAtTheEnd
            : Copy.itemSaveTitle(Format.money(Derive.itemPerWin(value: v, x: max(1, x))))
        let sub: String = {
            switch p {
            case .end: return Copy.itemEndSub(Format.money(v))
            case .save: return Copy.itemSaveSub(max(1, x), Format.money(Derive.itemPerWin(value: v, x: max(1, x))))
            }
        }()
        return Tile(title: title, sub: sub, selected: model.draft.itemPayout == p,
                    colorToken: model.colorToken) {
            model.draft.itemPayout = p; model.refreshFacts()
        }
        .accessibilityLabel("\(title) · \(sub)")
    }

    // MARK: - Start

    private func start() {
        let today = DayKey.from(date: Date(), calendar: .current)
        let d = model.draft
        let name = model.name.isEmpty ? model.autoName : model.name
        let c = Challenge(name: name,
                          colorToken: model.colorToken, metric: model.metric, target: model.target,
                          type: d.type ?? .flex, x: d.x ?? 20, y: d.y ?? 30,
                          start: today, reward: model.buildReward())
        Repository(context: context).insertChallenge(c)
        // C12: new page appears last, pager scrolls to it, Overview band added.
        app.selectNewChallenge = true
        let manual = (try? context.fetch(FetchDescriptor<AppSettings>()).first?.manualMode) ?? false
        app.showToast(manual ? Copy.challengeStartedManual : Copy.challengeStarted)
        dismiss()
    }
}

// Blank shake (DESIGN §6): x ±6/±4/±3 over 0.5s.
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        guard animatableData > 0 else { return ProjectionTransform() }
        let t = animatableData
        let travel: CGFloat = 6 * (1 - t)
        let x = sin(t * .pi * 3) * travel
        let t2 = CGAffineTransform(translationX: x, y: 0)
        return ProjectionTransform(t2)
    }
}

// Simple wrapping layout for the Create sentence and chip rows.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 340
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0, x + sz.width > w { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: w, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX, x + sz.width > bounds.maxX {
                x = bounds.minX; y += rowH + spacing; rowH = 0
            }
            s.place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                   proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}
