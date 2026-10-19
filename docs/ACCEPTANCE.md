# fill. — Acceptance Scenarios

Each ID maps to at least one automated test (unit for A\*, UI or unit for the rest). Name tests `test_<ID>_<shortName>`.
"Today" = 19 Oct 2026 unless stated; locale en-IN; currency INR.

Notation: `F(x/y)` flexible x of y days · `S(x)` streak · `O` once · `N` no end · `d` = day number (1-based) · `W/M` = wins/misses so far.

## 1. Engine (A01–A30) — unit tests

| ID | Given | When | Then |
| --- | --- | --- | --- |
| A01 | F(20/30) steps 10,000, d13, W9 M3, today 7,842 | snapshot | need 11, daysLeft 18, missesAllowed 7, base 0.45, layer ≈ 0.0392, outOfReach false |
| A02 | A01 | today = 10,000 | todayWon, W10, need 10, daysLeft 17, layer 0 |
| A03 | A01 | today = 9,999 | not won (≥ target required) |
| A04 | F(20/30) d1, W0, today 0 | snapshot | need 20, daysLeft 30, base 0, layer 0, first-win state |
| A05 | F(20/30) d21 (start 29 Sep, ends 28 Oct), W9 M11, today < target | snapshot | daysLeft 10, need 11 → outOfReach, extendBy 1 |
| A06 | A05 | extend by 1 | y = 31, outOfReach false, endDate 29 Oct |
| A07 | F(20/30) d29, W18, today won | snapshot | W19, need 1, daysLeft 1, **outOfReach false** |
| A08 | F(20/30) d30, W19, today won | snapshot | W20 → done, base 1 |
| A09 | S(30) d19, W18 all consecutive, today 2/3 rings | snapshot | need 12, not broken, endDate 30 Oct |
| A10 | S(30) with one miss on d5 | snapshot | broken, streakBrokenOnDay 5, layer 0 |
| A11 | A10 | switch to flex | type F(30/35), wins kept, broken false |
| A12 | O run 21.1, best 14.2 | snapshot | base ≈ 0.673, layer 0, not done |
| A13 | A12 | today 21.1 | best 21.1, done |
| A14 | N jar ₹1,000 → ₹2,00,000, 86 wins | snapshot | base 0.43, moneyLeft ₹2,00,000 (until claimed) |
| A15 | N jar, 199 wins, today won | snapshot | 200 wins → done |
| A16 | N money each ₹1,000, 6 wins | snapshot | earned ₹6,000, moneyLeft 0, never done |
| A17 | N item "Bike" | closedAt set | done |
| A18 | F(20/30) money each ₹10,000, W9 | money | earned ₹90,000, left ₹1,10,000 |
| A19 | F(20/30) money bonus ₹1,000 + ₹10,000, done, not claimed | money | earned ₹20,000, left ₹10,000 |
| A20 | A19 claimed | money | earned ₹30,000, left 0 |
| A21 | F(20/30) money end ₹50,000, W2 | money | earned 0, left ₹50,000; footer "REWARD AT THE END" |
| A22 | F(70/90) item value ₹7,00,000 save | perWin | ₹10,000 |
| A23 | item value ₹5,00,000, x 30, save | perWin / itemSaved | perWin ₹16,667 (rounded); saved after 29 wins ₹4,83,343; 30th win saves ₹16,657; saved after 30 wins exactly ₹5,00,000 |
| A24 | dayIndex | user wins today | dayIndex unchanged (calendar only) |
| A25 | F(20/30) started 15 Oct; day records 15–19 Oct stored in UTC+5:30. At 22:00 on 19 Oct (UTC+5:30) device moves to UTC+8 (00:30, 20 Oct) | evaluate | today = 20 Oct, dayIndex 5; records 15–19 Oct still matched (wins unchanged); one new record for 20 Oct; no duplicates |
| A26 | Watch syncs 1,200 steps at 01:30 for yesterday (was 9,000) | evaluate | yesterday becomes win (within 03:00 grace) |
| A27 | same at 04:00 | evaluate | yesterday unchanged (final) |
| A28 | level up steps 10,000 | levelUp | 11,000, name "... · Level 2", wins 0, claimed nil |
| A29 | level up rings 2 | levelUp | 3 |
| A30 | level up run 5.0 | levelUp | 5.5 |
| A31 | level up rings 3 | levelUp | nil (not offered) |
| A32 | 20 Oct record exists; device moves west UTC+8 → UTC+5:30 so the local date goes back to 19 Oct | evaluate | 19 Oct record updated, not duplicated; 20 Oct record ignored as future-dated until that date comes |
| A33 | DayKey | adding / days(to:) across a DST change (e.g. Europe/London, 25 Oct 2026) | whole-day results, same as in UTC |

## 2. Create (C01–C12)

