import SwiftUI
import SwiftData
import UIKit

// Screen 2 — Apple Health. White screen, no permission list.
// Explains why Health is needed + privacy (read-only, stays on device,
// no server). Connect asks iOS once; manual mode is one tap.
// Silent denial (never show an error).

struct HealthConnectPage: View {
    var onBack: () -> Void
    var onNext: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var connected = false
    @State private var connecting = false
    @State private var beat = false
    @State private var showHowTo = false

    private struct Why {
        var title: String
        var sub: String
        var icon: String
    }

    private let whys: [Why] = [
        .init(title: Copy.onbHealthWhy1Title, sub: Copy.onbHealthWhy1Sub,
              icon: "checkmark.circle.fill"),
        .init(title: Copy.onbHealthWhy2Title, sub: Copy.onbHealthWhy2Sub,
              icon: "eye.slash.fill"),
        .init(title: Copy.onbHealthWhy3Title, sub: Copy.onbHealthWhy3Sub,
              icon: "iphone"),
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
                        ForEach(Array(whys.enumerated()), id: \.offset) { i, w in
                            whyView(w)
                            if i < whys.count - 1 {
                                Divider().overlay(FillColor.hairline)
                                    .padding(.leading, 52)
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
                        Text(connected ? Copy.onbConnected : Copy.onbHealthAllow)
                    }
                    .font(FillFont.scaled(17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 58)
                    .background(connected ? FillColor.success : FillColor.ink, in: Capsule())
                }
                .disabled(connecting || connected)
                .accessibilityLabel(connected ? Copy.onbConnected : Copy.onbHealthAllow)

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
        .sheet(isPresented: $showHowTo) { howToSheet }
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

    private func whyView(_ w: Why) -> some View {
        HStack(spacing: 12) {
            Image(systemName: w.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FillColor.success)
                .frame(width: 28, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(w.title)
                    .font(FillFont.scaled(16, weight: .semibold))
                    .foregroundStyle(FillColor.ink)
                Text(w.sub)
                    .font(FillFont.scaled(13))
                    .foregroundStyle(FillColor.text2)
            }
            Spacer(minLength: 8)
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(w.title). \(w.sub)")
    }

    private func connect() {
        guard !connecting, !connected else { return }
        connecting = true
        Task { @MainActor in
            // Always request first — iOS shows the sheet once per install.
            // First denial stays silent; a re-tap after denial shows how-to.
            let wasAsked = HealthKitController.shared.hasBeenAsked
            // H01/H02: silent denial — never show Connected unless granted.
            let granted = await HealthKitController.shared.authorize()
            connecting = false
            if granted {
                let repo = Repository(context: context)
                repo.settings().manualMode = false
                try? context.save()
                connected = true
                try? await Task.sleep(for: .seconds(0.9))
                onNext()
            } else if wasAsked {
                showHowTo = true
            }
        }
    }

    private var howToSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule().fill(FillColor.hairline).frame(width: 40, height: 5)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)
                .accessibilityHidden(true)
            Text(Copy.onbHealthHowTitle)
                .font(FillFont.scaled(22, weight: .heavy))
                .foregroundStyle(FillColor.ink)
            Text(Copy.onbHealthHowBody)
                .font(FillFont.scaled(15))
                .foregroundStyle(FillColor.text2)
                .accessibilityLabel("\(Copy.onbHealthHowTitle). \(Copy.onbHealthHowBody)")
            Button(Copy.onbHealthOpenSettings) {
                Task { @MainActor in
                    if let healthURL = URL(string: "x-apple-health://"),
                       await UIApplication.shared.open(healthURL) {
                    } else if let url = URL(string: UIApplication.openSettingsURLString) {
                        await UIApplication.shared.open(url)
                    }
                }
            }
            .font(FillFont.scaled(17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(FillColor.ink, in: Capsule())
            .accessibilityLabel(Copy.onbHealthOpenSettings)
            Button(Copy.onbHealthClose) { showHowTo = false }
                .font(FillFont.scaled(15, weight: .semibold))
                .foregroundStyle(FillColor.ink)
                .frame(maxWidth: .infinity).frame(height: 44)
                .accessibilityLabel(Copy.onbHealthClose)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .presentationDetents([.medium])
    }

    private func manual() {
        let repo = Repository(context: context)
        repo.settings().manualMode = true
        try? context.save()
        app.showToast(Copy.onbManualToast)
        onNext()
    }
}
