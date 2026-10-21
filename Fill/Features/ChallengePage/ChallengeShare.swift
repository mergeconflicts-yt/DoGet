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
        Copy.shareText(
            name: challenge.name,
            progress: progressLine(challenge: challenge, snapshot: snapshot),
            reward: Derive.rewardPhrase(challenge.reward, x: challenge.x)
        )
    }

    @MainActor public static func makeImage(challenge: Challenge, snapshot: Snapshot) -> UIImage? {
        let card = ShareCardView(challenge: challenge, snapshot: snapshot)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 600, height: 800)
        return renderer.uiImage
    }
}

// Lightweight card rendered to an image for sharing. Static, no animation,
// so Reduce Motion needs no special path. Fixed 600x800 for a stable image.
public struct ShareCardView: View {
    var challenge: Challenge
    var snapshot: Snapshot

    public init(challenge: Challenge, snapshot: Snapshot) {
        self.challenge = challenge
        self.snapshot = snapshot
    }

    public var body: some View {
        let c = FillColor.color(for: challenge.colorToken)
        VStack(alignment: .leading, spacing: 12) {
            Text(challenge.name)
                .font(FillFont.scaled(34, weight: .heavy, relativeTo: .title1))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(ChallengeShare.progressLine(challenge: challenge, snapshot: snapshot))
                .font(FillFont.scaled(20, weight: .bold))
                .foregroundStyle(.white)
            Text(Derive.rewardPhrase(challenge.reward, x: challenge.x))
                .font(FillFont.scaled(16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(3)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                WondayWord(size: 20, color: .white)
                Text("· \(Copy.shareAppLink)")
                    .font(FillFont.mono(12))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(32)
        .frame(width: 600, height: 800, alignment: .topLeading)
        .background(c)
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
