# TASK.md — fill. implementation tracker

Source of truth: `docs/SPEC.md` > `docs/DESIGN.md` > `design-mockups/` (photos, portrait iPhone rotated) > `docs/IMPLEMENTATION.md` examples.
`docs/COPY.md` and `prototype/rewards-revamp.html` referenced in docs do NOT exist in repo — copy taken from SPEC body + mockup verbatim. All gaps flagged with [GAP].

Status legend: [ ] todo · [~] in progress · [x] done

## M0: Setup + DesignSystem
- [x] Read AGENTS.md + all docs + all 31 mockups (via subagents, summaries in this file's appendix)
- [x] Create TASK.md (this file)
- [x] Xcode project Fill.xcodeproj (iOS 18, iPhone, portrait, light only), targets Fill + FillTests, Swift 6 strict — builds with ZERO warnings, `test` green (27 Swift Testing tests pass on iPhone 17 simulator + `swift test`). Regenerate via `python3 genproj.py` after adding files (also add to `sources`/`test_sources` + Package.swift untouched — Domain-only).
- [x] Fill/DesignSystem: colors (8 palette + neutrals), fonts, Format helpers, components (ActivityPill, BottomBar, DayBars, FillStepper, Chip, Toast)
- [x] Fill/App: FillApp.swift, AppState, root pager navigation
- [x] Debug menu shell (DEBUG only): +1000 steps, finish, miss-until-OOR, health on/off, replay onboarding, seed demo, advance +1 day
- [ ] Exit: components gallery matches DESIGN §5 in the gallery screen (gallery screen still to add)

## M1: Domain (pure Swift, Foundation only)
- [x] Domain/Types.swift (Metric, ChallengeType, RewardKind/Category, MoneyPayout, ItemPayout, DataSource, DayKey, Reward, Challenge, DayResult) — Codable/Equatable/Sendable, Decimal money
- [x] Domain/Engine.swift — Engine.snapshot per IMPLEMENTATION §4 steps 1-11
- [x] Domain/Derive.swift — perWin, itemSaved, endDate, levelUp, rewardPhrase (a/an), createSentence, createValidation
- [x] Domain/Format.swift — INR en-IN, metric values, dates (5 Nov / ENDS 5 NOV)
- [x] Domain/Copy.swift — copy deck reconstructed from SPEC + mockups [GAP: SPEC §12 missing]
- [x] FillTests Domain tests A01-A33 (name test_<ID>_<short>) — 27 tests pass via `swift test`
- [ ] Exit: A01-A33 pass

## M2: Storage + Pages
- [x] Persistence: SwiftData 6 models (ChallengeRecord, RewardEntry, ManualLog | MetricDay, AppSettings, NotificationLog), two stores, Mapping.swift, Repository upserts + dedupe, operations table
- [x] Seed demo data (9 challenges) [GAP: IMPLEMENTATION §13 missing; reconstructed from ACCEPTANCE P-states + mockups]
- [x] Overview (page 0): header date/Today/gear, Rewards-claimed card, bands per challenge, empty state
- [x] ChallengePage every state (P01-P10) per DESIGN §4 layout
- [x] BottomBar + Pager (page 0 Overview + N pages oldest-first)
- [x] PageBuilder: store rows → DayResults → Engine snapshots + day-bar states wired into pager, overview bands (tap → page), and challenge pages (D01-D10 pass: 10/10)
- [ ] Exit: screenshots match mockups (TODO: simulator screenshot review vs mockups; needs seeded run)

## M3: Create
- [x] Create model: draft + filled blanks, order lock (what → how often → reward) + hint
- [x] Sentence with 3 blanks (dashed / locked dim / white pill), facts row (live ENDS/MISSES/MAX via refreshFacts), name + 8 colors + validation button, 3 panels (per-metric steppers+presets+C13 rings clamp; flex x/y + streak steppers + 7/14/30; money payouts filtered by type + amount/bonus/jar steppers + presets; item name/worth/split or "Add the price"), Start builds real reward → toast
- [x] Create validation unit tests (C01/C09/C10/valid-money/valid-item-save/name-required)
- [ ] Exit: C01-C13 pass (TODO: UI tests for panel flows C02-C08, C12-C13)

## M4: Data + Moments
- [x] Activity: ActivitySource protocol, HealthKitSource (per-metric day values §5.3), MotionSource (steps fallback), ManualSource
- [x] Evaluator (@MainActor, refresh-today, 2s coalesce, fetch/finalize/evaluate/ledger/OOR-stamp/reschedule)
- [x] Day won overlay (2.6s auto-dismiss via AppState.showDayWon), Celebration (claim → Rewarded ✓ → 0.9s → toast; level-up inserts Level n+1), R04 delay 2.3s Day-won→celebration; Rescue card (2-tap scrap); Log today (stepper + chips + honesty note + save-max-rule + Evaluator refresh)
- [x] Evaluator triggers: foreground/scene-active/midnight/tz-change wired in RootView; fresh-today-win detection (new ledger entry) → Day won; done-today → celebration; OOR first-time stamp
- [ ] Exit: H, M, R pass on device (TODO: on-device Health verification; background-delivery observer registration at launch; HealthKit prompt flow)

## M5: Rest of app
- [x] Rewards sheet (Claimed/In-progress toggle, money-only card per W07, category chips, item cards 2-col)
- [x] Onboarding 7 groups/8 screens + roll 2.3s + Skip 2-5→8 + Health + Notifications + You're-set (welcome verified visually in simulator: 2-line headline, roll, chips)
- [x] Notifications: full nudge scheduling (deterministic per-day IDs, removal on win/done/OOR/broken, never sleep, quiet 22–07, 2-per-day cap via NotificationLog with 14-day prune, per-metric bodies incl. steps-minutes + N06/N07 reward lines); shared remainingText helper
- [x] Settings sheet (connect health, log-by-hand, nudge time Stepper 7–21 i.e. 22–07 unselectable per S02, iCloud backup, replay welcome, privacy footer)
- [x] Device readiness: Fill.entitlements (HealthKit + background delivery), real Info.plist (usage strings, BG task id, portrait/iPhone/ITS encryption), privacy manifest in bundle, HealthKitController (auth/background observers, re-registers after grant since pre-auth observers die), BGAppRefresh registration, real Health + notification prompts, H05 rings gating, long-press-Today Debug menu (DEBUG), debug clock honored by Engine/Evaluator, no force-unwraps/prints; arm64 device slice builds clean; bundle verified. Fixed via log-stream triage: HealthKit observer callbacks now post .fillHealthUpdate on MainActor (was background-publish warning ×3 at launch), preset buttons expose their titles to VoiceOver/XCUITest.
- [x] Headless visual verification: FillUITests target + CreateFlowTests (11 screenshots attached to xcresult)
- [ ] Exit: O, N, W, S pass (TODO: UI tests; on-device verification per DEVICE-CHECKLIST below)

## DEVICE-CHECKLIST (for on-device verification)
Run: open Fill.xcodeproj in Xcode → select your Team (Signing & Capabilities; no signing identity exists on this Mac, Xcode will create a profile) → connect iPhone (iOS 18+) → Run on device.
1. O01–O05: fresh install → welcome roll recolors every 2.3s → Get started → Skip jumps to You're set → Make my first challenge opens Create; Explore first → "No challenges yet."
2. H01: onboarding Connect Apple Health → grant → steps appear after walking. H02: deny on a second install → no errors, values 0. M01: "Not now, I'll log by hand" → "✎ by hand" + Log today button.
3. M02/M03: Log today 10,000 → striped bar + "TODAY · WON · BY HAND" + DAY WON overlay. Log 5,000 → "Saved." toast, no win.
4. C-flow: Create a Flexible steps challenge with money-each reward → new page last + toast.
5. R01–R03: Debug menu (long-press "Today") → "Miss days until out of reach" → OUT OF REACH + Extend/Restart/Scrap (scrap needs 2 taps).
6. R04/R05: Debug → "Finish this challenge" → Day won → celebration ~2.3s later → Claim reward → "Rewarded ✓" → toast.
7. Rewards sheet: Claimed/In progress tabs, MONEY REWARDED counts money only (W07).
8. N01/N02: set nudge time in Settings → nudge fires when today unwon; win before nudge time → no nudge. N05: sleep challenge never nudges.
9. S01–S03: gear opens Settings; nudge 22–07 unselectable; Log-by-hand switch flips pages to Log today.
10. H03: walk past goal with app closed → Day won on next open; background refresh keeps history (check after 1+ days).

## M6: Extras
- [ ] iCloud backup switch (rebuild container, additive-only schema, VersionedSchema + MigrationPlan)
- [ ] Widgets (small today-band, medium overview), Live Activity, Log-today App Intent
- [ ] Exit: manual QA §8

## M7: Polish
- [ ] Accessibility (Dynamic Type to AX3, VoiceOver order, Reduce Motion, contrast 4.5:1)
- [ ] Performance (60fps pager), zero warnings Swift 6, no network deps
- [ ] App Store assets, privacy manifest, review notes
- [ ] Exit: AGENTS.md §9 DoD

## Spec gaps / conflicts found
1. SPEC references COPY.md + §12 copy deck — file missing. Reconstructing from SPEC body + mockups. [GAP]
2. SPEC references prototype/rewards-revamp.html — missing; using design-mockups/ instead per user.
3. IMPLEMENTATION §13 seed list missing; §14 exists. Reconstructing 8 seeds: October 10K (F20/30 steps orange), DGX Spark (F70/90 steps green), Run club (F12/30 run mustard), Kyoto streak (S30 violet?), Savings jar (N jar green), Sony A7 (F20/30 exercise purple), Sleep week (S7 sleep teal, claimed), Half marathon?/Omakase (once run 21.1 blue?) — verify against mockup pager counts 9/9.
4. Currency: SPEC §1 says UI INR-only + one USD seed to test W05; mockup Sony A7 shows $2,000/$1,000/$100 — keeping USD only in seed.
5. ACCEPTANCE R numbering skips R09-in-middle (R09 rings-at-3 listed after R06) — keeping IDs as written.
6. DESIGN canvas says open prototype html — using mockups instead.

## Appendix: mockup inventory (portrait, rotate photos 90° CW to view)
- Welcome roll: fill. / Reward yourself to move. / You set the goal. You choose the reward. We keep score. You pay for your rewards. / YOUR GOAL → YOUR REWARD: 10,000 steps a day → ₹10,000 each day (orange), 8 hours of sleep → A spa day (teal), 70 days of 10K steps → A DGX Spark (green) / Get started / ✓No sign-up ✓No account ✓No server
- Onboarding pink: I'll [walk 10,000 steps a day] [on 20 of 30 days] [to win a trip to Taiwan] / You make the deal. / Skip / Next
- Onboarding green trophy: 20 / CLAIMED·CHALLENGE COMPLETE·REWARD ring / Win it. Claim it.
- Onboarding Health: Connect Apple Health / Steps, Activity rings, Exercise minutes, Workouts and distance, Sleep / Connect Apple Health / Not now, I'll log by hand
- Onboarding blue: A nudge before the day ends. / notifications examples / Allow notifications / Not now
- Onboarding black: ✓ / You're set. / Make my first challenge / Explore the demo first
- Create: I'll [what you'll do] [how often] [to win your reward] / MOST YOU CAN WIN – / ENDS – / MISSES ALLOWED – / Name it / 8 colors / Fill in 3 blanks; panels What/How often/Your reward as specced
- Challenge pages: orange October 10K F20/30 (Day13, 9 wins, ENDS 5 NOV, ₹2,00,000, EARNED ₹90,000 NEXT +₹10,000, TODAY·2,158 STEPS TO GO); green DGX Spark F70/90 Day1; mustard Run club F12/30; purple Sony A7 F20/30 exercise; green Savings jar N-jar 86 wins ₹86,000/₹2,00,000; teal Sleep week S7 completed REWARDED; rescue Out-of-reach sheet; celebration Run club gold 12 WINS / Claim reward / Level up·5.5km; DAY WON +₹1,000 green; Log today black pill variant
- Overview Today: Monday 19 October / Rewards claimed 20 / bands per challenge with % OF GOAL
- Rewards: Claimed (MONEY REWARDED ₹90,000, All1/Trips0/Food1/Buy0, Omakase dinner CLAIMED) / In progress (MONEY STILL TO WIN ₹3,34,000, All5/Trips1/Food0/Buy4, Kyoto 60%, DGX 0%, Shoes 67%, Sony 50%)
