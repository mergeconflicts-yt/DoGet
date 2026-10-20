import SwiftUI
import SwiftData

// Screen 2 — Apple Health. White screen, read-only list, silent denial
// (never show an error). Connect asks iOS once; manual mode is one tap.

struct HealthConnectPage: View {
    var onBack: () -> Void
    var onNext: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var connected = false
    @State private var connecting = false
    @State private var beat = false

    private struct Row {
        var title: String
        var icon: String
        var token: String
        var badge: String? = nil
    }

    private let rows: [Row] = [
        .init(title: Copy.healthSteps, icon: "shoeprints.fill", token: "orange",
              badge: Copy.onbYourGoal),
        .init(title: Copy.healthRings, icon: "circle.circle", token: "pink"),
        .init(title: Copy.healthExercise, icon: "bolt.fill", token: "green"),
        .init(title: Copy.healthWorkouts, icon: "figure.run", token: "blue"),
        .init(title: Copy.onbActiveCalories, icon: "flame.fill", token: "teal"),
        .init(title: Copy.healthSleep, icon: "moon.fill", token: "violet"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(part: 2, color: FillColor.ink, showSkip: false,
                             onBack: onBack, onSkip: {})
                .padding(.top, 2)

            ScrollView {
                VStack(spacing: 16) {
                    healthIcon
                        .padding(.top, 4)

                    VStack(spacing: 8) {
                        Text(Copy.onbHealthTitle)
                            .font(.system(size: 33, weight: .black))
                            .tracking(-0.8)
                            .foregroundStyle(FillColor.ink)
                            .multilineTextAlignment(.center)
                        healthSub
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                            rowView(row)
                            if i < rows.count - 1 {
                                Divider().overlay(FillColor.hairline)
                                    .padding(.leading, 56)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(FillColor.healthCardBg,
                                in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                    HStack(spacing: 5) {
                        Image(systemName: "lock.fill").font(.system(size: 10))
                        Text(Copy.onbHealthNote)
                            .font(FillFont.scaled(12))
                    }
                    .foregroundStyle(FillColor.text3)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 4) {
                Button(action: connect) {
                    HStack(spacing: 8) {
                        if connecting {
                            ProgressView().tint(.white)
                        }
                        Text(connected ? Copy.onbConnected : Copy.onbHealthTitle)
                    }
                    .font(FillFont.scaled(17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 58)
                    .background(connected ? FillColor.success : FillColor.ink, in: Capsule())
                }
                .disabled(connecting || connected)
                .accessibilityLabel(connected ? Copy.onbConnected : Copy.onbHealthTitle)

                Button(Copy.logByHand, action: manual)
                    .font(FillFont.scaled(15, weight: .semibold))
                    .foregroundStyle(FillColor.ink)
                    .frame(height: 44)
                    .accessibilityLabel(Copy.logByHand)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
        }
        .background(.white)
    }

    private var healthSub: some View {
        // Branded wonday via WondayWord; container carries the full plain
        // sentence for VoiceOver and UI tests.
        VStack(spacing: 2) {
            WondayFlow(spacing: 4, alignment: .center) {
                WondayWord(size: 15, color: FillColor.ink.opacity(0.78), ring: FillColor.orange, track: FillColor.orangeTint)
                subWord("reads")
                subWord("your")
                subWord("activity")
                subWord("to")
                subWord("check")
                subWord("your")
                subWord("goal.")
            }
            WondayFlow(spacing: 4, alignment: .center) {
                subWord("It")
                subWord("never")
                subWord("writes,")
                subWord("uploads")
                subWord("or")
                subWord("shares")
                subWord("your")
                subWord("data.")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Copy.onbHealthSub)
    }

    private func subWord(_ s: String) -> some View {
        Text(s)
            .font(FillFont.scaled(15))
            .foregroundStyle(FillColor.ink.opacity(0.78))
    }

    private var healthIcon: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(LinearGradient(colors: [FillColor.healthRed, FillColor.healthRedLight],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 84, height: 84)
            .overlay {
                Image(systemName: "heart.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
                    .scaleEffect(beat ? 1.06 : 1)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    beat = true
                }
            }
            .accessibilityLabel("Apple Health")
    }

    private func rowView(_ row: Row) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(FillColor.color(for: row.token))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: row.icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
            Text(row.title)
                .font(FillFont.scaled(16, weight: .semibold))
                .foregroundStyle(FillColor.ink)
            if let badge = row.badge {
                Text(badge)
                    .font(FillFont.mono(8)).tracking(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(FillColor.orange, in: Capsule())
            }
            Spacer(minLength: 8)
            Toggle("", isOn: .constant(true))
                .labelsHidden()
                .tint(FillColor.success)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 9)
    }

    private func connect() {
        guard !connecting, !connected else { return }
        connecting = true
        Task { @MainActor in
            // H01/H02: the system prompt. iOS never tells us a refusal, so
            // there is no error state — the app simply works with what it has.
            _ = await HealthKitController.shared.authorize()
            let repo = Repository(context: context)
            repo.settings().manualMode = false
            try? context.save()
            connecting = false
            connected = true
            try? await Task.sleep(for: .seconds(0.9))
            onNext()
        }
    }

    private func manual() {
        let repo = Repository(context: context)
        repo.settings().manualMode = true
        try? context.save()
        app.showToast(Copy.onbManualToast)
        onNext()
    }
}
