# fill. — Database Design

On-device storage for v1. SwiftData, with optional iCloud backup through the CloudKit private database (M6). There is no server. This doc replaces the model sketch that used to be in `IMPLEMENTATION.md` §3.

Read with: `SPEC.md` §6 (rules), §8 (rewards accounting), §11 (edge cases); `IMPLEMENTATION.md` §2 (Domain types, `DayKey`), §6 (Evaluator).

## 1. Principles

1. **Store facts, derive state.** Store only what cannot be recomputed: the challenge's settings, the daily metric values, and the rewards already given. Wins, misses, need, progress, out of reach and "done" are always computed by `Engine.snapshot`. They are never stored.
2. **Health data never leaves the device** (AGENTS §3.2). Values read from HealthKit or Core Motion go only in the local store and are never synced to iCloud. After a restore they are read from HealthKit again.
3. **Days are `DayKey` strings** (`"yyyy-MM-dd"`), never `Date` timestamps (SPEC §11).
4. **Nothing is hard-deleted** except data that can be rebuilt (the metric cache, notification logs). Scrap = archive (SPEC §8).
5. **CloudKit-safe models** in the synced store: every property has a default or is optional, no `@Attribute(.unique)`, no required relationships. The Repository enforces uniqueness (§6).

## 2. Stores

One `ModelContainer` with two `ModelConfiguration`s:

| Store | File | CloudKit | Entities | Why |
| --- | --- | --- | --- | --- |
| Synced | `Fill.store` | `.private("iCloud.<bundle id>")` only when Settings → *Back up to iCloud* is on (M6); else `.none` | `ChallengeRecord`, `RewardEntry`, `ManualLog` | What the user made and earned. Must survive a reinstall. Holds no HealthKit data. |
| Local | `FillLocal.store` | never | `MetricDay`, `AppSettings`, `NotificationLog` | Health/Motion values (privacy), per-device settings, and caches that can be rebuilt. |

```swift
let synced = ModelConfiguration("Synced", schema: Schema([ChallengeRecord.self, RewardEntry.self, ManualLog.self]),
                                url: .applicationSupportDirectory.appending(path: "Fill.store"),
                                cloudKitDatabase: settings.iCloudBackup ? .private("iCloud.<bundle id>") : .none)
let local  = ModelConfiguration("Local", schema: Schema([MetricDay.self, AppSettings.self, NotificationLog.self]),
                                url: .applicationSupportDirectory.appending(path: "FillLocal.store"),
                                cloudKitDatabase: .none)
let container = try ModelContainer(for: FillSchemaV1.self, migrationPlan: FillMigrationPlan.self,
                                   configurations: synced, local)
```

`AppSettings.iCloudBackup` lives in the local store, so it is read before the synced configuration is built. Switching backup on or off rebuilds the container at the next launch. Settings shows `settings.icloud.note` under the switch (SPEC §12.3).

Manual values typed by the user (`ManualLog`) are user input, not HealthKit data, so they may be backed up.

## 3. Entity–relationship overview

```text
SYNCED STORE (iCloud when backup is on)          LOCAL STORE (never leaves the iPhone)

ChallengeRecord —id—< RewardEntry                MetricDay        (metric, dayKey) → value
    │  parentID → ChallengeRecord (level up)      AppSettings      single row
    │  metric ─┐                                 NotificationLog
ManualLog  (metric, dayKey) → value ─── joined at read time by (metric, dayKey) ───► DayResult (Domain)
```

- Links use IDs, not SwiftData relationships. `@Relationship` cannot cross stores, and IDs keep CloudKit merges simple.
- Daily values belong to a metric, not a challenge. Two challenges on `steps` read the same `MetricDay` rows, and each is evaluated on its own (SPEC §11). A manual log for steps therefore counts for every steps challenge (SPEC §7.9).

## 4. Entities

### 4.1 `ChallengeRecord` (synced)

One row per challenge, including archived and completed ones.

