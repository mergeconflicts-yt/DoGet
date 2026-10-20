import Foundation
import SwiftData

// M2 — builds one PageData per active challenge: Domain challenge +
// Engine snapshot + day-bar states + manual flag. It delegates the read model
// to EvaluationEngine.pages so the Evaluator and the UI can never disagree
// (DATABASE §5, IMPLEMENTATION §4).
public struct PageData: Identifiable {
    public var id: UUID { challenge.id }
    public var record: ChallengeRecord
    public var challenge: Challenge
    public var snapshot: Snapshot
    public var states: [ChallengePageView.DayState]
    public var manualMode: Bool
}

@MainActor
public enum PageBuilder {
    public static func build(context: ModelContext, now: Date = Date(),
                             calendar: Calendar = .current) -> [PageData] {
        let manualMode = Repository(context: context).settings().manualMode
        let today = DayKey.from(date: now, calendar: calendar)
        return EvaluationEngine.pages(context: context, now: now, calendar: calendar).map { p in
            PageData(record: p.record, challenge: p.challenge, snapshot: p.snapshot,
                     states: dayStates(challenge: p.challenge, results: p.results,
                                       snapshot: p.snapshot, today: today),
                     manualMode: manualMode)
        }
    }

    static func dayStates(challenge c: Challenge, results: [DayResult],
                          snapshot: Snapshot, today: DayKey) -> [ChallengePageView.DayState] {
        let window: Int? = {
            switch c.type {
            case .flex: return c.y
            case .streak: return c.x
            case .open: return max(7, snapshot.dayIndex + 1)
            case .once: return nil
            }
        }()
        guard let w = window else { return [] }
        let byDay = Dictionary(uniqueKeysWithValues: results.map { ($0.date.key, $0) })
        return (0..<w).map { i in
            let key = c.start.adding(days: i)
            if key == today {
                if snapshot.todayWon {
                    let manual = byDay[key.key]?.source == .manual
                    return .won(manual: manual)
                }
                return .today(ratio: snapshot.todayRatio)
            }
            if key > today { return .future }
            if let r = byDay[key.key] {
                if r.value >= c.target { return .won(manual: r.source == .manual) }
                return .missed
            }
            return .missed
        }
    }
}