| ID | Scenario | Expected |
| --- | --- | --- |
| C01 | Open Create | 3 blanks; only "what you'll do" active/pulsing; button "Fill in 3 blanks"; facts show "—" |
| C02 | Tap "your reward" first | panel does not open; hint `First set "what you'll do".`; required blank shakes |
| C03 | Fill act → Done | blank becomes pill "walk 10,000 steps" + " a day"; rule panel opens automatically |
| C04 | Rule Flexible 70 of 90 → Done | pill "on 70 of 90 days"; facts Ends 16 Jan, Misses allowed 20; reward panel opens |
| C05 | Reward Buy "DGX Spark", worth 7,00,000 | buttons "All at the end · ₹7,00,000 when you finish" and "₹10,000 each win · 70 wins × ₹10,000" |
| C06 | Pick split → Done | pill "a DGX Spark worth ₹7,00,000, ₹10,000 a win"; button "Start challenge" |
| C07 | Reward Trip "Taiwan" 5,00,000 + streak 30 | pill "a trip to Taiwan worth ₹5,00,000" |
| C08 | Item name starts with vowel "iPad" | "an iPad" |
| C09 | Flexible x=25, y=20 | button "Wins must fit in the days" |
| C10 | Money + No end | payout options only Each win, Jar; Jar target ≤ amount → "Jar must be bigger" |
| C11 | Money + One time | only "One reward" |
| C12 | Start | new page appears last, pager scrolls to it, toast shown, Overview band added |
| C13 | Metric Close rings | stepper max 3, + disabled at 3, typed value > 3 clamps to 3 |

## 3. Challenge page states (P01–P10) — snapshot/UI tests with seed data

| ID | State | Must show |
| --- | --- | --- |
| P01 | New (A04) | first-win card, "0 of 20 wins", "20 wins to go in 30 days", today pill above floor |
| P02 | In progress (A01) | pill "10,000 STEPS", "Day 13 of 30", rule "Flexible · 20 of 30 days", bars 9 won/3 missed/today, goal line "₹2,00,000 · ENDS 5 NOV", hero "9 of 20 wins / 11 wins to go in 18 days", today band + "TODAY · 2,158 STEPS TO GO", footer Earned ₹90,000 · Next win +₹10,000 |
| P03 | Today won (A02) | "TODAY · WON", hero "10 of 20", no band |
| P04 | Out of reach (A05) | red pill OUT OF REACH, fill desaturated, rescue card, no today pill |
| P05 | Streak broken (A10) | red pill STREAK BROKEN, rescue with switch option |
| P06 | Completed unclaimed | pill COMPLETED, goal fill 100%, "See your trophy" |
| P07 | Claimed | pill REWARDED, right text "Rewarded" |
| P08 | Once (A12) | no bars, "14.2 of 21.1 km", "6.9 km to go in one run" |
| P09 | Jar (A14) | "₹86,000 of ₹2,00,000", "₹1,14,000 to go in 114 wins", goal "₹2,00,000 · JAR OPENS" |
| P10 | No end item | footer button "I'm done · claim {name}" |

## 4. Health & manual (H01–H05, M01–M05)

| ID | Scenario | Expected |
| --- | --- | --- |
| H01 | Grant Health on onboarding | steps for today appear within one evaluation |
| H02 | Deny Health | no error UI; values 0; app still usable |
| H03 | Background: steps cross 10,000 while app closed | dayWon notification within the next background delivery; page shows win on open |
| H04 | Run metric | uses the longest single running workout of the day |
| H05 | No Apple Watch (no stand data 7 days) | Rings chip disabled "Needs Apple Watch" |
| M01 | "Not now, I'll log by hand" | manualMode on; pages show "✎ by hand" and the Log today button |
| M02 | Log 10,000 | win flagged manual; striped bar; "TODAY · WON · BY HAND"; Day won overlay |
| M03 | Log 5,000 | saved, no win, toast "Saved." |
| M04 | "Connect Apple Health instead" | Health prompt/settings path; manualMode off on success |
| M05 | Health value later lower than manual | higher value is kept |

## 5. Rescue, celebration, level up (R01–R08)

| ID | Scenario | Expected |
| --- | --- | --- |
| R01 | Extend (A05) | button "Extend by 1 day · ends 29 Oct"; toast "Extended by 1 day. Ends 29 Oct." (singular/plural via String Catalog plural rules) |
| R02 | Restart | start = today, wins reset, history kept in Rewards |
| R03 | Scrap | first tap → "Tap again to scrap"; second tap archives; rewarded history kept |
| R04 | Final win | Day won overlay, then celebration after 2.3 s |
| R05 | Claim | button → "Rewarded ✓", closes after 0.9 s, toast, page REWARDED |
| R06 | Level up | new page "... · Level 2", next color, target per A28–A30, toast "Level 2 started: 11,000 steps." |
| R09 | Rings at 3 complete | celebration has Claim reward only, no Level up |
| R07 | No end item claim | celebration shown; no Level up button |
| R08 | Reduce Motion on | no confetti, no pulsing, fills jump |

## 6. Rewards sheet (W01–W06)

