import SwiftUI
import SwiftData
import UserNotifications

// SPEC §7.10 — Onboarding: 8 screens. Skip on 2–5 → 8. Welcome rolling
// example every 2.3s + recolor (manual swipe with Reduce Motion).
public struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var app
    @State private var page = 0
    @State private var roll = 0
    @State private var welcomeFill = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let examples: [(color: String, big: String, small: String, reward: String)] = [
        ("orange", "10,000", "steps a day", "₹10,000 each day"),
        ("pink", "500", "calories burned", "Pizza night"),
        ("violet", "30", "days of closed rings", "A trip to Taiwan"),
        ("blue", "21.1", "km in one run", "New running shoes"),
        ("teal", "8", "hours of sleep", "A spa day"),
        ("green", "70", "days of 10K steps", "A DGX Spark"),
    ]

    public var body: some View {
        TabView(selection: $page) {
            welcome().tag(0)
            deal().tag(1)
            trophy().tag(2)
            privacy().tag(3)
            health().tag(4)
            nudges().tag(5)
            youreSet().tag(6)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .onAppear { startRoll() }
    }

    private func startRoll() {
        guard !reduceMotion else { return }
        Task {
            while true {
                try? await Task.sleep(for: .seconds(2.3))
                await MainActor.run { roll = (roll + 1) % Self.examples.count }
            }
        }
    }

    private func welcome() -> some View {
        let e = Self.examples[roll]
        return GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.white.ignoresSafeArea()
                // Color rises from the bottom to ~60% of the screen, not full screen.
                FillColor.color(for: e.color)
                    .frame(height: geo.size.height * welcomeFill)
                    .frame(maxWidth: .infinity, alignment: .bottom)
                    .animation(.easeInOut(duration: 0.6), value: e.color)
                    .ignoresSafeArea(edges: .bottom)
                VStack(alignment: .leading, spacing: 12) {
                    Text("fill.").font(.system(size: 30, weight: .black))
                    Text("\(Copy.rewardYourself)\n\(Copy.toMove)").font(FillFont.welcomeTitle)
                        .lineLimit(2).minimumScaleFactor(0.75) // O06: exactly 2 lines
                    Text(Copy.dealLine).font(.system(size: 15, weight: .medium))
                    Spacer()
                    Text("YOUR GOAL → YOUR REWARD").font(FillFont.mono(11)).foregroundStyle(.white.opacity(0.8))
                    Text(e.big).font(.system(size: 72, weight: .black)).foregroundStyle(.white)
                    Text("\(e.small)\n→ \(e.reward)").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                    Button(Copy.getStarted) { page = 1 }
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(FillColor.color(for: e.color))
                        .frame(maxWidth: .infinity).frame(height: 60)
                        .background(.white, in: Capsule())
                        .accessibilityLabel(Copy.getStarted)
                    HStack(spacing: 8) {
                        chip(Copy.noSignup); chip(Copy.noAccount); chip(Copy.noServer)
                    }.padding(.bottom, 24)
                }
                .foregroundStyle(.black)
                .padding(24)
            }
            .onAppear {
                guard welcomeFill == 0 else { return }
                if reduceMotion { welcomeFill = 0.6 } else {
                    withAnimation(.easeOut(duration: 1.0)) { welcomeFill = 0.6 }
                }
            }
        }
    }
    private func chip(_ t: String) -> some View {
        Text("✓ \(t)").font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 8)
            .background(.white.opacity(0.2), in: Capsule())
    }
    // Demo sentence in the upper half, "You make the deal." in the bottom half.
    private func deal() -> some View {
        ZStack {
            FillColor.color(for: "pink").ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Button("Skip") { page = 6 }.foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityLabel("Skip")
                Text("I'll walk 10,000 steps a day on 20 of 30 days to win a trip to Taiwan")
                    .font(.system(size: 24, weight: .heavy)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 12) {
                    Text(Copy.makeDeal).font(FillFont.onbTitle).foregroundStyle(.white)
                    Text("Pick what you'll do, how often, and your reward. You pay for the reward yourself. The app only tracks it.")
                        .font(.system(size: 16)).foregroundStyle(.white.opacity(0.9))
                    Button("Next") { page += 1 }
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(FillColor.color(for: "pink"))
                        .frame(maxWidth: .infinity).frame(height: 60)
                        .background(.white, in: Capsule())
                        .accessibilityLabel("Next")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(24)
        }
    }
    // Circle centered in the upper half, text below.
    private func trophy() -> some View {
        ZStack {
            FillColor.color(for: "green").ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Button("Skip") { page = 6 }.foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityLabel("Skip")
                Text("20").font(.system(size: 72, weight: .black)).foregroundStyle(.white)
                    .frame(width: 160, height: 160).background(.white.opacity(0.25), in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                VStack(alignment: .leading, spacing: 12) {
                    Text(Copy.winItClaimIt).font(FillFont.onbTitle).foregroundStyle(.white)
                    Text("Finish a challenge to claim your reward. Then start a new one.")
                        .font(.system(size: 16)).foregroundStyle(.white.opacity(0.9))
                    Button("Next") { page += 1 }
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(FillColor.color(for: "green"))
                        .frame(maxWidth: .infinity).frame(height: 60)
                        .background(.white, in: Capsule())
                        .accessibilityLabel("Next")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(24)
        }
    }
    private func privacy() -> some View {
        onbPage(color: "ink", title: "Private by design.",
                body: "No sign-up, no account, no server. Everything stays on this iPhone.",
                content: Image(systemName: "lock.fill").font(.system(size: 60)).foregroundStyle(.white))
    }
    private func health() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Copy.connectHealth).font(FillFont.onbTitle)
            Text("The app reads your activity on this iPhone to check your goals. It never uploads, writes or shares your data.")
                .font(.system(size: 15))
            ForEach(["Steps", "Activity rings", "Exercise minutes", "Workouts and distance", "Sleep"], id: \.self) { t in
                HStack { Text(t).font(.system(size: 15, weight: .medium)); Spacer(); Toggle("", isOn: .constant(true)).labelsHidden() }
                    .padding().background(FillColor.chipBg, in: RoundedRectangle(cornerRadius: 16))
            }
            Button(Copy.connectHealth) { Task { await requestHealth(); page = 5 } }
                .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 60)
                .background(FillColor.ink, in: Capsule())
                .accessibilityLabel(Copy.connectHealth)
            Button(Copy.logByHand) {
                Repository(context: context).settings().manualMode = true
                try? context.save(); page = 5
            }.font(.system(size: 15, weight: .semibold))
            Spacer()
        }
        .padding(24).background(FillColor.bg)
    }
    private func nudges() -> some View {
        onbPage(color: "blue", title: Copy.nudgeTitle,
                body: "Only when a win is close, or when you win. No spam.",
                content: VStack(spacing: 8) {
                    Text("October 10K · 2,158 steps to go").padding().background(.white, in: RoundedRectangle(cornerRadius: 16))
                    Text("Day won. +₹10,000").padding().background(.white, in: RoundedRectangle(cornerRadius: 16))
                }, cta: (Copy.allowNotifs, { Task { await requestNotifications(); page = 6 } }), skip: ("Not now", { page = 6 }))
    }
    private func youreSet() -> some View {
        onbPage(color: "ink", title: Copy.youreSet,
                body: "No sign-up, no account. Everything stays on this iPhone. Make your first challenge. It takes 3 taps.",
                content: Image(systemName: "checkmark").font(.system(size: 60, weight: .bold)).foregroundStyle(.black)
                    .frame(width: 120, height: 120).background(.white, in: Circle()),
                cta: (Copy.makeFirst, finish(makeChallenge: true)),
                skip: ("Explore the demo first", finish(makeChallenge: false)))
    }
    private func onbPage(color: String, title: String, body: String, content: some View,
                         cta: (String, () -> Void)? = nil, skip: (String, () -> Void)? = nil) -> some View {
        ZStack {
            FillColor.color(for: color).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                if page >= 1 && page <= 4 {
                    Button("Skip") { page = 6 }.foregroundStyle(.white)
                        .accessibilityLabel("Skip")
                }
                Spacer()
                content
                Text(title).font(FillFont.onbTitle).foregroundStyle(.white)
                Text(body).font(.system(size: 16)).foregroundStyle(.white.opacity(0.9))
                if let cta {
                    Button(cta.0, action: cta.1)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(FillColor.color(for: color))
                        .frame(maxWidth: .infinity).frame(height: 60)
                        .background(.white, in: Capsule())
                } else {
                    Button("Next") { page += 1 }
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(FillColor.color(for: color))
                        .frame(maxWidth: .infinity).frame(height: 60)
                        .background(.white, in: Capsule())
                        .accessibilityLabel("Next")
                }
                if let skip {
                    Button(skip.0, action: skip.1)
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
        }
    }
    private func requestHealth() async {
        // H01/H02: system prompt; denial is silent, app works with 0s.
        _ = await HealthKitController.shared.authorize()
        Repository(context: context).settings().manualMode = false
        try? context.save()
    }
    private func requestNotifications() async {
        // IMPLEMENTATION §7: ask only here or in Settings.
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        Repository(context: context).settings().notificationsAsked = true
        try? context.save()
    }
    private func finish(makeChallenge: Bool) -> () -> Void {
        {
            Repository(context: context).settings().onboardingDone = true
            try? context.save()
            if makeChallenge { app.showingCreate = true }
        }
    }
}
