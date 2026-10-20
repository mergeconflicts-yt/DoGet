# TASK.md — fill. implementation tracker

Source of truth: `docs/SPEC.md` > `docs/COPY.md` > `docs/DESIGN.md` > `design-mockups/` (photos, portrait iPhone rotated) > `docs/IMPLEMENTATION.md` examples.
`prototype/rewards-revamp.html` referenced in docs does NOT exist in the repo — visual checks use `design-mockups/` instead.
`docs/COPY.md` was also missing. It now exists as a **reconstructed** deck (SPEC body + ACCEPTANCE + mockups); invented lines are marked `[proposal]` / `[gap]` and still need product review.

Status legend: [ ] todo · [~] in progress · [x] done · [!] blocked on missing source

**Honest status (20 Oct 2026):** code builds and unit/persistence tests are green, but **no milestone exit criterion is fully met yet**. The gaps are visual verification against the mockups, on-device HealthKit/background checks, the remaining Create UI tests, and accessibility verification at AX3. `review.txt` issues are fixed except where noted below.

## M0: Setup + DesignSystem
- [x] Read AGENTS.md + all docs + all 31 mockups (via subagents, summaries in this file's appendix)
- [x] Create TASK.md (this file)
- [x] Xcode project Fill.xcodeproj (iOS 18, iPhone, portrait, light only), targets Fill + FillTests + FillPersistenceTests + FillUITests, Swift 6 strict — app builds with zero code warnings; `swift test` 45 Domain + 15 Persistence tests green; simulator `xcodebuild test` covers the UI flows. Regenerate via `python3 genproj.py` after adding files (also add to `sources`/`test_sources`/`ui_test_sources`).
- [x] Fill/DesignSystem: colors (8 palette + neutrals), fonts, Format helpers, components (ActivityPill, BottomBar, DayBars, FillStepper, Chip, Toast)
- [x] Fill/App: FillApp.swift, AppState, root pager navigation
- [x] Debug menu (DEBUG only): +1000 steps, finish, miss-until-OOR, health on/off, replay onboarding, seed demo, advance +1 day — the two former stubs now write data and refresh the UI
- [ ] Exit: components gallery matches DESIGN §5 in the gallery screen (gallery screen still to add)

## M1: Domain (pure Swift, Foundation only)
- [x] Domain/Types.swift (Metric, ChallengeType, RewardKind/Category, MoneyPayout, ItemPayout, DataSource, DayKey, Reward, Challenge, DayResult) — Codable/Equatable/Sendable, Decimal money; `DayKey` no longer force-unwraps
- [x] Domain/Engine.swift — Engine.snapshot per IMPLEMENTATION §4 steps 1-11; One-time includes today; savings cap; free of force unwraps
- [x] Domain/Derive.swift — perWin, itemSaved (capped at value), endDate, levelUp, rewardPhrase (a/an/“a treat”), createSentence, createValidation (reward checked second)
- [x] Domain/Format.swift — INR en-IN, metric values, dates (5 Nov / ENDS 5 NOV)
- [x] Domain/Copy.swift — reconstructed deck, `docs/COPY.md`; invented lines marked [proposal]
- [x] Domain/CreateDraft.swift — pure `CreateLogic` (Foundation only, no Observation); `CreateModel.swift` is the `@Observable` UI wrapper
- [x] FillTests Domain tests A01-A33 (name test_<ID>_<short>) — 45 tests pass via `swift test`; A25-A27 in FillPersistenceTests; A13 now goes through the engine
- [x] Exit: A01-A33 pass (verified locally: 45 Domain + 15 Persistence tests green)

## M2: Storage + Pages
- [x] Persistence: SwiftData 6 models (ChallengeRecord, RewardEntry, ManualLog | MetricDay, AppSettings, NotificationLog), two stores, Mapping.swift, Repository upserts + dedupe (now covers ChallengeRecord and ManualLog), `markFinal`, parent links; persistence tests D01-D11 green
- [x] Seed demo data (9 challenges) [GAP: IMPLEMENTATION §13 missing; reconstructed from ACCEPTANCE P-states + mockups]
- [x] Overview (page 0): header date/Today/gear, Rewards-claimed card, bands per challenge with subtitles and total, empty state
- [x] ChallengePage every state (P01-P10) per DESIGN §4 layout; 420 pt hero threshold; BY HAND and Rewarded beside the pill; corrected rule/hero/goal/footer copy; no share sheet
- [x] BottomBar + Pager (page 0 Overview + N pages oldest-first)
- [x] `EvaluationEngine` in Persistence is the single evaluator core; `PageBuilder` delegates to it (D07, D10 through the real evaluator)
- [ ] Exit: screenshots match mockups (TODO: seeded simulator screenshot review vs mockups; prototype HTML is missing)

## M3: Create
- [x] Create model: pure `CreateLogic` + `@Observable CreateModel`; draft + filled blanks, order lock (what → how often → reward) + hints
- [x] Sentence with 3 blanks (dashed / locked dim / white pill), facts row (live ENDS/MISSES/MAX via refreshFacts), name + 8 colors + validation button, 3 panels (per-metric steppers+presets+C13 rings clamp; flex x/y + streak steppers + 7/14/30; money payouts filtered by type + amount/bonus/jar steppers + presets; item name/worth/split or “Add the price”), Start builds real reward → toast
- [x] Copy pass: “every day, no end”, “exercise for 30 minutes”, food/other placeholders, panel labels/hints, challenge name and item name stay independent
- [x] Type switch clears inapplicable counts: No-end/One-time have no x/y, No-end each shows “—” (no maximum), and end-only rewards reset to “All at the end”
- [x] Create validation unit tests (C01/C09/C10/valid-money/valid-item-save/name-required/reward-before-target)
- [ ] Exit: C01-C13 pass (TODO: UI tests for panel flows C05-C08, C11-C13; only C02-C04 are driven in `CreateFlowTests`)

## M4: Data + Moments
- [x] Activity: ActivitySource protocol, HealthKitSource (per-metric day values §5.3), MotionSource (steps fallback), ManualSource
- [x] Evaluator core in `Fill/Persistence/EvaluationEngine.swift`: persists fetched days, re-fetches from min(lastEvaluated+1, yesterday) through today, marks past days final before fetching, backfills ledger using each win’s win number, detects done/OOR, caps per-win money at the window, handles manual logs
- [x] Evaluator wrapper in Engagement: 2s coalescing that merges (does not drop), foreground/scene-active/midnight/tz-change, background task now runs the evaluator, observers registered in App init, HealthKit completion called after the evaluator
- [x] Day won and celebration fire for every reward/type (per-win, end, jar, item-end, One time), not just per-win
- [x] Day won overlay (2.6s auto-dismiss via AppState.showDayWon), Celebration (claim guard; claim → Rewarded ✓ → 0.9s → toast; level-up inserts Level n+1), R04 delay 2.3s Day-won→celebration; Rescue card (2-tap scrap, resets); Log today button (stepper + chips + honesty note + save-max-rule + Evaluator refresh)
- [x] Notifications: nudges only before today’s time, removed on win/done/OOR/broken/scrap, currency-aware money; day-won/completion/out-of-reach notifications
- [ ] Exit: H, M, R pass on device (TODO: on-device Health verification; background delivery; HealthKit prompt flow; only unit/persistence + simulator checks done)

## M5: Rest of app
- [x] Rewards sheet **removed** (SPEC has no rewards screen; review W* no longer applies). Rewards stay visible through each challenge page/footer and the Overview “Rewards claimed” count.
- [x] Onboarding **replaced** per `onboarding.txt` + `welcome-onboarding/` prototype + `brand/` (old 8-screen fill. flow scrapped): 5 Wonday screens — Welcome (looping demo card, 6 goals, recolor), Walk to unlock (2.3s hold demo, no Health/save), Apple Health (read-only, silent denial), Notifications (lock preview, ask-again-later), You're set (ring/disc/check, real first challenge). Slide transitions, confetti/shake/haptics, Reduce Motion paths, replay from Settings. `FillUITests/OnboardingTests` (welcome→make-own, walk-unlock→start) green.
- [x] Notifications: full nudge scheduling (deterministic per-day IDs, removal on win/done/OOR/broken/scrap, never sleep, quiet 22–07, 2-per-day cap via NotificationLog with 14-day prune, per-metric bodies incl. steps-minutes + N06/N07 reward lines)
- [x] Settings sheet (connect health, log-by-hand, nudge time Stepper 7–21 i.e. 22–07 unselectable per S02, iCloud backup flag, replay welcome, privacy footer)
- [x] Device readiness: Fill.entitlements (HealthKit + background delivery), real Info.plist (usage strings, BG task id, portrait/iPhone/ITS encryption), privacy manifest in bundle, HealthKitController (auth/background observers, re-registers after grant since pre-auth observers die), BGAppRefresh registration, real Health + notification prompts, H05 rings gating, long-press-Today Debug menu (DEBUG), debug clock honored by Engine/Evaluator, no force-unwraps/prints; arm64 device slice builds clean; bundle verified.
- [x] Headless checks: FillUITests target + CreateFlowTests/GelFillTests/RescueTests/OnboardingTests (screenshots and flow assertions attached to xcresult)
- [ ] Exit: O, N, S pass. Fresh-install onboarding is exercised by `OnboardingTests` (both paths) + `CreateFlowTests`; N/S UI tests and on-device verification are still TODO (see DEVICE-CHECKLIST below). Every in-app "wonday" uses the ¾ ring (`WondayWordmark`/`WondayWord` via `WondayFlow`, gap centred on top like `wonday-wordmark-transparent.png`); system strings (Info.plist prompts, notifications, Home Screen name) stay plain per the brief.

## DEVICE-CHECKLIST (for on-device verification)
Run: open Fill.xcodeproj in Xcode → select your Team (Signing & Capabilities; no signing identity exists on this Mac, Xcode will create a profile) → connect iPhone (iOS 18+) → Run on device.
1. O01–O05: fresh install → welcome roll recolors every 2.3s → Get started → Skip jumps to You're set → Make my first challenge opens Create; Explore first → "No challenges yet."
2. H01: onboarding Connect Apple Health → grant → steps appear after walking. H02: deny on a second install → no errors, values 0. M01: "Not now, I'll log by hand" → "✎ by hand" + Log today button.
3. M02/M03: Log today 10,000 → striped bar + "TODAY · WON · BY HAND" + DAY WON overlay. Log 5,000 → "Saved." toast, no win.
4. C-flow: Create a Flexible steps challenge with money-each reward → new page last + toast.
5. R01–R03: Debug menu (long-press "Today") → "Miss days until out of reach" → OUT OF REACH + Extend/Restart/Scrap (scrap needs 2 taps).
6. R04/R05: Debug → "Finish this challenge" → Day won → celebration ~2.3s later → Claim reward → "Rewarded ✓" → toast.
7. W*: not applicable — the Rewards sheet was removed. Check “Rewards claimed” on Overview and the reward/EARNED footer instead.
8. N01/N02: set nudge time in Settings → nudge fires when today unwon; win before nudge time → no nudge. N05: sleep challenge never nudges.
9. S01–S03: gear opens Settings; nudge 22–07 unselectable; Log-by-hand switch flips pages to Log today.
10. H03: walk past goal with app closed → Day won on next open; background refresh keeps history (check after 1+ days).

## M6: Extras
- [~] iCloud backup: the Settings switch persists `iCloudBackup` only; no CloudKit container, VersionedSchema or MigrationPlan yet
- [ ] Widgets (small today-band, medium overview), Live Activity, Log-today App Intent
- [ ] Exit: manual QA §8

## M7: Polish
- [~] Accessibility: `FillFont.scaled` via UIFontMetrics (capped at 2×) across UI, VoiceOver labels on controls, Reduce Motion paths for onboarding/GelFill/celebration. **Not yet verified at AX3**, and contrast has not been measured.
- [x] Manual wins use striped bars; GelFill wave flattened under today band/done; colors outside DesignSystem replaced (`FillColor.confettiYellow`, `FillColor.shadow`, `FillColor.ink`, `FillColor.surface`). Remaining `.white` is the on-color for text/fills over challenge colors.
- [ ] Verify color contrast ≥ 4.5:1 and VoiceOver order on device
- [x] Zero code warnings under Swift 6 (the only remaining warning is Xcode’s `appintentsmetadataprocessor` metadata note); no network deps
- [ ] Performance (60fps pager)
- [ ] App Store assets, privacy manifest, review notes
- [ ] Exit: AGENTS.md §9 DoD

## Spec gaps / conflicts found
1. SPEC references COPY.md + §12 copy deck — the original was missing. `docs/COPY.md` is now reconstructed from SPEC body + ACCEPTANCE + mockups; every invented line is marked `[proposal]`/`[gap]` and needs product review.
2. SPEC references prototype/rewards-revamp.html — still missing; using design-mockups/ instead per user. Visual parity is therefore unverified.
2b. `DATABASE.md` §2 stores `iCloudBackup` in `AppSettings`; `review.txt` says it should be `UserDefaults`. DATABASE is the storage source of truth, so the flag stays in `AppSettings` until the docs agree. Flagged here.
2c. `DESIGN.md` §5 specifies the GelFill press dent; SPEC does not. Kept. Share cards/ShareLink were removed because no SPEC/COPY source exists for their strings.
2d. W* acceptance scenarios no longer apply: the Rewards sheet they test was removed (also noted in review §6).
3. IMPLEMENTATION §13 seed list missing; §14 exists. Reconstructed 9 seeds (`Fill/Persistence/Seed.swift`): October 10K (F20/30 steps orange), DGX Spark (F70/90 steps green), Run club (F12/30 run amber), Kyoto streak (S30 rings violet), Savings jar (N jar green), Sony A7 (F20/30 exercise blue, USD), Sleep week (S7 sleep teal, Omakase reward), Half marathon (once run 21.1 blue), Shoes (F12/30 steps pink) — names/order match the mockup pager count 9/9; colours and offsets are reconstructed and still need a visual check.
4. Currency: SPEC §1 says UI INR-only + one USD seed to test W05; mockup Sony A7 shows $2,000/$1,000/$100 — keeping USD only in seed.
5. ACCEPTANCE R numbering skips R09-in-middle (R09 rings-at-3 listed after R06) — keeping IDs as written.
6. DESIGN canvas says open prototype html — using mockups instead.

## Appendix: mockup inventory (portrait, rotate photos 90° CW to view)
- Welcome roll: fill. / Reward yourself to move. / You set the goal. You choose the reward. We keep score. You pay for your rewards. / YOUR GOAL → YOUR REWARD: 10,000 steps a day → ₹10,000 each day (orange), 8 hours of sleep → A spa day (teal), 70 days of 10K steps → A DGX Spark (green) / Get started / ✓No sign-up ✓No account ✓No server
- Onboarding pink: I'll [walk 10,000 steps a day] [on 20 of 30 days] [to win a trip to Taiwan] / You make the deal. / Skip / Next
- Onboarding green trophy: 20 / CLAIMED·CHALLENGE COMPLETE·REWARD ring / Win it. Claim it.
- Onboarding Health: Connect Apple Health / Steps, Activity rings, Exercise minutes, Workouts and distance, Sleep / Connect Apple Health / Not now, I'll log by hand
- Onboarding blue: A nudge before the day ends. / notifications examples / Allow notifications / Not now
- Onboarding black: ✓ / You're set. / Make my first challenge / Explore first
- Create: I'll [what you'll do] [how often] [to win your reward] / MOST YOU CAN WIN – / ENDS – / MISSES ALLOWED – / Name it / 8 colors / Fill in 3 blanks; panels What/How often/Your reward as specced
- Challenge pages: orange October 10K F20/30 (Day13, 9 wins, ENDS 5 NOV, ₹2,00,000, EARNED ₹90,000 NEXT +₹10,000, TODAY·2,158 STEPS TO GO); green DGX Spark F70/90 Day1; mustard Run club F12/30; purple Sony A7 F20/30 exercise; green Savings jar N-jar 86 wins ₹86,000/₹2,00,000; teal Sleep week S7 completed REWARDED; rescue Out-of-reach sheet; celebration Run club gold 12 WINS / Claim reward / Level up·5.5km; DAY WON +₹1,000 green; Log today black pill variant
- Overview Today: Monday 19 October / Rewards claimed 20 / bands per challenge with % OF GOAL
- Rewards: Claimed (MONEY REWARDED ₹90,000, All1/Trips0/Food1/Buy0, Omakase dinner CLAIMED) / In progress (MONEY STILL TO WIN ₹3,34,000, All5/Trips1/Food0/Buy4, Kyoto 60%, DGX 0%, Shoes 67%, Sony 50%)
