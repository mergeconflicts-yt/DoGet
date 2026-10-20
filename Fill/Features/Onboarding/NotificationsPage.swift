import SwiftUI
import SwiftData
import UserNotifications

// Screen 3 — Notifications. A lock-screen preview; two samples drop in,
// clear and repeat. Allow asks iOS once, then advances. Not now advances and
// leaves the prompt for after the first real win (onboarding.txt).

struct NotificationsPage: View {
    var onBack: () -> Void
    var onNext: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var allowState: AllowState = .idle
    @State private var showFirst = false
    @State private var showSecond = false

    private enum AllowState: Equatable { case idle, asking, allowed }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(part: 3, color: .white, showSkip: false,
                             onBack: onBack, onSkip: {})
                .padding(.top, 2)

            lockPreview
                .padding(.horizontal, 24)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 8) {
                Text("\(Copy.onbNotifTitle1)\n\(Copy.onbNotifTitle2)")
                    .font(.system(size: 38, weight: .black))
                    .tracking(-1)
                    .lineSpacing(-2)
                    .foregroundStyle(.white)
                    .accessibilityLabel("\(Copy.onbNotifTitle1) \(Copy.onbNotifTitle2)")
                Text(Copy.onbNotifSub)
                    .font(FillFont.scaled(15))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 18)

            Spacer(minLength: 12)

            VStack(spacing: 2) {
                Button(action: allow) {
                    HStack(spacing: 8) {
                        if allowState == .asking { ProgressView().tint(FillColor.orange) }
                        Text(allowState == .allowed ? Copy.onbAllowed : Copy.onbAllow)
                    }
                    .font(FillFont.scaled(17, weight: .bold))
                    .foregroundStyle(allowState == .allowed ? FillColor.success : FillColor.orange)
                    .frame(maxWidth: .infinity).frame(height: 58)
                    .background(.white, in: Capsule())
                }
                .disabled(allowState != .idle)
                .accessibilityLabel(allowState == .allowed ? Copy.onbAllowed : Copy.onbAllow)

                Button(Copy.onbNotNow, action: onNext)
                    .font(FillFont.scaled(15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(height: 44)
                    .accessibilityLabel(Copy.onbNotNow)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
        }
        .background(FillColor.orange)
        .task { await dropLoop() }
    }

    private var lockPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Copy.onbNotifLockTime)
                .font(.system(size: 58, weight: .light))
                .foregroundStyle(.white)
            Text(Copy.onbNotifLockDate)
                .font(FillFont.scaled(15, weight: .semibold))
                .foregroundStyle(.white)
            VStack(spacing: 8) {
                if showFirst {
                    notification(title: Copy.onbSample1Title,
                                 body: Copy.onbSample1Body,
                                 time: "8:00 PM")
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if showSecond {
                    notification(title: Copy.onbSample2Title,
                                 body: Copy.onbSample2Body,
                                 time: "9:12 PM")
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FillColor.ink.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Copy.onbNotifLockDate)
    }

    private func notification(title: String, body: String, time: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            WondayTile(size: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    WondayWord(size: 11, color: FillColor.ink, ring: FillColor.orange, track: FillColor.orangeTint)
                    Spacer(minLength: 6)
                    Text(time)
                        .font(FillFont.scaled(10))
                        .foregroundStyle(FillColor.text2)
                }
                notifTitle(title)
                notifBody(body)
            }
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Wonday. \(title). \(body)")
    }

    private func notifTitle(_ title: String) -> some View {
        if title == Copy.onbSample2Title {
            // “That’s a wonday! ✓” with a branded wonday.
            return AnyView(
                WondayFlow(spacing: 3) {
                    notifWord("That’s", bold: true)
                    notifWord("a", bold: true)
                    HStack(spacing: 0) {
                        WondayWord(size: 12, color: FillColor.ink, ring: FillColor.orange, track: FillColor.orangeTint)
                        Text("!").font(FillFont.scaled(12, weight: .bold)).foregroundStyle(FillColor.ink)
                    }
                    notifWord("✓", bold: true)
                }
            )
        }
        return AnyView(
            Text(title)
                .font(FillFont.scaled(12, weight: .bold))
                .foregroundStyle(FillColor.ink)
        )
    }

    private func notifBody(_ body: String) -> some View {
        if body == Copy.onbSample1Body {
            // “2,158 steps to make today a wonday.”
            return AnyView(
                WondayFlow(spacing: 3) {
                    notifWord("2,158")
                    notifWord("steps")
                    notifWord("to")
                    notifWord("make")
                    notifWord("today")
                    notifWord("a")
                    HStack(spacing: 0) {
                        WondayWord(size: 12, color: FillColor.ink.opacity(0.9), ring: FillColor.orange, track: FillColor.orangeTint)
                        Text(".").font(FillFont.scaled(12)).foregroundStyle(FillColor.ink.opacity(0.9))
                    }
                }
            )
        }
        return AnyView(
            Text(body)
                .font(FillFont.scaled(12))
                .foregroundStyle(FillColor.ink.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        )
    }

    private func notifWord(_ s: String, bold: Bool = false) -> some View {
        Text(s)
            .font(FillFont.scaled(12, weight: bold ? .bold : .regular))
            .foregroundStyle(bold ? FillColor.ink : FillColor.ink.opacity(0.9))
    }

    private func dropLoop() async {
        if reduceMotion {
            showFirst = true; showSecond = true
            return
        }
        while !Task.isCancelled {
            withAnimation(.easeOut(duration: 0.2)) {
                showFirst = false; showSecond = false
            }
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                showFirst = true
            }
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                showSecond = true
            }
            try? await Task.sleep(for: .seconds(3.0))
        }
    }

    private func allow() {
        guard allowState == .idle else { return }
        allowState = .asking
        Task { @MainActor in
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            let repo = Repository(context: context)
            repo.settings().notificationsAsked = true
            try? context.save()
            allowState = .allowed
            try? await Task.sleep(for: .seconds(0.8))
            onNext()
        }
    }
}
