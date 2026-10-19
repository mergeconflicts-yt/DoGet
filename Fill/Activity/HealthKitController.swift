import Foundation
import HealthKit

public extension Notification.Name {
    /// Posted when a HealthKit observer fires (IMPLEMENTATION §5.4).
    /// RootView refreshes the Evaluator on receipt.
    static let fillHealthUpdate = Notification.Name("com.fill.app.healthUpdate")
}

// IMPLEMENTATION §5.2–§5.4 — HealthKit access lives here, not in views.
// Read only; never writes. Denial is silent (SPEC §9/H02).
@MainActor
public final class HealthKitController {
    public static let shared = HealthKitController()
    private let store = HKHealthStore()
    private var observersRegistered = false
    private init() {}

    public static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// SPEC §9 read set (share nothing).
    public static func readTypes() -> Set<HKObjectType> {
        var t: Set<HKObjectType> = []
        for id in [HKQuantityTypeIdentifier.stepCount,
                   .distanceWalkingRunning,
                   .activeEnergyBurned,
                   .basalEnergyBurned,
                   .appleExerciseTime,
                   .appleStandTime] as [HKQuantityTypeIdentifier] {
            if let q = HKObjectType.quantityType(forIdentifier: id) { t.insert(q) }
        }
        if let w = HKObjectType.workoutType() as HKObjectType? { t.insert(w) }
        if let s = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { t.insert(s) }
        t.insert(HKObjectType.activitySummaryType())
        return t
    }

    /// Shows the system prompt (once per install). Returns authorization state;
    /// denial is indistinguishable from no data — never an error UI (H02).
    public func authorize() async -> Bool {
        guard Self.isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: Self.readTypes())
            // Observer queries created before authorization die with
            // "Authorization not determined" — re-register now that we can read.
            observersRegistered = false
            registerBackgroundDelivery()
            return true
        } catch {
            return false
        }
    }

    /// IMPLEMENTATION §5.4 — register before the first frame; hourly for steps
    /// (iOS limit), immediate for the rest. Posts .fillHealthUpdate on fire.
    public func registerBackgroundDelivery() {
        guard Self.isAvailable, !observersRegistered else { return }
        observersRegistered = true
        let steps = HKQuantityTypeIdentifier.stepCount
        let immediate: [HKQuantityTypeIdentifier] = [.activeEnergyBurned, .appleExerciseTime]
        if let q = HKQuantityType.quantityType(forIdentifier: steps) {
            store.enableBackgroundDelivery(for: q, frequency: .hourly) { _, _ in }
            addObserver(for: q)
        }
        for id in immediate {
            if let q = HKQuantityType.quantityType(forIdentifier: id) {
                store.enableBackgroundDelivery(for: q, frequency: .immediate) { _, _ in }
                addObserver(for: q)
            }
        }
        if let w = HKObjectType.workoutType() as HKWorkoutType? {
            store.enableBackgroundDelivery(for: w, frequency: .immediate) { _, _ in }
            addSampleObserver(for: w)
        }
        if let s = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            store.enableBackgroundDelivery(for: s, frequency: .immediate) { _, _ in }
            addSampleObserver(for: s)
        }
    }

    private func addObserver(for type: HKQuantityType) {
        let q = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, _ in
            completion()
            // Post on main: SwiftUI onReceive runs on the posting thread, and
            // background delivery must never publish model updates off-main.
            Task { @MainActor in
                NotificationCenter.default.post(name: .fillHealthUpdate, object: nil)
            }
        }
        store.execute(q)
    }

    private func addSampleObserver(for type: HKSampleType) {
        let q = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, _ in
            completion()
            Task { @MainActor in
                NotificationCenter.default.post(name: .fillHealthUpdate, object: nil)
            }
        }
        store.execute(q)
    }

    /// H05 — stand-hour samples in the last 7 days mean an Apple Watch.
    public func hasWatchData() async -> Bool {
        guard Self.isAvailable else { return false }
        guard let q = HKQuantityType.quantityType(forIdentifier: .appleStandTime) else { return false }
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(quantityType: q,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: end, options: [])) { _, r, _ in
                cont.resume(returning: (r?.sumQuantity()?.doubleValue(for: .hour()) ?? 0) > 0)
            }
            store.execute(query)
        }
    }
}
