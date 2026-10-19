# AGENTS.md — fill. (iOS)

Instructions for coding agents working in this repository. Read this file first, then the docs it points to.

## 1. What we are building

fill. is an iOS app where the user rewards themselves for moving.

- The user sets a goal (for example 10,000 steps a day), a challenge type (for example 20 of 30 days) and a reward (money, a trip, a treat, something to buy).
- The app reads activity from Apple Health (or the user logs it by hand) and keeps score.
- The user pays for their own rewards. The app never moves money.
- No sign-up. No account. No server. All data stays on the device (optional backup to the user's own iCloud).

Working name: `fill.` (not final, trademark not checked).

## 2. Read in this order

| File | What it contains |
| --- | --- |
| `docs/SPEC.md` | Product spec: concepts, rules, every screen, every state, final copy. Source of truth for behaviour and text. |
| `docs/DESIGN.md` | Design tokens, layout measurements, components, motion. Source of truth for look and feel. |
| `docs/IMPLEMENTATION.md` | Architecture, Domain types, engine formulas, HealthKit, notifications, milestones. |
| `docs/DATABASE.md` | Storage: synced vs local stores, entities, keys, rewards ledger, what each action writes, backup, versioning. |
| `docs/ACCEPTANCE.md` | Test scenarios. Every one must pass before a milestone is done. |

If two sources disagree: `SPEC.md` > `DESIGN.md` > prototype > `IMPLEMENTATION.md` examples. Report the conflict in your PR description. Differences already known are listed in `IMPLEMENTATION.md` §14; do not copy those from the prototype.

## 3. Non-negotiable rules

1. No network calls for app features. No backend, no auth, no third-party analytics or crash SDKs in v1. The only allowed network use is Apple frameworks (CloudKit private database, StoreKit if added later).
2. Health data never leaves the device and is never written to HealthKit (read only). Health values live only in the local store; iCloud backup never includes them (DATABASE §2).
3. No money handling. The app only records rewards. Never add payment, wallet or bank features.
4. Use the exact copy from `SPEC.md` §12 Copy deck (including §12.1–12.3). Do not invent user-facing text. If a string is missing, add it to the copy deck in the same PR and flag it. Strings in §12.3 are proposals that still need product review.
5. Domain logic is pure Swift (no SwiftUI, no HealthKit imports) and is fully unit tested.
6. A "day" is the user's local calendar day (`Calendar.current`, midnight to midnight, current time zone). Store and compare days as `DayKey` calendar dates, never as `Date` timestamps (IMPLEMENTATION §2, SPEC §11).
7. Do not show errors when Health returns no data. iOS hides refused permission; treat "no data" as "no data yet" (see SPEC §9).
8. Accessibility is required: Dynamic Type, VoiceOver labels on every control, Reduce Motion respected, contrast ≥ 4.5:1 for body text.

## 4. Tech stack

- Swift 6 (strict concurrency on), SwiftUI, Observation (`@Observable`)
- SwiftData for persistence: a synced store plus a local store (CloudKit-compatible model rules, see DATABASE.md)
- HealthKit, Core Motion (`CMPedometer`) fallback
- UserNotifications (local only), BackgroundTasks
- WidgetKit, ActivityKit, App Intents (milestone M6)
- Swift Testing (unit), XCTest (UI)
- Minimum iOS: 18.0. iPhone only for v1. Portrait only.

No third-party packages without written approval in the PR.

## 5. Repository layout

```text
Fill/
├── App/                  FillApp.swift, AppState, root navigation
├── Features/
│   ├── Onboarding/
│   ├── Pager/            Overview + ChallengePage
│   ├── Create/
│   ├── Rewards/
│   ├── LogToday/
│   ├── Celebration/
│   └── Rescue/
├── Domain/               Pure Swift: models, Engine, rules (no UI/HealthKit imports)
├── Activity/             ActivitySource protocol + HealthKit / Motion / Manual sources
├── Persistence/          SwiftData models, Repository (upserts), mapping to Domain (DATABASE.md)
├── Engagement/           Notifications, background refresh
├── DesignSystem/         Colors, fonts, components (Fill, Ribbon, GoalLine, TodayBand, Pill…)
├── Resources/            Localizable.xcstrings, Assets, PrivacyInfo.xcprivacy
├── FillTests/            Domain unit tests (Swift Testing)
├── FillUITests/          Flow tests
└── FillWidgets/          (M6)
```

## 6. Commands

```sh
# build
xcodebuild -scheme Fill -destination 'platform=iOS Simulator,name=iPhone 16' build
# unit + UI tests
xcodebuild -scheme Fill -destination 'platform=iOS Simulator,name=iPhone 16' test
# lint/format (if configured)
swift format lint --recursive Fill FillTests
```

HealthKit does not have real data in the Simulator. Use the Debug menu (IMPLEMENTATION §11) to inject steps, misses and completions, the same as the prototype's demo buttons.

## 7. Coding conventions

- One feature per folder. Views are small; logic lives in `Domain/Engine` or a feature `@Observable` model.
- No force unwraps outside tests. No `print` in committed code (use `Logger`).
- All numbers shown to the user go through `Format` helpers (`Format.money`, `Format.metric`), en-IN grouping for INR (₹1,00,000).
- Colors and fonts only from `DesignSystem`. No hex values in feature code.
- Every new rule in `Domain` gets a test named after the scenario in `ACCEPTANCE.md` (for example `test_A07_flexWinDoesNotTriggerOutOfReach`).
- Keep SwiftData models CloudKit-safe: every property optional or with a default, no `@Attribute(.unique)`. Synced-store changes are additive only (DATABASE §9). Write only through `Repository` upserts (DATABASE §6).

## 8. How to work

1. Pick the next milestone in `IMPLEMENTATION.md` §12. Do not start the next one before its acceptance tests pass.
2. Write/extend Domain tests first, then the engine, then UI.
3. Compare each screen against the prototype at iPhone 16 size (393×852 pt).
4. In the PR: list the acceptance IDs covered, screenshots of each new state, and any spec gaps you found.

## 9. Definition of done (per PR)

- [ ] Builds with zero warnings under Swift 6 strict concurrency
- [ ] Unit tests for every new rule; all tests green
- [ ] Matches SPEC copy and DESIGN measurements (±2 pt)
- [ ] VoiceOver labels, Dynamic Type up to AX3 without clipping critical numbers
- [ ] Reduce Motion: no looping/pulsing animations; fills change without animation
- [ ] No network access added; no new third-party dependency
- [ ] Acceptance IDs listed in the PR

## 10. Things to NOT do

- Do not add sign-in, accounts, onboarding email capture, or remote config.
- Do not write to HealthKit.
- Do not show "You owe" or debt language. Rewards are **Rewarded** or **Claimed** (SPEC §8).
- Do not reintroduce the currency picker or suggested-item chips in Create (removed on purpose).
- Do not use the word "goal" for a challenge. "Challenge" = the whole deal; "goal" = the daily target (SPEC §2).
