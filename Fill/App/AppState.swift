import SwiftUI
import SwiftData

// App-wide state: pager selection, sheets, toasts. Overlays owned here
// so the Evaluator can open them (IMPLEMENTATION §8.4).
@Observable @MainActor
public final class AppState {
    public var selectedPage: Int = 0 // 0 = Overview
    public var showingCreate = false
    public var showingSettings = false
    /// Log today sheet context: metric + its target + color (manual mode).
    public var showingLogToday: LogTodayRequest? = nil
    /// C12: after Start, the pager scrolls to the new (last) page.
    public var selectNewChallenge = false
    public var toast: String? = nil
    public var dayWon: (name: String, amount: String, wins: Int)?
    public var celebrating: UUID? = nil
    public var debugAdvanceDays = 0
    #if DEBUG
    public var showingDebug = false
    #endif

    public init() {}

    /// Debug "Advance clock +1 day": the time given to Engine/Evaluator.
    public var now: Date {
        Calendar.current.date(byAdding: .day, value: debugAdvanceDays, to: Date()) ?? Date()
    }

    public func showDayWon(name: String, amount: String, wins: Int) {
        dayWon = (name, amount, wins)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6)) // SPEC §7.4
            dayWon = nil
        }
    }

    public func showToast(_ t: String) {
        toast = t
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            if toast == t { toast = nil }
        }
    }
}

/// Log today sheet context (SPEC §7.9): every challenge on that metric uses
/// the value, so the sheet only needs the metric, its target and the color.
public struct LogTodayRequest: Identifiable, Equatable, Sendable {
    public var id: String { metric.rawValue }
    public var metric: Metric
    public var target: Double
    public var colorToken: String
    public init(metric: Metric, target: Double, colorToken: String) {
        self.metric = metric
        self.target = target
        self.colorToken = colorToken
    }
}
