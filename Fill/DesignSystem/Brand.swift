import SwiftUI

// Wonday brand — the wordmark, the ring "o", the app tile and the wave used
// by the welcome/onboarding demo. One source for every in-app use.

/// The wordmark: lowercase "wonday" where the "o" is a ¾ ring with a pale
/// quarter, exactly like `brand/wonday-wordmark-transparent.png`.
/// Brand rule: letters are black (ink), the O is brand orange. Two
/// exceptions: on an orange background the O alone turns white; on a
/// black background the letters turn white and the O stays orange.
/// Pass `color`/`ring` explicitly for those two backgrounds.
public struct WondayWordmark: View {
    var size: CGFloat
    var color: Color
    /// 0…0.75. Screen 0 animates this from 0 to 0.75 on first appearance.
    var progress: Double
    var ring: Color?
    var track: Color?

    public init(size: CGFloat = 34, color: Color = FillColor.ink, progress: Double = 0.75, ring: Color? = nil, track: Color? = nil) {
        self.size = size
        self.color = color
        self.progress = progress
        self.ring = ring
        self.track = track
    }

    public var body: some View {
        HStack(alignment: .center, spacing: size * -0.012) {
            letter("w")
            WondayRing(diameter: size * 0.60, lineWidth: size * 0.122,
                       color: ring ?? FillColor.orange, progress: progress, track: track)
                .offset(x: size * -0.015, y: size * 0.012)
            letter("nday")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Wonday")
    }

    private func letter(_ s: String) -> some View {
        Text(s)
            .font(.system(size: size, weight: .black))
            .tracking(size * -0.030)
            .foregroundStyle(color)
    }
}

/// The brand ring: ¾ solid arc with the gap centred near the top, plus a
/// pale quarter filling the gap — like `wonday-wordmark-transparent.png`.
/// (Earlier this drew a full faint track circle; the brand has none.)
/// Progress is 0…1 of a full circle; the wordmark uses 0.75.
public struct WondayRing: View {
    var diameter: CGFloat
    var lineWidth: CGFloat
    var color: Color
    var progress: Double
    var trackOpacity: Double = 0.16
    /// Solid pale track instead of a translucent one (brand track is solid
    /// pale peach, e.g. FillColor.orangeTint for the orange ring).
    var track: Color?

    public init(diameter: CGFloat, lineWidth: CGFloat, color: Color,
                progress: Double, trackOpacity: Double = 0.16, track: Color? = nil) {
        self.diameter = diameter
        self.lineWidth = lineWidth
        self.color = color
        self.progress = progress
        self.trackOpacity = trackOpacity
        self.track = track
    }

    public var body: some View {
        ZStack {
            // Pale quarter exactly where the solid arc stops: trim 0.75→1.0
            // with the same -100° rotation lands just left of top (the
            // brand gap sits slightly west of north). No wrap past 1.0,
            // so no clamping surprises.
            Circle()
                .trim(from: 0.75, to: 1.0)
                .stroke(track ?? color.opacity(trackOpacity), lineWidth: lineWidth)
                .rotationEffect(.degrees(-100))
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 0.75)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                .rotationEffect(.degrees(-100))
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

/// The app tile (Home Screen icon motif) used in notification previews.
/// Light tile with the orange W, matching the notification mock.
public struct WondayTile: View {
    var size: CGFloat
    public init(size: CGFloat = 28) { self.size = size }
    public var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(FillColor.wondayTileBg)
            .frame(width: size, height: size)
            .overlay {
                Text("W")
                    .font(.system(size: size * 0.72, weight: .black))
                    .foregroundStyle(FillColor.orange)
                    .offset(y: -size * 0.02)
            }
            .accessibilityHidden(true)
    }
}

/// Fill rising from the bottom with a soft, moving wave on its top edge.
/// The edge is scalloped (a row of small bumps, like the prototype) and the
/// wave keeps drifting while holding.
public struct WaveShape: Shape {
    public var fraction: Double
    public var phase: Double
    public var amplitude: CGFloat
    public var bumps: Double = 14
    /// Wave dies out as the fill reaches the top, so "full" is a clean block.
    public var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(fraction, phase) }
        set { fraction = newValue.first; phase = newValue.second }
    }

    public init(fraction: Double, phase: Double = 0, amplitude: CGFloat = 12, bumps: Double = 14) {
        self.fraction = fraction
        self.phase = phase
        self.amplitude = amplitude
        self.bumps = bumps
    }

    public func path(in rect: CGRect) -> Path {
        var p = Path()
        let f = max(0, min(fraction, 1))
        guard f > 0 else { return p }
        let amp = amplitude * (1 - f) * (f > 0.02 ? 1 : f / 0.02)
        let top = rect.height * (1 - f)
        p.move(to: CGPoint(x: 0, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: top))
        let steps = 120
        for i in 0...steps {
            let x = rect.width * CGFloat(i) / CGFloat(steps)
            let t = Double(i) / Double(steps)
            let y = top + sin(t * .pi * bumps + phase) * amp
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.closeSubpath()
        return p
    }
}

/// Header for screens 1–3: back, a 3-part progress bar. No Skip in v1.
public struct OnboardingHeader: View {
    var part: Int
    var color: Color
    var showSkip: Bool
    var onBack: () -> Void
    var onSkip: () -> Void