| Property | Type | Default | Notes |
| --- | --- | --- | --- |
| `id` | `UUID` | `UUID()` | Stable identity. Used by `RewardEntry.challengeID`, notifications, widgets and App Intents. |
| `name` | `String` | `""` | Can be renamed (v1.1). |
| `colorToken` | `String` | `"orange"` | DESIGN §1.1 token, never a hex value. |
| `metricRaw` | `String` | `"steps"` | `Metric.rawValue` |
| `target` | `Double` | `10_000` | Daily goal. Rings: 1–3. |
| `typeRaw` | `String` | `"flex"` | `ChallengeType.rawValue` |
| `x` | `Int` | `20` | Wins needed (flex/streak); 1 for once; 0 for open. |
| `y` | `Int` | `30` | Window in days (flex). Equal to `x` for streak; 0 for once/open. Increased by **Extend**. |
| `startKey` | `String` | `""` | `DayKey` of day 1. Moved to today by **Restart**. |
| `rewardData` | `Data` | `Data()` | JSON-encoded `Reward` (IMPLEMENTATION §2), including `currency`. A blob keeps the schema stable while reward options change. Rewards are filtered in memory (a user has tens of challenges, not thousands). |
| `rewardSchemaVersion` | `Int` | `1` | Version of the JSON in `rewardData`. Decode older versions with defaults. |
| `level` | `Int` | `1` | |
| `parentID` | `UUID?` | `nil` | The challenge this one levelled up from. |
| `createdAt` | `Date` | `Date()` | Page order in the pager (oldest first). |
| `claimedAt` | `Date?` | `nil` | Set by **Claim reward**. |
| `closedAt` | `Date?` | `nil` | No end + item: **I'm done**. |
| `archivedAt` | `Date?` | `nil` | Scrapped. Hidden from the pager and In progress; its rewards stay in history. |
| `outOfReachNotifiedAt` | `Date?` | `nil` | Makes the `outOfReach` notification fire only the first time (SPEC §10). Cleared by Extend/Restart. |
| `restartCount` | `Int` | `0` | For the toast and for analysis only. |

There is no stored `wins`, `best`, `done` or `money`; they are all derived (§1.1). One time `best` = max of the day values for the metric with `dayKey ≥ startKey` (§7.2).

`Active = archivedAt == nil`. `Completed = Engine.snapshot(...).done`. `Claimed = claimedAt != nil`.

### 4.2 `RewardEntry` (synced): the rewards ledger

One row each time the app records that the user has earned something. This is the history in SPEC §8 and the Rewards sheet's Claimed tab. It is append-only.

