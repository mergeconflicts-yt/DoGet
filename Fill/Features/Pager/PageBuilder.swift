import Foundation
import SwiftData

// M2 — builds one PageData per active challenge: Domain challenge +
// Engine snapshot + day-bar states + manual flag. Single place where
// store rows become UI input (DATABASE §5, IMPLEMENTATION §4).
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
        let repo = Repository(context: context)
        let records = repo.fetchActiveChallenges()
        let today = DayKey.from(date: now, calendar: calendar)
        let manualMode = repo.settings().manualMode

        let metricRows = (try? context.fetch(FetchDescriptor<MetricDay>())) ?? []
        let manualRows = (try? context.fetch(FetchDescriptor<ManualLog>())) ?? []
        var metricVals: [String: Double] = [:]
        var metricSrcs: [String: String] = [:]
        var finals: Set<String> = []
        for m in metricRows where m.dayKey <= today.key {
            metricVals["\(m.metricRaw)|\(m.dayKey)"] = m.value
            metricSrcs["\(m.metricRaw)|\(m.dayKey)"] = m.sourceRaw
            if m.isFinal { finals.insert("\(m.metricRaw)|\(m.dayKey)") }
        }
        var manualVals: [String: Double] = [:]
        for m in manualRows where m.dayKey <= today.key {
            manualVals["\(m.metricRaw)|\(m.dayKey)"] = m.value
        }

        return records.compactMap { rec in
            guard let c = toChallenge(rec) else { return nil }
            let md = Dictionary(uniqueKeysWithValues: metricVals
                .filter { $0.key.hasPrefix("\(c.metric.rawValue)|") }
                .map { (String($0.key.split(separator: "|")[1]), $0.value) })
            let ms = Dictionary(uniqueKeysWithValues: metricSrcs
                .filter { $0.key.hasPrefix("\(c.metric.rawValue)|") }
                .map { (String($0.key.split(separator: "|")[1]), $0.value) })
            let man = Dictionary(uniqueKeysWithValues: manualVals
                .filter { $0.key.hasPrefix("\(c.metric.rawValue)|") }
                .map { (String($0.key.split(separator: "|")[1]), $0.value) })
            let fin = Set(finals.filter { $0.hasPrefix("\(c.metric.rawValue)|") }
                .map { String($0.split(separator: "|")[1]) })
            let (results, best) = Mapping.dayResults(challenge: c, metricDays: md,
                metricSources: ms, finalDays: fin, manualLogs: man, today: today)
            let snap = Engine.snapshot(challenge: c, days: results, best: best,
                                       now: now, calendar: calendar)
            let states = dayStates(challenge: c, results: results, snapshot: snap, today: today)
            return PageData(record: rec, challenge: c, snapshot: snap,
                            states: states, manualMode: manualMode)
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
