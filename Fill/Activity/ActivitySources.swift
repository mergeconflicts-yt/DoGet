import Foundation
import HealthKit
import CoreMotion

// IMPLEMENTATION §5.1 — one metric, one day; + best since a day (One time).
public protocol ActivitySource: Sendable {
    func value(metric: Metric, day: DayKey, calendar: Calendar) async -> Double
    func best(metric: Metric, since: DayKey, calendar: Calendar) async -> Double
}

// IMPLEMENTATION §5.3 — HealthKit day values (read only, never written).
public actor HealthKitSource: ActivitySource {
    private let store = HKHealthStore()
    public init() {}
    public func value(metric: Metric, day: DayKey, calendar: Calendar) async -> Double {
        let range = day.timeRange(in: calendar)
        switch metric {
        case .steps:
            return await sum(.stepCount, unit: .count(), range: range)
        case .calories:
            return await sum(.activeEnergyBurned, unit: .kilocalorie(), range: range)
        case .exercise:
            return await sum(.appleExerciseTime, unit: .minute(), range: range)
        case .run:
            return await longestRun(range: range)
        case .sleep:
            return await sleepHours(day: day, calendar: calendar)
        case .rings:
            return await ringsClosed(day: day, calendar: calendar)
        }
    }
    public func best(metric: Metric, since: DayKey, calendar: Calendar) async -> Double {
        // One time: max single-day value in window (run: longest single run).
        var b = 0.0
        var d = since
        let today = DayKey.from(date: Date(), calendar: calendar)
        while d <= today {
            b = max(b, await value(metric: metric, day: d, calendar: calendar))
            if d == today { break }
            d = d.adding(days: 1)
        }
        return b
    }
    private func sum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, range: Range<Date>) async -> Double {
        guard let t = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: HKQuery.predicateForSamples(
                withStart: range.lowerBound, end: range.upperBound, options: .strictStartDate)) { _, r, _ in
                cont.resume(returning: r?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(q)
        }
    }
    private func longestRun(range: Range<Date>) async -> Double {
        await withCheckedContinuation { cont in
            let run = HKQuery.predicateForWorkouts(with: .running)
            let dates = HKQuery.predicateForSamples(withStart: range.lowerBound,
                end: range.upperBound, options: .strictStartDate)
            let p = NSCompoundPredicate(andPredicateWithSubpredicates: [run, dates])
            let q = HKSampleQuery(sampleType: .workoutType(), predicate: p, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: nil) { _, samples, _ in
                let best = (samples as? [HKWorkout])?.filter {
                    $0.startDate >= range.lowerBound && $0.endDate <= range.upperBound
                }.map { $0.totalDistance?.doubleValue(for: .meter()) ?? 0 }.max() ?? 0
                cont.resume(returning: best / 1000)
            }
            store.execute(q)
        }
    }
    private func sleepHours(day: DayKey, calendar: Calendar) async -> Double {
        // A sleep sample belongs to the day it ENDS on: asleep samples ending
        // 12:00 the day before → 12:00 this day. An overlap window counted the
        // same sample on two days (review Medium).
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        var comp = DateComponents(); comp.year = day.year; comp.month = day.month; comp.day = day.day
        guard let midnight = calendar.date(from: comp),
              let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: midnight),
              let start = calendar.date(byAdding: .day, value: -1, to: noon) else { return 0 }
        return await withCheckedContinuation { cont in
            let p = HKQuery.predicateForSamples(withStart: start, end: noon, options: .strictEndDate)
            let q = HKSampleQuery(sampleType: type, predicate: p,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let asleep: Set<Int> = [HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                                        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                                        HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                                        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue]
                let total = (samples as? [HKCategorySample])?.filter { asleep.contains($0.value) }
                    .map { $0.endDate.timeIntervalSince($0.startDate) }.reduce(0, +) ?? 0
                cont.resume(returning: total / 3600)
            }
            store.execute(q)
        }
    }
    private func ringsClosed(day: DayKey, calendar: Calendar) async -> Double {
        // That day's activity summary: how many of Move/Exercise/Stand hit goal.
        // Move is active energy against its goal; appleMoveTime is a different
        // metric and made a 3-ring target unwinnable for most people (High 3).
        await withCheckedContinuation { cont in
            var comps = DateComponents()
            comps.year = day.year; comps.month = day.month; comps.day = day.day
            let p = HKQuery.predicate(forActivitySummariesBetweenStart: comps, end: comps)
            let q = HKActivitySummaryQuery(predicate: p) { _, summaries, _ in
                let cal = calendar
                let match = summaries?.first {
                    let c = $0.dateComponents(for: cal)
                    return c.year == day.year && c.month == day.month && c.day == day.day
                }
                guard let s = match else { cont.resume(returning: 0); return }
                var n = 0.0
                let move = s.activeEnergyBurned.doubleValue(for: .kilocalorie())
                let moveGoal = s.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie())
                if moveGoal > 0, move >= moveGoal { n += 1 }
                let exercise = s.appleExerciseTime.doubleValue(for: .minute())
                let exerciseGoal = s.appleExerciseTimeGoal.doubleValue(for: .minute())
                if exerciseGoal > 0, exercise >= exerciseGoal { n += 1 }
                let stand = s.appleStandHours.doubleValue(for: .count())
                let standGoal = s.appleStandHoursGoal.doubleValue(for: .count())
                if standGoal > 0, stand >= standGoal { n += 1 }
                cont.resume(returning: n)
            }
            store.execute(q)
        }
    }
}

// IMPLEMENTATION §5.5 — Core Motion fallback, steps only, 7-day history.
public actor MotionSource: ActivitySource {
    private let pedo = CMPedometer()
    public init() {}
    public func value(metric: Metric, day: DayKey, calendar: Calendar) async -> Double {
        guard metric == .steps, CMPedometer.isStepCountingAvailable() else { return 0 }
        let range = day.timeRange(in: calendar)
        return await withCheckedContinuation { cont in
            pedo.queryPedometerData(from: range.lowerBound, to: range.upperBound) { data, _ in
                cont.resume(returning: data?.numberOfSteps.doubleValue ?? 0)
            }
        }
    }
    public func best(metric: Metric, since: DayKey, calendar: Calendar) async -> Double { 0 }
}

// Manual source reads ManualLog via Repository (called on MainActor by Evaluator).
public struct ManualSource: ActivitySource {
    var logs: [String: Double]
    public func value(metric: Metric, day: DayKey, calendar: Calendar) async -> Double {
        logs["\(metric.rawValue)|\(day.key)"] ?? 0
    }
    public func best(metric: Metric, since: DayKey, calendar: Calendar) async -> Double { 0 }
}
