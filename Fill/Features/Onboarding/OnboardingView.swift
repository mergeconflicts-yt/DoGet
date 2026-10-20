import SwiftUI
import SwiftData

// Wonday welcome + onboarding (onboarding.txt). Five screens, no TabView:
// the new screen slides in from the right while the old one slips left and
// fades (Reduce Motion: plain cross-fade). Onboarding shows once; Settings
// replays it.

public struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Step: Int, CaseIterable {
        case welcome, walk, health, notifications, set
    }

    @State private var step: Step = .welcome
    @State private var forward = true

    public init() {}

    public var body: some View {
        ZStack {
            switch step {
            case .welcome:
                WelcomePage(onStart: { go(.walk) })
                    .transition(pageTransition)
            case .walk:
                WalkToUnlockPage(onBack: { go(.welcome, forward: false) },
                                 onNext: { go(.health) })
                    .transition(pageTransition)
            case .health:
                HealthConnectPage(onBack: { go(.walk, forward: false) },
                                  onNext: { go(.notifications) })
                    .transition(pageTransition)
            case .notifications:
                NotificationsPage(onBack: { go(.health, forward: false) },
                                  onNext: { go(.set) })
                    .transition(pageTransition)
            case .set:
                YoureSetPage(onStart: startChallenge, onMakeOwn: makeOwn)
                    .transition(pageTransition)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .easeOut(duration: 0.5), value: step)
    }

    private var pageTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        if forward {
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .offset(x: -70).combined(with: .opacity))
        }
        return .asymmetric(
            insertion: .move(edge: .leading),
            removal: .offset(x: 70).combined(with: .opacity))
    }

    private func go(_ next: Step, forward direction: Bool = true) {
        guard next != step else { return }
        forward = direction
        step = next
    }

    // MARK: End of onboarding

    private func startChallenge() {
        let repo = Repository(context: context)
        let today = DayKey.from(date: Date(), calendar: .current)
        let challenge = Challenge(
            name: Copy.onbFirstChallengeName,
            colorToken: "orange", metric: .steps, target: 10_000,
            type: .flex, x: 20, y: 30, start: today,
            reward: .moneyEach(amount: 10_000))
        repo.insertChallenge(challenge)
        finish()
        app.selectNewChallenge = true
        app.showToast(Copy.onbStartedToast)
    }

    private func makeOwn() {
        finish()
        app.showingCreate = true
    }

    private func finish() {
        let repo = Repository(context: context)
        let settings = repo.settings()
        settings.onboardingDone = true
        // A "Not now" on the notification screen leaves this false, so the
        // prompt is asked again after the first real win (onboarding.txt).
        try? context.save()
    }
}