| Property | Type | Default | Notes |
| --- | --- | --- | --- |
| `id` | `UUID` | `UUID()` | |
| `challengeID` | `UUID` | — (`UUID()` placeholder) | Owner challenge. |
| `kindRaw` | `String` | `"perWin"` | `perWin` (money each/bonus), `itemSaving` (item save), `final` (written once by Claim reward / I'm done) |
| `dayKey` | `String` | `""` | The won day for `perWin`/`itemSaving`; the claim day for `final`/`bonus`. |
| `amount` | `Decimal` | `0` | Money given by this entry. `itemSaving` uses the last-win remainder from SPEC §5.3. Item `final` entries keep this at 0. |
| `itemValue` | `Decimal` | `0` | Item `final` only: the item's worth (`value`), for display. It is not money and is never added to money totals. |
| `currency` | `String` | `"INR"` | Copied from the reward. Totals are grouped by currency (W05). |
| `isManual` | `Bool` | `false` | The win came from a manual log. |
| `challengeName` | `String` | `""` | Copy taken at write time, so history still reads right after a rename. |
| `colorToken` | `String` | `"orange"` | Copy, for the stacked bar and legend. |
| `itemName` | `String` | `""` | For toward {item} and Enjoy your {name}. |
| `categoryRaw` | `String` | `""` | Item category, for the Trips/Food/Buy chips. |
| `createdAt` | `Date` | `Date()` | |

Natural key: `(challengeID, kindRaw, dayKey)`. Each can exist only once (§6).

What gets written (SPEC §8):

Claiming a challenge always writes exactly one `final` entry, so every claimed challenge is counted once.

| Reward | On each win | `final` on Claim reward |
| --- | --- | --- |
| Money each | `perWin` amount | amount 0 (all of it was already given per win) |
| Money bonus | `perWin` amount | `amount` = bonus only, so nothing is counted twice (W06) |
| Money end | — | `amount` = end amount |
| Money jar | — (wins fill the jar; nothing is given until it opens) | `amount` = jarTarget |
| Item end | — | amount 0, `itemValue` = value |
| Item save | `itemSaving` = per (last win: the remainder) | amount 0, `itemValue` = value (the savings were the money) |
| No end + money each | `perWin` | — (never done, never claimed) |
| No end + item | — | via **I'm done · claim {name}**: amount 0, `itemValue` = value |

Derived numbers:

- Overview **Rewards claimed** = number of `RewardEntry` rows (SPEC §8: rewarded entries + claimed challenges).
- Rewards → **MONEY REWARDED** = sum of `amount` per currency over `perWin` and money `final` entries, archived challenges included. `itemSaving` entries are not included. They are shown only on the item's card and in the challenge footer (SAVED TOWARD IT), per SPEC §7.7. Likewise, MONEY STILL TO WIN excludes items (`Snapshot.moneyLeft` is 0 for item rewards).
- Rewards → **MONEY STILL TO WIN** = sum of `Snapshot.moneyLeft` over active, unclaimed challenges. It comes from the engine, not the ledger.

### 4.3 `MetricDay` (local): daily values from Health / Motion

| Property | Type | Default | Notes |
| --- | --- | --- | --- |
| `metricRaw` | `String` | `"steps"` | |
| `dayKey` | `String` | `""` | |
| `value` | `Double` | `0` | Day value per IMPLEMENTATION §5.3 (for run: the longest single run). |
| `sourceRaw` | `String` | `"health"` | health or motion |
| `isFinal` | `Bool` | `false` | true after 03:00 the next day (SPEC §11). A final row is never changed by Health again. |
| `fetchedAt` | `Date` | `Date()` | |

Key: `(metricRaw, dayKey)`. Index: `#Index<MetricDay>([\.metricRaw, \.dayKey])` (iOS 18; local store only).
Values only ever go up within a day (`max(old, new)`), so a win can never turn back into a miss, and rewards are never taken back.

### 4.4 `ManualLog` (synced): values typed by the user

| Property | Type | Default | Notes |
| --- | --- | --- | --- |
| `metricRaw` | `String` | `"steps"` | |
| `dayKey` | `String` | `""` | Always today when written (SPEC §7.9). |
| `value` | `Double` | `0` | The highest value saved for that day. Log today sets the day's total (it is not added on top), but a lower value never replaces a higher one. This follows the rule that a win never turns back into a miss (§4.3). |
| `updatedAt` | `Date` | `Date()` | |

Key: `(metricRaw, dayKey)`.

### 4.5 `AppSettings` (local, single row)

| Property | Type | Default |
| --- | --- | --- |
| `onboardingDone` | `Bool` | `false` |
| `manualMode` | `Bool` | `false` |
| `notificationsAsked` | `Bool` | `false` |
| `nudgeHour` / `nudgeMinute` | `Int` | `20` / `0` |
| `iCloudBackup` | `Bool` | `false` |
| `lastEvaluatedKey` | `String` | `""` (last DayKey the Evaluator finished, used for backfill) |
| `paletteCursor` | `Int` | `0` (next round-robin color, DESIGN §1.1) |

The Repository makes sure there is always exactly one row: it fetches the first row, or creates one.

### 4.6 `NotificationLog` (local)

| Property | Type | Default | Notes |
| --- | --- | --- | --- |
| `challengeID` | `UUID` | — | |
| `dayKey` | `String` | `""` | |
| `kindRaw` | `String` | `"nudge"` | `nudge`, `dayWon`, `complete`, `outOfReach` |
| `deliveredAt` | `Date` | `Date()` | |

Enforces "max 2 per challenge per day" (SPEC §10). Rows older than 14 days are deleted at launch.

## 5. Read model: from rows to `DayResult`

For a challenge `c` with metric `m`:

```swift
for each dayKey d from c.startKey to today:
    h = MetricDay(m, d)?.value      (Health/Motion)
    u = ManualLog(m, d)?.value      (typed)
    value = max(h ?? 0, u ?? 0)              // SPEC M05: the higher value wins
    source = u != nil && u! >= (h ?? 0) ? .manual   // a manual log decided the day
                                      : MetricDay(m, d)?.source ?? .health
    isFinal = MetricDay(m, d)?.isFinal ?? (d < yesterday)
    → DayResult(date: d, value, source, isFinal)
best (once) = max(value) over the same range
```

Ignore rows whose `dayKey` is after today (SPEC §11, device date moved back). The Domain sees only `DayResult`s; it never sees store rows. Mapping lives in `Persistence/Mapping.swift`.

## 6. Uniqueness and upserts

CloudKit forbids unique constraints, so all writes go through `Repository` upserts:

| Entity | Natural key | On write | On duplicates found (e.g. after a CloudKit merge) |
| --- | --- | --- | --- |
| `ChallengeRecord` | `id` | update in place | keep the row with the latest of (`claimedAt`, `archivedAt`, `createdAt`); delete the rest |
| `RewardEntry` | `(challengeID, kind, dayKey)` | insert only if missing | keep the oldest `createdAt`; delete the rest |
| `ManualLog` | `(metric, dayKey)` | `value = max(old, new)`, set `updatedAt` | keep the max value |
| `MetricDay` | `(metric, dayKey)` | `value = max(old, new)` unless `isFinal` | keep the max value |
| `AppSettings` | single row | update | keep the first row |

Run a dedupe pass at launch and after each `NSPersistentStoreRemoteChange` notification (backup on).

## 7. Operations (what each user action writes)

| Action (SPEC) | Writes |
| --- | --- |
| **Start challenge** (§7.6) | insert `ChallengeRecord` (`startKey` = today, `createdAt` = now, color from `paletteCursor`, then advance it) |
| Health / Motion refresh (IMPLEMENTATION §6) | upsert `MetricDay` for each metric used by an active challenge: from the day after `lastEvaluatedKey` (backfill) through today; update `lastEvaluatedKey` |
| **Log today** (§7.9) | upsert `ManualLog(metric, today)` |
| Day becomes a win (Evaluator event) | insert `RewardEntry` `perWin` / `itemSaving` if the reward has one (§4.2 table) |
| **Claim reward** (§7.5) | set `claimedAt`; insert `final` / `bonus` entry |
| **I'm done · claim** (No end item) | set `closedAt` and `claimedAt`; insert `final` entry |
| **Extend** (§7.8) | `y += n`; clear `outOfReachNotifiedAt` |
| **Restart from today** | `startKey` = today, `restartCount += 1`, clear `claimedAt`, `closedAt`, `outOfReachNotifiedAt`. Ledger kept: old entries have `dayKey` before the new start, so no key clashes. |
| Switch to Flexible | `typeRaw = "flex"`, `y = x + 5`; `startKey` unchanged (existing wins count) |
| **Scrap** | set `archivedAt`. The challenge and its entries stay. |
| **Level up** (§6.8) | insert a new `ChallengeRecord` with `parentID` = old id, `level + 1`, new target, name and color, `startKey` = today. The old row is unchanged. |
| Rename / recolor (v1.1) | update `name` / `colorToken` only. Ledger copies keep their old values on purpose. |
| Settings changes | update `AppSettings` |

Every operation is one `ModelContext.save()`. Ledger inserts and the challenge update for one action are saved together.

## 8. Backup and restore (M6)

- **On:** the synced store mirrors to the CloudKit private database. Nothing goes to any server the app controls.
- **Reinstall with backup:** challenges, ledger and manual logs come back from iCloud. The local store is empty, so the Evaluator backfills `MetricDay` from HealthKit for each active challenge's window (`lastEvaluatedKey` is empty → start from the earliest active `startKey`). Core Motion only keeps 7 days, so older motion-only days come back as 0. The ledger keeps everything already rewarded (ACCEPTANCE §8).
- **Off:** the synced store stays on the device. Turning backup off does not delete the iCloud copy. Removing it is the user's choice in iOS Settings → Apple Account → iCloud.

## 9. Schema versioning

- Define `enum FillSchemaV1: VersionedSchema` with all six models and `enum FillMigrationPlan: SchemaMigrationPlan` from the first build.
- Once CloudKit is on in production, synced-store changes must be **additive only**: new optional or defaulted properties, new entities. Never rename or delete properties. Reward option changes go into `rewardData` JSON plus `rewardSchemaVersion`.
- The local store may change freely (lightweight or custom migration). If it is lost, it is rebuilt from HealthKit.

## 10. Seed and debug data

**Seed demo data** (IMPLEMENTATION §11, §13) writes `ChallengeRecord`s with `startKey`s that put each challenge on the right day, `MetricDay` rows that recreate each history (`S = value ≥ target`, `M = 0`), `RewardEntry` rows for wins already rewarded, and a `claimedAt` + `final` entry for Sleep week. Half marathon's `best` 14.2 is one `MetricDay(run, d, 14.2)` inside its window. Seed data is DEBUG only and is never written to a synced store with backup on.