    public init(part: Int, color: Color, showSkip: Bool,
                onBack: @escaping () -> Void, onSkip: @escaping () -> Void) {
        self.part = part
        self.color = color
        self.showSkip = showSkip
        self.onBack = onBack
        self.onSkip = onSkip
    }

    public var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Copy.onbBack)

            Spacer(minLength: 0)
            HStack(spacing: 5) {
                ForEach(1...3, id: \.self) { i in
                    Capsule()
                        .fill(color.opacity(0.22))
                        .frame(width: 28, height: 3)
                        .overlay(alignment: .leading) {
                            Capsule().fill(color)
                                .scaleEffect(x: part >= i ? 1 : 0, anchor: .leading)
                        }
                        .animation(.easeOut(duration: 0.35), value: part)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Copy.onbProgress(part))
            Spacer(minLength: 0)

            if showSkip {
                Button(Copy.onbSkip, action: onSkip)
                    .font(FillFont.scaled(15, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel(Copy.onbSkip)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 12)
    }
}

/// Counts a money amount up as its fraction animates (welcome card, unlock).
/// Plain view: the parent @State drives `fraction` with withAnimation, so
/// intermediate values flow through without Animatable conformance.
public struct CountingMoney: View {
    var fraction: Double
    var amount: Decimal
    var currency: String

    public init(fraction: Double, amount: Decimal, currency: String = "INR") {
        self.fraction = fraction
        self.amount = amount
        self.currency = currency
    }

    public var body: some View {
        Text(Format.money(amount * Decimal(fraction), currency: currency))
    }
}

/// Branded "wonday" for use inside sentences and headlines: w + ¾ ring
/// + nday, matching the website wordmark. Brand rule: black letters,
/// orange O; on orange backgrounds the O alone turns white; on black
/// backgrounds the letters turn white and the O stays orange.
/// One accessibility element.
public struct WondayWord: View {
    var size: CGFloat
    var color: Color
    var weight: Font.Weight = .black
    var ring: Color?
    var track: Color?
    public init(size: CGFloat, color: Color, weight: Font.Weight = .black, ring: Color? = nil, track: Color? = nil) {
        self.size = size; self.color = color; self.weight = weight; self.ring = ring; self.track = track
    }
    public var body: some View {
        HStack(spacing: 0) {
            Text("w").font(FillFont.scaled(size, weight: weight)).foregroundStyle(color)
            WondayRing(diameter: size * 0.60, lineWidth: max(1.5, size * 0.122),
                       color: ring ?? FillColor.orange, progress: 0.75, track: track)
                .offset(x: size * -0.015, y: size * 0.02)
            Text("nday").font(FillFont.scaled(size, weight: weight)).foregroundStyle(color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("wonday")
    }
}

/// Toast with a branded wonday: same ink pill as `Toast`, used for
/// "Challenge started. Go make it a wonday!". Container carries the full
/// plain string for VoiceOver.
public struct WondayToast: View {
    public init() {}
    public var body: some View {
        WondayFlow(spacing: 4, alignment: .center) {
            toastWord("Challenge")
            toastWord("started.")
            toastWord("Go")
            toastWord("make")
            toastWord("it")
            toastWord("a")
            HStack(spacing: 0) {
                WondayWord(size: 14, color: .white)
                Text("!").font(FillFont.scaled(14, weight: .semibold)).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(FillColor.ink, in: RoundedRectangle(cornerRadius: 16))
        .padding(.bottom, 100)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Copy.onbStartedToast)
    }
    private func toastWord(_ s: String) -> some View {
        Text(s).font(FillFont.scaled(14, weight: .semibold)).foregroundStyle(.white)
    }
}
/// Wrapping row for sentences that mix regular text with the branded word.
/// Word spacing matches body text; punctuation stays glued to the word
/// before it via `HStack(spacing: 0)` subviews.
public struct WondayFlow: Layout {
    var spacing: CGFloat = 4
    var alignment: Alignment = .leading
    public init(spacing: CGFloat = 4, alignment: Alignment = .leading) {
        self.spacing = spacing; self.alignment = alignment
    }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
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
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let w = bounds.width
        // Split into rows first so centred rows can be offset.
        var rows: [[(index: Int, size: CGSize)]] = [[]]
        var x: CGFloat = 0, rowH: CGFloat = 0
        for (i, s) in subviews.enumerated() {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0, x + sz.width > w {
                rows.append([])
                x = 0; rowH = 0
            }
            rows[rows.count - 1].append((i, sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        var y = bounds.minY
        for row in rows {
            let contentW = row.reduce(CGFloat(0)) { $0 + $1.size.width } + spacing * CGFloat(max(0, row.count - 1))
            var rx = alignment == .center ? bounds.minX + (w - contentW) / 2 : bounds.minX
            var rh: CGFloat = 0
            for (i, sz) in row {
                subviews[i].place(at: CGPoint(x: rx, y: y), proposal: .unspecified)
                rx += sz.width + spacing
                rh = max(rh, sz.height)
            }
            y += rh + spacing
        }
    }
}
