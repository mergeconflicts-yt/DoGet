import SwiftUI

// Screen 1 — Walk to unlock. A demo only: holding fills the screen, counts
// the steps and unlocks a reward card. It never reads Health, never saves a
// win or a challenge (onboarding.txt).

struct WalkToUnlockPage: View {
    var onBack: () -> Void
    var onNext: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let target = 10_000.0
    private let holdSeconds = 2.3

    @State private var fraction = 0.0
    @State private var unlocked = false
    @State private var holding = false
    @State private var holdTask: Task<Void, Never>?
    @State private var rewardFraction = 0.0
    @State private var showRows = false
    @State private var showNext = false
    @State private var shakeTrigger = 0.0
    @State private var confetti = false
    @State private var giftWiggle = false

    private var steps: Int { Int((fraction * target).rounded()) }
    private var fillColor: Color { FillColor.color(for: "orange") }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                FillColor.orangeTint.ignoresSafeArea()

                // The rising fill with a scalloped, drifting edge.
                if !unlocked {
                    TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || fraction <= 0)) { timeline in
                        let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate * 2
                        WaveShape(fraction: fraction, phase: phase, amplitude: 8, bumps: 22)
                            .fill(fillColor)
                            .ignoresSafeArea()
                    }
                } else {
                    fillColor.ignoresSafeArea()
                }

                if unlocked {
                    unlockedLayout
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                } else {
                    // Single header (no Skip button) + dual-layer body so
                    // covered rows turn white mid-glyph.
                    VStack(spacing: 0) {
                        OnboardingHeader(part: 1,
                                         color: fraction > 0.88 ? .white : FillColor.ink,
                                         showSkip: false,
                                         onBack: onBack, onSkip: {})
                            .padding(.top, 2)
                        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || fraction <= 0)) { timeline in
                            let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate * 2
                            ZStack {
                                holdBody(white: false)
                                holdBody(white: true)
                                    .mask {
                                        WaveShape(fraction: fraction, phase: phase, amplitude: 8, bumps: 22)
                                            .ignoresSafeArea()
                                    }
                                    .allowsHitTesting(false)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .modifier(ShakeEffect(animatableData: shakeTrigger))
            .overlay {
                if confetti, !reduceMotion {
                    ConfettiView(colorToken: "orange").ignoresSafeArea()
                }
            }
        }
        .sensoryFeedback(.success, trigger: unlocked)
        .onDisappear { holdTask?.cancel() }
    }

    // MARK: Before unlock — centered title, huge number, bottom button.

    private func holdBody(white: Bool) -> some View {
        let fg: Color = white ? .white : FillColor.ink
        let fgSoft: Color = white ? .white : FillColor.ink.opacity(0.8)
        let circleFill: Color = white ? .white : FillColor.ink
        let iconColor: Color = white ? fillColor : .white
        return VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(Copy.onbWalkTitle("10,000"))
                    .font(.system(size: 34, weight: .black))
                    .tracking(-0.8)
                    .foregroundStyle(fg)
                Text(Copy.onbWalkSub)
                    .font(FillFont.scaled(17))
                    .foregroundStyle(fgSoft)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(Copy.onbWalkTitle("10,000")). \(Copy.onbWalkSub)")

            Spacer(minLength: 0)

            VStack(spacing: 0) {
                Text(Format.int(steps))
                    .font(.system(size: 108, weight: .black, design: .default))
                    .tracking(-3)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .foregroundStyle(fg)
                Text(Copy.onbStepsUnit)
                    .font(FillFont.scaled(20, weight: .semibold))
                    .foregroundStyle(white ? .white : FillColor.ink.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(Format.int(steps)) \(Copy.onbStepsUnit)")

            Spacer(minLength: 0)

            if white {
                // Visual copy only — no button, no accessibility, so the
                // UI test and VoiceOver see a single Hold to walk.
                VStack(spacing: 10) {
                    ZStack {
                        Circle().fill(circleFill).frame(width: 82, height: 82)
                        Image(systemName: "footprints")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(iconColor)
                    }
                    Text(Copy.onbHoldToWalk)
                        .font(FillFont.scaled(17, weight: .bold))
                        .foregroundStyle(fg)
                }
                .padding(.vertical, 6)
                .padding(.bottom, 26)
                .accessibilityHidden(true)
            } else {
                Button {
                // Holding is handled by the long-press below; this action
                // exists so VoiceOver sees a real button.
            } label: {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(circleFill)
                            .frame(width: 82, height: 82)
                        Image(systemName: "footprints")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(iconColor)
                    }
                    .overlay {
                        if !holding, !reduceMotion, !white {
                            TimelineView(.animation) { timeline in
                                let t = timeline.date.timeIntervalSinceReferenceDate
                                    .truncatingRemainder(dividingBy: 1.8) / 1.8
                                Circle()
                                    .stroke(FillColor.ink.opacity(0.35 * (1 - t)), lineWidth: 2)
                                    .scaleEffect(1 + t * 0.55)
                                    .frame(width: 82, height: 82)
                            }
                        }
                    }
                    Text(Copy.onbHoldToWalk)
                        .font(FillFont.scaled(17, weight: .bold))
                        .foregroundStyle(fg)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .scaleEffect(holding ? 0.96 : 1)
                .animation(.easeOut(duration: 0.15), value: holding)
                .onLongPressGesture(minimumDuration: 0.05, maximumDistance: 80,
                                    pressing: { isPressing in
                                        if isPressing { startHold() } else { stopHold() }
                                    }, perform: {})
                .accessibilityLabel(Copy.onbHoldToWalk)
                .accessibilityHint(Copy.onbHoldHint)
                .accessibilityAction(named: Copy.onbCompleteWalk) { completeWalk() }
                .padding(.bottom, 26)
            }
        }
    }

    // MARK: After unlock

    private var unlockedLayout: some View {
        VStack(spacing: 0) {
            OnboardingHeader(part: 1, color: .white, showSkip: false,
                             onBack: {}, onSkip: {})
                .padding(.top, 2)
                .opacity(0)
                .allowsHitTesting(false)
                .frame(height: 46)

            Text(Copy.onbWalkTitle("10,000"))
                .font(.system(size: 30, weight: .black))
                .tracking(-0.8)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.top, 18)

            Spacer(minLength: 0)
            unlockedContent
            Spacer(minLength: 0)
        }
    }

    private var unlockedContent: some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(FillColor.orangeTint)
                        .frame(width: 46, height: 46)
                    Image(systemName: "gift.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(FillColor.orange)
                        .rotationEffect(.degrees(giftWiggle ? -10 : 10))
                        .onAppear {
                            guard !reduceMotion else { return }
                            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                                giftWiggle = true
                            }
                        }
                }
                Text(Copy.onbRewardUnlocked)
                    .font(FillFont.mono(10)).tracking(1.6)
                    .foregroundStyle(FillColor.orange)
                CountingMoney(fraction: rewardFraction, amount: 10_000)
                    .font(.system(size: 46, weight: .black))
                    .tracking(-1)
                    .foregroundStyle(FillColor.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: FillColor.shadow.opacity(0.16), radius: 18, y: 12)

            if showRows {
                VStack(spacing: 8) {
                    unlockRow(icon: "checkmark", text: Copy.onbScore)
                    unlockRow(icon: "indianrupeesign", text: Copy.onbPay)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if showNext {
                Button(Copy.onbNext, action: onNext)
                    .font(FillFont.scaled(17, weight: .bold))
                    .foregroundStyle(FillColor.orange)
                    .frame(maxWidth: .infinity).frame(height: 58)
                    .background(.white, in: Capsule())
                    .padding(.top, 8)
                    .accessibilityLabel(Copy.onbNext)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
        .accessibilityElement(children: .contain)
    }

    private func unlockRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(.white).frame(width: 24, height: 24)
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(FillColor.ink)
            }
            Text(text)
                .font(FillFont.scaled(15, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(FillColor.ink.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: Hold

    private func startHold() {
        guard !unlocked, holdTask == nil else { return }
        holding = true
        holdTask = Task { @MainActor in
            var last = Date()
            while !Task.isCancelled, !unlocked {
                try? await Task.sleep(for: .milliseconds(16))
                let now = Date()
                let dt = now.timeIntervalSince(last)
                last = now
                fraction = min(1, fraction + dt / holdSeconds)
                if fraction >= 1 {
                    completeWalk()
                    return
                }
            }
        }
    }

    private func stopHold() {
        holding = false
        holdTask?.cancel()
        holdTask = nil
    }

    private func completeWalk() {
        guard !unlocked else { return }
        holdTask?.cancel(); holdTask = nil
        holding = false
        fraction = 1
        withAnimation(.easeOut(duration: 0.3)) { unlocked = true }
        if !reduceMotion {
            shakeTrigger = 0
            withAnimation(.easeInOut(duration: 0.35)) { shakeTrigger = 1 }
            confetti = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
            rewardFraction = 1
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.35))
            withAnimation(.easeOut(duration: 0.35)) {
                showRows = true
                showNext = true
            }
        }
    }
}
