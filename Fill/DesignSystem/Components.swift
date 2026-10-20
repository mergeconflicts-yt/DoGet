import SwiftUI

// DESIGN §5 — components. Reduce Motion respected by callers.

// Activity pill: C bg, white mono uppercase. Status variants red / C.
public struct ActivityPill: View {
    var metric: String
    var text: String
    var colorToken: String
    var status: Status = .normal
    public enum Status { case normal, danger, done }
    public var body: some View {
        let bg: Color = status == .danger ? FillColor.danger : FillColor.color(for: colorToken)
        HStack(spacing: 6) {
            Image(systemName: FillMetricIcon.symbol(for: metric)).font(FillFont.scaled(13, weight: .bold))
            Text(text).font(FillFont.mono(11)).tracking(1.2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(bg, in: Capsule())
        .accessibilityLabel("\(text)")
    }
}

// Bottom bar: left pill (Challenges) + round + button.
public struct BottomBar: View {
    var pageLabel: String
    var onAll: () -> Void
    var onAdd: () -> Void
    public var body: some View {
        HStack {
            Button(action: onAll) {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2")
                    Text(pageLabel).font(FillFont.scaled(14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(FillColor.ink, in: Capsule())
            }
            .accessibilityLabel(Copy.overviewAllChallenges)
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus").font(FillFont.scaled(24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(FillColor.ink, in: Circle())
            }
            .accessibilityLabel(Copy.newChallengeLabel)
        }
        .padding(.horizontal, 20).padding(.bottom, 26)
    }
}

// Day bars: won solid / manual striped / missed stub / today partial / future dot.
public struct DayBars: View {
    var total: Int
    var wins: Set<Int> // 0-based indices won
    var manualWins: Set<Int> = []
    var misses: Set<Int> = []
    var todayIndex: Int?
    var todayRatio: Double = 0
    var colorToken: String
    public var body: some View {
        HStack(spacing: total > 40 ? 1 : 3) {
            ForEach(0..<total, id: \.self) { i in
                bar(i)
            }
        }
        .frame(height: 40)
        .accessibilityHidden(true)
    }
    @ViewBuilder private func bar(_ i: Int) -> some View {
        let c = FillColor.color(for: colorToken)
        if wins.contains(i) {
            if manualWins.contains(i) {
                ManualBar(color: c)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                RoundedRectangle(cornerRadius: 3).fill(c)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if misses.contains(i) {
            VStack { Spacer(); RoundedRectangle(cornerRadius: 3).fill(FillColor.danger.opacity(0.75)).frame(maxWidth: .infinity, maxHeight: 10) }
        } else if todayIndex == i {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3).fill(c.opacity(0.45)).frame(maxWidth: .infinity, maxHeight: .infinity)
                RoundedRectangle(cornerRadius: 3).fill(c.opacity(0.45))
                    .frame(maxWidth: .infinity, maxHeight: max(4, 40 * todayRatio))
                Rectangle().fill(c).frame(maxWidth: .infinity, maxHeight: 2).padding(.top, 2)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        } else {
            VStack { Spacer(); RoundedRectangle(cornerRadius: 3).fill(FillColor.hairline).frame(maxWidth: .infinity, maxHeight: 6) }
        }
    }
}

// Manual wins are striped (SPEC §9), not a flat tint.
struct ManualBar: View {
    var color: Color
    var body: some View {
        Canvas { ctx, size in
            let rect = CGRect(origin: .zero, size: size)
            let shape = Path(roundedRect: rect, cornerRadius: 3)
            ctx.clip(to: shape)
            ctx.fill(Path(rect), with: .color(color))
            var stripe = Path()
            let period: CGFloat = 6
            var x = -size.height
            while x < size.width {
                stripe.move(to: CGPoint(x: x, y: 0))
                stripe.addLine(to: CGPoint(x: x + size.height, y: size.height))
                x += period
            }
            ctx.stroke(stripe, with: .color(.white.opacity(0.55)), lineWidth: 2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// Toast: ink, radius 16, slides up, 2.6s (caller handles timing).
public struct Toast: View {
    var text: String
    public var body: some View {
        Text(text).font(FillFont.scaled(14, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(FillColor.ink, in: RoundedRectangle(cornerRadius: 16))
            .padding(.bottom, 100)
            .accessibilityLabel(text)
            .allowsHitTesting(false)
    }
}

// Stepper per DESIGN §5: bg radius 20, 48pt white square buttons, value 30
// heavy in C with the unit label under it, tap to type (SPEC §7.6).
public struct FillStepper: View {
    var value: String
    var unit: String = ""
    var colorToken: String
    var minText: String? = nil // typed entry replaces the value
    var onMinus: () -> Void
    var onPlus: () -> Void
    var onSet: ((Double) -> Void)? = nil // tap to type
    @State private var typing = false
    @State private var typed = ""
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        HStack(spacing: 10) {
            Button(action: { typed = ""; endTyping(); onMinus() }) {
                Image(systemName: "minus").font(FillFont.scaled(20, weight: .bold))
                    .frame(width: 48, height: 48).background(.white, in: RoundedRectangle(cornerRadius: 12))
            }.accessibilityLabel(Copy.decrease)
            valueField()
                .frame(maxWidth: .infinity)
            Button(action: { typed = ""; endTyping(); onPlus() }) {
                Image(systemName: "plus").font(FillFont.scaled(20, weight: .bold))
                    .frame(width: 48, height: 48).background(.white, in: RoundedRectangle(cornerRadius: 12))
            }.accessibilityLabel(Copy.increase)
        }
        .padding(10)
        .background(FillColor.chipBg, in: RoundedRectangle(cornerRadius: 20))
        .foregroundStyle(FillColor.ink)
    }

    @ViewBuilder private func valueField() -> some View {
        if typing, onSet != nil {
            TextField(value, text: $typed)
                .keyboardType(.decimalPad)
                .focused($focused)
                .font(FillFont.scaled(30, weight: .heavy))
                .foregroundStyle(FillColor.color(for: colorToken))
                .multilineTextAlignment(.center)
                .monospacedDigit()
                .onSubmit { commitTyped() }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { commitTyped() }
                    }
                }
                .accessibilityLabel("Type a value")
        } else {
            Button {
                guard onSet != nil else { return }
                typed = ""; typing = true
                focused = true
            } label: {
                VStack(spacing: 0) {
                    Text(value).font(FillFont.scaled(30, weight: .heavy))
                        .foregroundStyle(FillColor.color(for: colorToken))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6).lineLimit(1)
                    if !unit.isEmpty {
                        Text(unit).font(FillFont.scaled(13, weight: .semibold))
                            .foregroundStyle(FillColor.text2)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            }
            .accessibilityLabel("\(value) \(unit)")
            .accessibilityHint("Double tap to type a value")
        }
    }
    private func commitTyped() {
        if let v = Double(typed.replacingOccurrences(of: ",", with: ".")), onSet != nil {
            onSet?(v)
        }
        endTyping()
    }
    private func endTyping() {
        typing = false
        focused = false
    }
}

// Selection tile (How often tiles, reward split buttons): title + sub,
// selected = challenge color with white text (mockups IMG_5623, 5626–5627).
public struct Tile: View {
    var title: String
    var sub: String
    var selected: Bool
    var colorToken: String
    var action: () -> Void
    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(FillFont.scaled(16, weight: .bold))
                Text(sub).font(FillFont.scaled(13, weight: .medium))
                    .foregroundStyle(selected ? .white.opacity(0.85) : FillColor.text2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(selected ? FillColor.color(for: colorToken) : FillColor.chipBg,
                        in: RoundedRectangle(cornerRadius: 18))
            .foregroundStyle(selected ? .white : FillColor.ink)
        }
        .accessibilityLabel("\(title), \(sub)")
    }
}

// Preset chips row (mockups IMG_5621/5622/5624): selected = C bg, white text.
public struct PresetChips: View {
    var labels: [String]
    var selectedIndex: Int?
    var colorToken: String
    var action: (Int) -> Void
    public var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(labels.enumerated()), id: \.offset) { i, l in
                Button(l) { action(i) }
                    .font(FillFont.scaled(14, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .foregroundStyle(selectedIndex == i ? .white : FillColor.ink)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(selectedIndex == i ? FillColor.color(for: colorToken) : FillColor.chipBg,
                                in: Capsule())
                    .accessibilityLabel(l)
            }
            Spacer(minLength: 0)
        }
    }
}

public struct Chip: View {
    var text: String
    var selected: Bool
    var colorToken: String
    public var body: some View {
        Text(text).font(FillFont.scaled(14, weight: .semibold))
            .lineLimit(1).minimumScaleFactor(0.7)
            .foregroundStyle(selected ? .white : FillColor.ink)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(selected ? FillColor.color(for: colorToken) : FillColor.chipBg, in: Capsule())
    }
}
