import Foundation
import HealthKit

public extension Notification.Name {
    /// Posted when a HealthKit observer fires (IMPLEMENTATION §5.4).
    /// RootView refreshes the Evaluator on receipt.
    static let fillHealthUpdate = Notification.Name("com.wonday.rewards.healthUpdate")
}

// IMPLEMENTATION §5.2–§5.4 — HealthKit access lives here, not in views.
// Read only; never writes. Denial is silent (SPEC §9/H02).
@MainActor
public final class HealthKitController {
    public static let shared = HealthKitController()
    private let store = HKHealthStore()
    private var observersRegistered = false
    /// Set by RootView. Observer completion waits for this so HealthKit is not
    /// told the update is done before the Evaluator has read it (review Medium).
    public var onRefresh: (@MainActor () async -> Void)?
    private init() {}

    public static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// SPEC §9 read set (share nothing).
    public static func readTypes() -> Set<HKObjectType> {
        var t: Set<HKObjectType> = []
        for id in [HKQuantityTypeIdentifier.stepCount,
                   .distanceWalkingRunning,
                   .activeEnergyBurned,
                   .basalEnergyBurned,
                   .appleExerciseTime] as [HKQuantityTypeIdentifier] {
            if let q = HKObjectType.quantityType(forIdentifier: id) { t.insert(q) }
        }
        if let w = HKObjectType.workoutType() as HKObjectType? { t.insert(w) }
        if let s = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { t.insert(s) }
        // Stand hours are a category sample (one per hour), not a quantity.
        if let s = HKObjectType.categoryType(forIdentifier: .appleStandHour) { t.insert(s) }
        t.insert(HKObjectType.activitySummaryType())
        return t
    }

    /// Shows the system prompt (once per install). Returns true only if at
    /// least one read type is actually authorized; denial is silent (H02)
    /// so callers must not show an error, just stay unconnected.
    /// Note: iOS shows the sheet only once — later calls return immediately,
    /// so callers must send an already-determined-but-denied user to Settings.
    public func authorize() async -> Bool {
        guard Self.isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: Self.readTypes())
            guard isAuthorized else { return false }
            // Observer queries created before authorization die with
            // "Authorization not determined" — re-register now that we can read.
            observersRegistered = false
            registerBackgroundDelivery()
            return true
        } catch {
            return false
        }
    }

    /// True once iOS has asked at all (granted or denied). After this,
    /// requestAuthorization no longer shows UI.
    public var hasBeenAsked: Bool {
        for t in Self.readTypes() {
            if store.authorizationStatus(for: t) != .notDetermined { return true }
        }
        return false
    }

    /// True when the user granted at least one read type. iOS never
    /// pre-selects anything: the system sheet always starts with everything
    /// off and the user must toggle each type on by hand.
    public var isAuthorized: Bool {
        for t in Self.readTypes() {
            if store.authorizationStatus(for: t) == .sharingAuthorized { return true }
        }
        return false
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
            // Run the Evaluator first, then tell HealthKit we are done. iOS
            // throttles or stops delivery if completion is called too early.
            let done = SendableCompletion(completion)
            Task { @MainActor in
                await HealthKitController.shared.onRefresh?()
                done.run()
                NotificationCenter.default.post(name: .fillHealthUpdate, object: nil)
            }
        }
        store.execute(q)
    }

    private func addSampleObserver(for type: HKSampleType) {
        let q = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, _ in
            let done = SendableCompletion(completion)
            Task { @MainActor in
                await HealthKitController.shared.onRefresh?()
                done.run()
                NotificationCenter.default.post(name: .fillHealthUpdate, object: nil)
            }
        }
        store.execute(q)
    }

    /// H05 — stand-hour samples in the last 7 days mean an Apple Watch.
    /// (The old query used appleStandTime, a quantity the Watch does not
    /// necessarily write; stand hours are category samples.)
    public func hasWatchData() async -> Bool {
        guard Self.isAvailable else { return false }
        guard let q = HKObjectType.categoryType(forIdentifier: .appleStandHour) else { return false }
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        return await withCheckedContinuation { cont in
            let p = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKSampleQuery(sampleType: q, predicate: p, limit: 1,
                                      sortDescriptors: nil) { _, samples, _ in
                cont.resume(returning: !(samples ?? []).isEmpty)
            }
            store.execute(query)
        }
    }
}

/// HealthKit's observer completion handler is not Sendable in the SDK yet,
/// but it is safe to call once. This box lets us await the Evaluator on the
/// main actor and then call it without a Swift 6 region-isolation error.
private struct SendableCompletion: @unchecked Sendable {
    let run: () -> Void
    init(_ run: @escaping () -> Void) { self.run = run }
}