| ID | Scenario | Expected |
| --- | --- | --- |
| W01 | Claimed tab with seed data | hero "MONEY REWARDED ₹90,000", chips All/Trips/Food/Buy with counts, Omakase card stamped CLAIMED |
| W02 | In progress tab | hero "MONEY STILL TO WIN" sum, cards filled to % (Kyoto 60%, Sony A7 50%, Shoes 67%, DGX Spark 0%) |
| W03 | Tap money hero | list by challenge with ₹ rewarded / to win |
| W04 | Tap a card | sheet closes, pager goes to that challenge |
| W05 | Mixed currencies | totals shown per currency, joined with " · " |
| W06 | Bonus claimed | trophy row shows "₹10,000 bonus" only (no double count) |
| W07 | DGX Spark (item save) has 3 wins = ₹30,000 saved | MONEY REWARDED and MONEY STILL TO WIN unchanged by it; DGX Spark card and footer show SAVED TOWARD IT ₹30,000 |

## 7. Onboarding & notifications (O01–O06, N01–N04)

| ID | Scenario | Expected |
| --- | --- | --- |
| O01 | First launch | Welcome shows; headline exactly 2 lines; roll advances every 2.3 s and recolors |
| O02 | Skip on screens 2–5 | jumps to "You're set" |
| O03 | Finish onboarding | never shown again; Settings → Replay works |
| O04 | Make my first challenge | Create opens |
| O05 | Explore first with no challenges | Overview empty state |
| O06 | Dynamic Type AX3 | no clipped titles; welcome headline may scale down to fit 2 lines |
| N01 | 20:00, today not won, reachable | one nudge per challenge with correct numbers |
| N02 | Today won before 20:00 | nudge removed |
| N03 | 22:30 win | no notification until 07:00 |
| N04 | 3 events same day | max 2 delivered per challenge |
| N05 | Sleep challenge, 20:00 | no nudge |
| N06 | Run 5 km, today 0, money each ₹2,000 | nudge "Run club · 5 km to go" / "One 5 km run wins ₹2,000 today." |
| N07 | Steps, item end reward, 2,158 left | body "A 25-minute walk wins the day." (reward not named) |

## 6a. Persistence (D01–D10): unit tests against an in-memory `ModelContainer`, DATABASE.md

| ID | Scenario | Expected |
| --- | --- | --- |
| D01 | Two active challenges on `steps`; Health gives 9,000 for today | one `MetricDay(steps, today)`; both snapshots see 9,000 |
| D02 | Log today 6,000 steps, then 10,000, then 7,000 the same day | one `ManualLog`; value 10,000 (totals, not added; never lowered); the day stays a win |
| D03 | F(20/30) money each ₹10,000: today becomes a win; Evaluator runs 3 more times | exactly one `RewardEntry(perWin, today, ₹10,000)` |
| D04 | Challenge with 5 rewarded wins → Restart from today | `startKey` = today, snapshot wins 0; 5 entries still in the ledger; Claimed tab total unchanged |
| D05 | Scrap a challenge with rewarded wins | `archivedAt` set; not in pager or in progress; its entries still counted in Rewards claimed and MONEY REWARDED |
| D06 | Backup on: inspect the synced configuration's entities | only `ChallengeRecord`, `RewardEntry`, `ManualLog`; no `MetricDay` (no Health values) |
| D07 | App closed for 3 days (`lastEvaluatedKey` = 16 Oct, today 19 Oct) | Evaluator fetches 17, 18 and 19 Oct; past wins are rewarded with the right `dayKey`s; 17 Oct is final |
| D08 | Duplicate `RewardEntry` and `MetricDay` rows inserted (simulated CloudKit merge) → dedupe pass | one row per natural key; `MetricDay` keeps the max value; `RewardEntry` keeps the oldest |
| D09 | Claim F(20/30) money each (all wins already rewarded) | one `final` entry with amount 0; Rewards claimed +1; MONEY REWARDED unchanged |
| D10 | Claim item save "DGX Spark" ₹7,00,000 after 70 wins | 70 `itemSaving` entries sum to exactly ₹7,00,000; one `final` entry with amount 0 and `itemValue` ₹7,00,000 |

## 7a. Settings (S01–S03), proposed (SPEC §7.11)

| ID | Scenario | Expected |
| --- | --- | --- |
| S01 | Tap gear on Overview | Settings sheet with Connect Apple Health, Log by hand, Nudge time, Replay welcome |
| S02 | Change nudge time to 19:00 | today's nudges rescheduled to 19:00; 22:00–07:00 not selectable |
| S03 | Turn on Log by hand | manualMode on; pages show Log today |

## 8. Manual QA (M6+)

- Widgets small/medium show the same numbers as the app within 15 min.
- Live Activity starts when today's progress > 0 and ends at win or 23:59.
- iCloud backup on → reinstall → data restored.
- VoiceOver reads challenge page in order: pill, day, name, rule, hero, remaining, today, footer.
