import SwiftUI

// Screen 0 — Welcome. One idea in three seconds: the idea fills a card, the
// reward is yours, and you pay for it. The demo card loops through six goals
// and recolours the whole screen each time (onboarding.txt).

struct WelcomePage: View {
    var onStart: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    fileprivate struct Example {
        var color: String
        var pill: String
        var icon: String
        var targetValue: Double
        var target: String
        var unit: String
        var targetText: String
        var reward: String
        var decimals: Int
    }

    private static let examples: [Example] = [
        .init(color: "orange", pill: "STEPS", icon: "shoeprints.fill",
              targetValue: 10_000, target: "10,000", unit: "steps",
              targetText: "of 10,000 steps", reward: "10,000 bucks", decimals: 0),
        .init(color: "pink", pill: "RINGS", icon: "circle.circle",
              targetValue: 3, target: "3", unit: "rings",
              targetText: "of 3 rings", reward: "A trip to Taiwan", decimals: 0),
        .init(color: "green", pill: "EXERCISE", icon: "bolt.fill",
              targetValue: 30, target: "30", unit: "minutes",
              targetText: "of 30 min", reward: "New headphones", decimals: 0),
        .init(color: "blue", pill: "RUN", icon: "figure.run",
              targetValue: 5, target: "5.0", unit: "km",
              targetText: "of 5 km", reward: "New running shoes", decimals: 1),
        .init(color: "teal", pill: "CALORIES", icon: "flame.fill",
              targetValue: 500, target: "500", unit: "kcal",
              targetText: "of 500 kcal", reward: "Pizza night", decimals: 0),
        .init(color: "violet", pill: "SLEEP", icon: "moon.fill",
              targetValue: 8, target: "8", unit: "hours",
              targetText: "of 8 hours", reward: "A spa day", decimals: 0),
    ]

    @State private var index = 0
    @State private var fill = 0.0
    @State private var stamp = false
    @State private var chip = false
    @State private var logo = 0.0

    private var example: Example { Self.examples[index] }
    private var color: Color { FillColor.color(for: example.color) }
    private var onColor: Color {
        // The reference keeps the copy near-black on orange; saturated
        // blues/violets need white to stay readable.
        example.color == "orange" ? FillColor.ink : .white
    }

    @State private var bob = false

    var body: some View {
        ZStack {
            color.ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: index)
            if !reduceMotion {
                FloatingOrbs().ignoresSafeArea()
            }
            VStack(spacing: 0) {
                WondayWordmark(size: 34, color: FillColor.ink, progress: logo,
                                 ring: (example.color == "orange" || example.color == "pink") ? .white : nil)
                    .padding(.top, 6)

                Spacer(minLength: 10)

                demo
                    .padding(.horizontal, 18)

                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Copy.onbHeadline1)
                            .font(FillFont.scaled(40, weight: .black, relativeTo: .largeTitle))
                            .tracking(-1.2)
                            .foregroundStyle(onColor)
                        Text(Copy.onbHeadline2)
                            .font(FillFont.scaled(40, weight: .black, relativeTo: .largeTitle))
                            .tracking(-1.2)
                            .foregroundStyle(onColor)
                        Text(Copy.onbHeadline3)
                            .font(FillFont.scaled(40, weight: .black, relativeTo: .largeTitle))
                            .tracking(-1.2)
                            .foregroundStyle(onColor)
                    }
                    .lineSpacing(-3)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(Copy.onbHeadline1) \(Copy.onbHeadline2) \(Copy.onbHeadline3)")
                    .accessibilityAddTraits(.isStaticText)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Copy.onbIntro)
                            .font(FillFont.scaled(15))
                            .foregroundStyle(onColor.opacity(0.9))
                        Text(Copy.onbScore)
                            .font(FillFont.scaled(15, weight: .bold))
                            .foregroundStyle(onColor)
                        Text(Copy.onbPay)
                            .font(FillFont.scaled(15, weight: .bold))
                            .foregroundStyle(onColor)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 14)

                Button(Copy.onbGetStarted, action: onStart)
                    .font(FillFont.scaled(17, weight: .bold))
                    .foregroundStyle(color)
                    .frame(maxWidth: .infinity).frame(height: 58)
                    .background(.white, in: Capsule())
                    .accessibilityLabel(Copy.onbGetStarted)

                HStack(spacing: 14) {
                    chip(Copy.onbNoSignup)
                    chip(Copy.onbNoAccount)
                    chip(Copy.onbNoServer)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .task { await runLoop() }
    }

    private var demo: some View {
        ZStack(alignment: .bottomTrailing) {
            DemoCard(fraction: fill, example: example, stamp: stamp)
                .rotationEffect(.degrees(-4))
                .offset(y: bob ? -7 : 7)
                .shadow(color: FillColor.shadow.opacity(0.18), radius: 22, y: 16)
            if chip {
                rewardChip
                    .offset(x: 6, y: 34)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 30)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                bob = true
            }
        }
    }

    private var rewardChip: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Copy.onbYourReward)
                .font(FillFont.mono(9)).tracking(1.2)
                .foregroundStyle(.white.opacity(0.65))
            Text(example.reward)
                .font(FillFont.scaled(17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(FillColor.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: FillColor.shadow.opacity(0.2), radius: 10, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Copy.onbYourReward). \(example.reward)")
    }

    private func chip(_ title: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark").font(.system(size: 9, weight: .black))
            Text(title).font(FillFont.scaled(12, weight: .semibold))
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }

    private func runLoop() async {
        if reduceMotion {
            logo = 0.75; fill = 1; stamp = true; chip = true
            return
        }
        try? await Task.sleep(for: .seconds(0.15))
        withAnimation(.easeOut(duration: 0.9)) { logo = 0.75 }
        while !Task.isCancelled {
            // Hold-to-walk pattern: step fill directly at 60fps so the
            // number counts 0 → target fast, locked to the rising color.
            // (withAnimation on fill would animate the wave but jump the
            // Text straight to the target.)
            await driveFill(duration: 2.0)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { stamp = true }
            try? await Task.sleep(for: .seconds(0.25))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { chip = true }
            try? await Task.sleep(for: .seconds(1.1))
            guard !Task.isCancelled else { return }
            // Reset first, then advance: the new example never flashes full.
            withTransaction(Transaction(animation: nil)) {
                fill = 0; stamp = false; chip = false
            }
            withAnimation(.easeInOut(duration: 0.5)) { index = (index + 1) % Self.examples.count }
            try? await Task.sleep(for: .seconds(0.45))
        }
    }

    /// Steps `fill` 0 → 1 without animation, like WalkToUnlock's hold
    /// loop. Each step redraws both the wave and the count text.
    private func driveFill(duration: Double) async {
        let frames = max(1, Int(duration * 60))
        for i in 1...frames {
            guard !Task.isCancelled else { return }
            fill = Double(i) / Double(frames)
            try? await Task.sleep(for: .milliseconds(16))
        }
        fill = 1
    }
}

