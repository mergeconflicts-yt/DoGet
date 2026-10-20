import Foundation
#if SWIFT_PACKAGE
@testable import FillDomain
#endif

// DATABASE.md §5 — read model: rows → DayResult. Domain sees only DayResults.
// (Pure-Swift side of Mapping; the SwiftData fetch side lives in Repository.)

// sourcery:skip
public enum Mapping {
    public static func dayResults(
        challenge: Challenge,
        metricDays: [String: Double], metricSources: [String: String], finalDays: Set<String>,
        manualLogs: [String: Double],
        today: DayKey
    ) -> (results: [DayResult], best: Double) {
        var results: [DayResult] = []
        var best = 0.0
        var d = challenge.start
        let yesterday = today.adding(days: -1)
        while d <= today {
            let h = metricDays[d.key] ?? 0
            let u = manualLogs[d.key]
            let value = max(h, u ?? 0)
            let manual = (u ?? 0) >= h
            let src: DataSource = manual ? .manual : (metricSources[d.key] == "motion" ? .motion : .health)
            // DATABASE §5: a stored row decides; yesterday stays open until
            // 03:00 (SPEC §11), so it is not final just because it is past.
            let isFinal = finalDays.contains(d.key) || d < yesterday
            results.append(DayResult(date: d, value: value, source: src, isFinal: isFinal))
            best = max(best, value)
            if d == today { break }
            d = d.adding(days: 1)
        }
        return (results, best)
    }
}
