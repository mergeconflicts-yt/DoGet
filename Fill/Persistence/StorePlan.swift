import Foundation

// DATABASE.md §2 — store membership in one place so FillApp and D06 agree.
// Synced (iCloud private DB when backup is on): user-made + earned data.
// Local (never leaves the iPhone): Health/Motion values, settings, caches.
public enum StorePlan {
    public static let synced: [String] = ["ChallengeRecord", "RewardEntry", "ManualLog"]
    public static let local: [String] = ["MetricDay", "AppSettings", "NotificationLog"]
}
