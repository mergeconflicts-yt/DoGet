import Foundation
import SwiftData
#if SWIFT_PACKAGE
@testable import FillDomain
#endif

// DATABASE.md §6–§7 — all writes go through Repository upserts. One save per action.
@MainActor
public final class Repository {
    let context: ModelContext
    public init(context: ModelContext) { self.context = context }

    // MARK: Challenge
    @discardableResult
    public func insertChallenge(_ c: Challenge) -> ChallengeRecord {
        let r = ChallengeRecord()
        r.id = c.id; r.name = c.name; r.colorToken = c.colorToken
        r.metricRaw = c.metric.rawValue; r.target = c.target
        r.typeRaw = c.type.rawValue; r.x = c.x; r.y = c.y
        r.startKey = c.start.key
        r.rewardData = (try? JSONEncoder().encode(c.reward)) ?? Data()
        r.level = c.level
        if c.claimed, r.claimedAt == nil { r.claimedAt = Date() }
        if c.closed, r.closedAt == nil { r.closedAt = Date() }
        if c.archived, r.archivedAt == nil { r.archivedAt = Date() }
        context.insert(r)
        try? context.save()
        return r
    }

    public func fetchActiveChallenges() -> [ChallengeRecord] {
        let d = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate { $0.archivedAt == nil },
            sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(d)) ?? []
    }

    // MARK: MetricDay upsert — max(old,new) unless final (D08).
    public func upsertMetricDay(metric: String, dayKey: String, value: Double, source: String = "health") {
        let d = FetchDescriptor<MetricDay>(
            predicate: #Predicate { $0.metricRaw == metric && $0.dayKey == dayKey })
        let rows = (try? context.fetch(d)) ?? []
        if let row = rows.first {
            if !row.isFinal { row.value = max(row.value, value) }
            for dup in rows.dropFirst() { context.delete(dup) }
        } else {
            let row = MetricDay()
            row.metricRaw = metric; row.dayKey = dayKey; row.value = value; row.sourceRaw = source
            context.insert(row)
        }
    }

    // MARK: ManualLog upsert — never lowered (D02).
    public func upsertManualLog(metric: String, dayKey: String, value: Double) {
        let d = FetchDescriptor<ManualLog>(
            predicate: #Predicate { $0.metricRaw == metric && $0.dayKey == dayKey })
        let rows = (try? context.fetch(d)) ?? []
        if let row = rows.first {
            row.value = max(row.value, value); row.updatedAt = Date()
            for dup in rows.dropFirst() { context.delete(dup) }
        } else {
            let row = ManualLog()
            row.metricRaw = metric; row.dayKey = dayKey; row.value = value
            context.insert(row)
        }
        try? context.save()
    }

    // MARK: RewardEntry — insert only if missing (D03).
    public func hasRewardEntry(challengeID: UUID, kind: String, dayKey: String) -> Bool {
        let cid = challengeID
        let d = FetchDescriptor<RewardEntry>(
            predicate: #Predicate { $0.challengeID == cid && $0.kindRaw == kind && $0.dayKey == dayKey })
        return ((try? context.fetch(d)) ?? []).isEmpty == false
    }
    public func insertRewardEntry(challengeID: UUID, kind: String, dayKey: String,
                                 amount: Decimal = 0, itemValue: Decimal = 0,
                                 currency: String = "INR", isManual: Bool = false,
                                 challengeName: String = "", colorToken: String = "",
                                 itemName: String = "", category: String = "") {
        let cid = challengeID
        let d = FetchDescriptor<RewardEntry>(
            predicate: #Predicate { $0.challengeID == cid && $0.kindRaw == kind && $0.dayKey == dayKey })
        if let rows = try? context.fetch(d), !rows.isEmpty { return }
        let e = RewardEntry()
        e.challengeID = challengeID; e.kindRaw = kind; e.dayKey = dayKey
        e.amount = amount; e.itemValue = itemValue; e.currency = currency
        e.isManual = isManual; e.challengeName = challengeName; e.colorToken = colorToken
        e.itemName = itemName; e.categoryRaw = category
        context.insert(e)
        try? context.save()
    }

    // MARK: Dedupe pass (launch + remote change).
    public func dedupe() {
        // RewardEntry: keep oldest per (challengeID, kind, dayKey).
        if let all = try? context.fetch(FetchDescriptor<RewardEntry>()) {
            var seen: [String: RewardEntry] = [:]
            for e in all {
                let k = "\(e.challengeID.uuidString)|\(e.kindRaw)|\(e.dayKey)"
                if let old = seen[k] {
                    if e.createdAt < old.createdAt { context.delete(old); seen[k] = e }
                    else { context.delete(e) }
                } else { seen[k] = e }
            }
        }
        // MetricDay: keep max value.
        if let all = try? context.fetch(FetchDescriptor<MetricDay>()) {
            var seen: [String: MetricDay] = [:]
            for m in all {
                let k = "\(m.metricRaw)|\(m.dayKey)"
                if let old = seen[k] {
                    old.value = max(old.value, m.value); context.delete(m)
                } else { seen[k] = m }
            }
        }
        try? context.save()
    }

    // MARK: Settings single row.
    public func settings() -> AppSettings {
        let d = FetchDescriptor<AppSettings>()
        if let rows = try? context.fetch(d), let first = rows.first {
            for dup in rows.dropFirst() { context.delete(dup) }
            return first
        }
        let s = AppSettings(); context.insert(s)
        return s
    }
}

// MARK: - Record → Domain
public func toChallenge(_ r: ChallengeRecord) -> Challenge? {
    guard let metric = Metric(rawValue: r.metricRaw),
          let type = ChallengeType(rawValue: r.typeRaw),
          let start = DayKey(key: r.startKey) else { return nil }
    let reward = (try? JSONDecoder().decode(Reward.self, from: r.rewardData)) ?? Reward(kind: .money)
    return Challenge(id: r.id, name: r.name, colorToken: r.colorToken, metric: metric,
                     target: r.target, type: type, x: r.x, y: r.y, start: start,
                     reward: reward, level: r.level,
                     claimed: r.claimedAt != nil, closed: r.closedAt != nil, archived: r.archivedAt != nil)
}
