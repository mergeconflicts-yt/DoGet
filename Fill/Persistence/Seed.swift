import Foundation
import SwiftData
#if SWIFT_PACKAGE
@testable import FillDomain
#endif

// DATABASE §10 + IMPLEMENTATION §11 — DEBUG-only seed demo data.
// [GAP] IMPLEMENTATION §13 seed list missing; reconstructed from ACCEPTANCE
// P-states + mockup pager (9 challenges incl. one USD seed for W05).
@MainActor
public enum Seed {
    public static func insert(into context: ModelContext) {
        let repo = Repository(context: context)
        let today = DayKey.from(date: Date(), calendar: .current)
        func mk(_ name: String, color: String, metric: Metric, target: Double,
                type: ChallengeType, x: Int, y: Int, startOffset: Int, reward: Reward) {
            let c = Challenge(name: name, colorToken: color, metric: metric, target: target,
                              type: type, x: x, y: y, start: today.adding(days: startOffset), reward: reward)
            repo.insertChallenge(c)
        }
        // 1. October 10K — F(20/30) steps, orange, money each ₹10,000 (A01/P02).
        mk("October 10K", color: "orange", metric: .steps, target: 10_000, type: .flex,
           x: 20, y: 30, startOffset: -12, reward: .moneyEach(amount: 10_000))
        // 2. DGX Spark — F(70/90) steps, green, item save ₹7,00,000 (P03/C05).
        mk("DGX Spark", color: "green", metric: .steps, target: 10_000, type: .flex,
           x: 70, y: 90, startOffset: 0,
           reward: Reward(kind: .item, category: .item, name: "DGX Spark", value: 700_000, itemPayout: .save))
        // 3. Run club — F(12/30) run 5.0, mustard/amber, money each ₹2,000.
        mk("Run club", color: "amber", metric: .run, target: 5.0, type: .flex,
           x: 12, y: 30, startOffset: 0, reward: .moneyEach(amount: 2_000))
        // 4. Kyoto streak — S(30) rings/teal?, violet, item end trip.
        mk("Kyoto streak", color: "violet", metric: .rings, target: 3, type: .streak,
           x: 30, y: 30, startOffset: -18,
           reward: Reward(kind: .item, category: .trip, name: "Kyoto", value: 500_000, itemPayout: .end))
        // 5. Savings jar — N jar ₹1,000 → ₹2,00,000, green (A14/P09).
        mk("Savings jar", color: "green", metric: .steps, target: 8_000, type: .open,
           x: 0, y: 0, startOffset: -100,
           reward: Reward(kind: .money, payout: .jar, amount: 1_000, jarTarget: 200_000))
        // 6. Sony A7 — F(20/30) exercise 30, purple/blue, item save USD (W05 seed).
        mk("Sony A7", color: "blue", metric: .exercise, target: 30, type: .flex,
           x: 20, y: 30, startOffset: -12,
           reward: Reward(kind: .item, currency: "USD", category: .item, name: "Sony A7", value: 2_000, itemPayout: .save))
        // 7. Sleep week — S(7) sleep 8, teal, item end food (claimed; W01 Omakase).
        mk("Sleep week", color: "teal", metric: .sleep, target: 8, type: .streak,
           x: 7, y: 7, startOffset: -7,
           reward: Reward(kind: .item, category: .food, name: "Omakase dinner", value: 6_000, itemPayout: .end))
        // 8. Half marathon — O run 21.1, blue, money end ₹50,000 (A12).
        mk("Half marathon", color: "blue", metric: .run, target: 21.1, type: .once,
           x: 1, y: 0, startOffset: -10,
           reward: Reward(kind: .money, payout: .end, amount: 50_000))
        // 9. Shoes — item end buy (In-progress 67% card).
        mk("Shoes", color: "pink", metric: .steps, target: 10_000, type: .flex,
           x: 12, y: 30, startOffset: -8,
           reward: Reward(kind: .item, category: .item, name: "Shoes", value: 12_000, itemPayout: .end))
        try? context.save()
    }
}
