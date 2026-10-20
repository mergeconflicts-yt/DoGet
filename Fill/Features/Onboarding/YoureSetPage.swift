import SwiftUI
import SwiftData

// Screen 4 — You're set. The ring, disc and check draw in sequence, then the
// first-challenge card slides up and confetti bursts. Start creates the real
// challenge; Make my own opens a fresh Create with nothing pre-selected.

struct YoureSetPage: View {
    var onStart: () -> Void
    var onMakeOwn: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var ring: Double = 0
    @State private var disc = false
    @State private var check: Double = 0
    @State private var showText = false
    @State private var showCard = false
    @State private var confetti = false
    @State private var celebrated = false

    var body: some View {
        ZStack {
            FillColor.orange.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .trim(from: 0, to: max(0.001, ring))
                                .stroke(.white, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                                .frame(width: 156, height: 156)
                                .rotationEffect(.degrees(-90))
                            Circle()
                                .fill(.white)
                                .frame(width: 96, height: 96)
                                .scaleEffect(disc ? 1 : 0.01)
                            CheckShape()
                                .trim(from: 0, to: check)
                                .stroke(FillColor.orange,
                                        style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                                .frame(width: 46, height: 40)
                        }
                        .frame(width: 170, height: 170)
                        .padding(.top, 26)
                        .accessibilityHidden(true)

                        VStack(spacing: 6) {
                            Text(Copy.onbSetTitle)
                                .font(.system(size: 40, weight: .black))
                                .tracking(-1)
                                .foregroundStyle(.white)
                            Text(Copy.onbSetSub)
                                .font(FillFont.scaled(17))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 16)
                        .opacity(showText ? 1 : 0)
                        .offset(y: showText ? 0 : 10)

                        firstChallenge
                            .padding(.horizontal, 24)
                            .padding(.top, 22)
                            .opacity(showCard ? 1 : 0)
                            .offset(y: showCard ? 0 : 30)
                            .padding(.bottom, 12)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)

                if showCard {
                    VStack(spacing: 2) {
                        Button(action: onStart) {
                            Text(Copy.onbStartThis)
                                .font(FillFont.scaled(17, weight: .bold))
                                .foregroundStyle(FillColor.orange)
                                .frame(maxWidth: .infinity).frame(height: 58)
                                .background(.white, in: Capsule())
                        }
                        .accessibilityLabel(Copy.onbStartThis)

                        Button(Copy.onbMakeOwn, action: onMakeOwn)
                            .font(FillFont.scaled(15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(height: 44)
                            .accessibilityLabel(Copy.onbMakeOwn)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            if confetti, !reduceMotion {
                ConfettiView(colorToken: "orange").ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .task { await play() }
        .sensoryFeedback(.success, trigger: celebrated)
    }

    private var firstChallenge: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Copy.onbFirstChallenge)
                .font(FillFont.mono(9)).tracking(1.5)
                .foregroundStyle(FillColor.orange)
            WondayFlow(spacing: 5) {
                senWord("I'll")
                senWord("walk 10,000 steps a day", color: FillColor.orange, weight: .black)
                senWord("on")
                senWord("20 of 30 days", weight: .black)
                senWord("to")
                senWord("win")
                senWord(Format.money(10_000), color: FillColor.orange, weight: .black)
                senWord("for")
                senWord("each")
                HStack(spacing: 0) {
                    WondayWord(size: 16, color: FillColor.ink, ring: FillColor.orange, track: FillColor.orangeTint)
                    Text(".").font(FillFont.scaled(16)).foregroundStyle(FillColor.ink)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: FillColor.shadow.opacity(0.15), radius: 16, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Copy.onbFirstChallenge). \(Copy.onbFirstSentence)")
    }

    private func senWord(_ s: String, color: Color = FillColor.ink,
                         weight: Font.Weight = .regular) -> some View {
        Text(s).font(FillFont.scaled(16, weight: weight)).foregroundStyle(color)
    }

    private func play() async {
        if reduceMotion {
            ring = 1; disc = true; check = 1
            showText = true; showCard = true
            return
        }
        try? await Task.sleep(for: .seconds(0.15))
        withAnimation(.easeOut(duration: 0.65)) { ring = 1 }
        try? await Task.sleep(for: .seconds(0.55))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { disc = true }
        try? await Task.sleep(for: .seconds(0.22))
        withAnimation(.easeOut(duration: 0.3)) { check = 1 }
        try? await Task.sleep(for: .seconds(0.28))
        withAnimation(.easeOut(duration: 0.35)) { showText = true }
        try? await Task.sleep(for: .seconds(0.2))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { showCard = true }
        try? await Task.sleep(for: .seconds(0.2))
        confetti = true
        celebrated = true
    }
}

/// The check drawn on the white disc.
struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.54))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.40, y: rect.minY + rect.height * 0.78))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.86, y: rect.minY + rect.height * 0.26))
        return p
    }
}