/// The tilted demo card. `fraction` is stepped directly at 60fps (Hold to
/// walk pattern), so both the wave and the count text update every frame.
private struct DemoCard: View {
    var fraction: Double
    var example: WelcomePage.Example
    var stamp: Bool

    private var countText: String {
        if example.decimals > 0 {
            return Format.metric(fraction * example.targetValue, metric: .run)
        }
        return Format.int(Int((fraction * example.targetValue).rounded()))
    }
    private var fillColor: Color { FillColor.color(for: example.color) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.white)
            content(inverted: false)
            // Solid color first (WalkToUnlock pattern): without this the
            // masked white text below has no fill behind it — white-on-white
            // reads as "no fill + overlapping text".
            WaveShape(fraction: fraction, phase: fraction * 6, amplitude: 8, bumps: 16)
                .fill(fillColor)
            content(inverted: true)
                .mask {
                    WaveShape(fraction: fraction, phase: fraction * 6, amplitude: 8, bumps: 16)
                        .fill(.white)
                }
            if stamp {
                stampView
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: .top)
                    .padding(.top, 52)
                    .transition(.scale(scale: 1.5).combined(with: .opacity))
            }
        }
        .frame(height: 218)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(example.targetText). \(countText) \(example.unit). \(Copy.onbYourReward). \(example.reward)")
    }

    @ViewBuilder
    private func content(inverted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: example.icon)
                        .font(.system(size: 10, weight: .bold))
                    Text(example.pill)
                        .font(FillFont.mono(9)).tracking(0.8)
                }
                .foregroundStyle(inverted ? fillColor : .white)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(inverted ? AnyShapeStyle(.white) : AnyShapeStyle(fillColor),
                            in: Capsule())
                Spacer()
                Text("TODAY")
                    .font(FillFont.mono(9)).tracking(1.4)
                    .foregroundStyle(inverted ? .white : FillColor.text2)
            }
            Spacer(minLength: 8)
            Text(countText)
                .font(.system(size: 54, weight: .black))
                .tracking(-1.5)
                .lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(inverted ? .white : FillColor.ink)
            Text(example.targetText)
                .font(FillFont.scaled(15, weight: .medium))
                .foregroundStyle(inverted ? .white : FillColor.text2)
        }
        .padding(18)
    }

    private var stampView: some View {
        HStack(spacing: 4) {
            WondayWord(size: 22, color: FillColor.ink,
                       ring: (example.color == "orange" || example.color == "pink") ? .white : FillColor.orange)
            Text("✓").font(FillFont.scaled(20, weight: .black)).foregroundStyle(.white)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white, lineWidth: 3)
        }
        .rotationEffect(.degrees(-12))
    }
}

/// Large, soft circles drifting slowly; tiny white bits rising and fading.
private struct FloatingOrbs: View {
    @State private var drift = false
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle().fill(.white.opacity(0.07))
                    .frame(width: 300, height: 300)
                    .position(x: geo.size.width * 0.12, y: geo.size.height * 0.30)
                    .offset(y: drift ? -18 : 18)
                Circle().fill(.white.opacity(0.06))
                    .frame(width: 210, height: 210)
                    .position(x: geo.size.width * 0.95, y: geo.size.height * 0.18)
                    .offset(y: drift ? 22 : -14)
                Circle().fill(FillColor.ink.opacity(0.04))
                    .frame(width: 260, height: 260)
                    .position(x: geo.size.width * 0.78, y: geo.size.height * 0.92)
                    .offset(y: drift ? -24 : 12)
                TimelineView(.animation) { timeline in
                    Canvas { ctx, size in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        for i in 0..<11 {
                            let seed = Double(i) * 1.37
                            let speed = 10.0 + (Double(i % 3) * 4)
                            let span = size.height + 80
                            let y = size.height - (t * speed + seed * 90)
                                .truncatingRemainder(dividingBy: span)
                            let x = size.width * (0.08 + (Double((i * 37) % 90) / 100))
                            let r = 1.6 + Double(i % 3)
                            let p = Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r))
                            let fade = 0.55 * (1 - abs(y / size.height - 0.5) * 1.4)
                            ctx.fill(p, with: .color(.white.opacity(max(0, fade))))
                        }
                    }
                }
                .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                    drift = true
                }
            }
        }
        .accessibilityHidden(true)
    }
}
