import SwiftUI
import UIKit

// Share a challenge: progress card image + text + app link.
// Image + text + link via the system share sheet (user-initiated only,
// no network, Health data never leaves the device except what the user shares).
public enum ChallengeShare {
    public static var appURL: URL {
        URL(string: Copy.shareAppLink) ?? URL(string: "https://wonday.kranehx.com/")!
    }

    public static func progressLine(challenge: Challenge, snapshot: Snapshot) -> String {
        switch challenge.type {
        case .flex, .streak:
            return "\(snapshot.wins) of \(challenge.x) wins"
        case .once:
            return "best \(Format.metric(snapshot.best, metric: challenge.metric)) of \(Format.metric(challenge.target, metric: challenge.metric))"
        case .open:
            if challenge.reward.kind == .money, challenge.reward.payout == .jar {
                return "\(Format.money(challenge.reward.amount * Decimal(snapshot.wins), currency: challenge.reward.currency)) saved of \(Format.money(challenge.reward.jarTarget, currency: challenge.reward.currency))"
            }
            return "\(snapshot.wins) wins so far"
        }
    }

    public static func text(challenge: Challenge, snapshot: Snapshot) -> String {
        Copy.shareChallenge(
            sentence: sentence(challenge: challenge),
            progress: progressLine(challenge: challenge, snapshot: snapshot)
        )
    }

    /// "I'll walk 10,000 steps a day on 20 of 30 days to win 10,000 bucks each time"
    public static func sentence(challenge: Challenge) -> String {
        let target = Format.metric(challenge.target, metric: challenge.metric)
        let act: String = {
            switch challenge.metric {
            case .steps: return Copy.actSteps(target)
            case .rings: return Copy.actRings("\(Int(challenge.target))")
            case .exercise: return Copy.actExercise("\(Int(challenge.target))")
            case .run: return Copy.actRun(target)
            case .sleep: return Copy.actSleep(target)
            case .calories: return Copy.actCalories("\(Int(challenge.target))")
            }
        }()
        let rule: String = {
            switch challenge.type {
            case .flex: return Copy.createRuleFlex(challenge.x, challenge.y)
            case .streak: return Copy.createRuleStreak(challenge.x)
            case .once: return Copy.createRuleOnce
            case .open: return Copy.createRuleOpen
            }
        }()
        let reward = Derive.rewardPhrase(challenge.reward, x: challenge.x)
        return "I'll \(act) \(MetricDefaults.suffix(for: challenge.metric)) \(rule) to win \(reward)"
    }
}

// UIActivityViewController wrapper: shares image + text + link together.
public struct ActivityView: UIViewControllerRepresentable {
    var items: [Any]

    public init(items: [Any]) { self.items = items }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    public func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
