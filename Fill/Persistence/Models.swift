import Foundation
import SwiftData

// DATABASE.md §4 — CloudKit-safe: all props optional-or-defaulted, no @Attribute(.unique),
// links by ID not relationships. Synced store: ChallengeRecord, RewardEntry, ManualLog.
// Local store: MetricDay, AppSettings, NotificationLog.

@Model
public final class ChallengeRecord {
    public var id: UUID = UUID()
    public var name: String = ""
    public var colorToken: String = "orange"
    public var metricRaw: String = "steps"
    public var target: Double = 10_000
    public var typeRaw: String = "flex"
    public var x: Int = 20
    public var y: Int = 30
    public var startKey: String = ""
    public var rewardData: Data = Data()
    public var rewardSchemaVersion: Int = 1
    public var level: Int = 1
    public var parentID: UUID? = nil
    public var createdAt: Date = Date()
    public var claimedAt: Date? = nil
    public var closedAt: Date? = nil
    public var archivedAt: Date? = nil
    public var outOfReachNotifiedAt: Date? = nil
    public var restartCount: Int = 0
    public init() {}
}

@Model
public final class RewardEntry {
    public var id: UUID = UUID()
    public var challengeID: UUID = UUID()
    public var kindRaw: String = "perWin" // perWin | itemSaving | final
    public var dayKey: String = ""
    public var amount: Decimal = 0
    public var itemValue: Decimal = 0
    public var currency: String = "INR"
    public var isManual: Bool = false
    public var challengeName: String = ""
    public var colorToken: String = "orange"
    public var itemName: String = ""
    public var categoryRaw: String = ""
    public var createdAt: Date = Date()
    public init() {}
}

@Model
public final class ManualLog {
    public var metricRaw: String = "steps"
    public var dayKey: String = ""
    public var value: Double = 0
    public var updatedAt: Date = Date()
    public init() {}
}

@Model
public final class MetricDay {
    public var metricRaw: String = "steps"
    public var dayKey: String = ""
    public var value: Double = 0
    public var sourceRaw: String = "health"
    public var isFinal: Bool = false
    public var fetchedAt: Date = Date()
    public init() {}
}

@Model
public final class AppSettings {
    public var onboardingDone: Bool = false
    public var manualMode: Bool = false
    public var notificationsAsked: Bool = false
    public var nudgeHour: Int = 20
    public var nudgeMinute: Int = 0
    public var iCloudBackup: Bool = false
    public var lastEvaluatedKey: String = ""
    public var paletteCursor: Int = 0
    public init() {}
}

@Model
public final class NotificationLog {
    public var challengeID: UUID = UUID()
    public var dayKey: String = ""
    public var kindRaw: String = "nudge"
    public var deliveredAt: Date = Date()
    public init() {}
}
