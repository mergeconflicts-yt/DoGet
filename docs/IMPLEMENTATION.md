# fill. — Implementation Guide

How to build SPEC.md and DESIGN.md on iOS. This guide says what to build and how it should behave, not the code. Use the type and function names given here so the docs, tests and code stay in step.

## 1. Architecture

The app has five layers. Each layer only talks to the layers below it.

1. **SwiftUI views** render state and send user actions to their feature model.
2. **Feature models** are @Observable and @MainActor, one per feature folder.
3. **Domain** (the Domain folder) is pure, synchronous and deterministic. It holds the Engine, the Derive helpers and Format, and all of it is unit tested.
4. **Repository** (the Persistence folder) uses SwiftData with two stores: a synced store (optional CloudKit private database) and a local store (Health values, never synced). See DATABASE.md.
5. **ActivityService** (the Activity folder) reads values from HealthKit, Core Motion or manual logs. **Engagement** (the Engagement folder) runs local notifications and background refresh.

### Rules

- **Domain imports only Foundation.**
  - It takes plain values (a challenge, its day results, the current time and a calendar) and returns plain values (a Snapshot).
  - The current time and calendar are always passed in; Domain never reads the clock itself. This keeps tests deterministic and makes the Debug menu's "Advance clock" work.
- **Days are DayKeys** (calendar dates), never timestamps. Convert a timestamp to a DayKey only at the edges: once for "today" from the current time, and when putting Health samples into days.
- **Views never compute rules.** They only show a Snapshot and the strings Derive builds from it.
- **Mapping:** persistence models are mapped to Domain values in Persistence/Mapping.swift (DATABASE §5).

## 2. Domain types (Domain/Types.swift)

All Domain types are value types (structs or enums) that are Codable, Equatable and Sendable.

Enums (their raw string values are what gets stored):

- **Metric:** steps, rings, exercise, run, sleep, calories.
- **ChallengeType:** flex, streak, once, open.
- **RewardKind:** money, item.
- **RewardCategory:** trip, food, item, other. The "item" category is labelled Buy in the UI.
- **MoneyPayout:** each, end, bonus, jar.
- **ItemPayout:** end, save.
- **DataSource:** health, motion, manual.

**DayKey** is a calendar date: year, month and day, with no time and no time zone (SPEC §2 "Day", §11).

- **Why:** a timestamp at local midnight belongs to one time zone. After travel it no longer matches the new zone's midnight, so days get lost or counted twice. A DayKey is the same in every zone.
- **Creating one:** from a timestamp plus the device's current calendar. That answers "which date is it here".
- **Storage:** converts to and from the text form year-month-day (for example 2026-10-19), and sorts in date order.
- **Date math:** it can add days and count the days between two keys. Do this math with a fixed Gregorian calendar in UTC, so the answer never depends on the zone or on daylight saving.
- **Time range:** it can give its midnight-to-midnight range in a given calendar. HealthKit queries use this range.

### Reward

- kind and currency (INR by default);
- for money: payout, amount (per win for each, bonus and jar, or the total for end), bonus, and jar target;
- for an item: category, name, value (0 means no value), and item payout.

Store all money as Decimal, never Double.

### Challenge

- id, name, color token (DESIGN §1.1), metric, daily target and type.
- x: wins needed (Flexible and Streak), 1 for One time, 0 for No end.
- y: the window in days for Flexible; the same as x for Streak.
- start: the DayKey of day 1.
- reward and level.
- Three optional dates: claimed, closed (No end item "I'm done"), and archived (scrapped).

**DayResult:** one day's DayKey, its metric value, its source, and whether it is final (the grace period has passed, SPEC §11).

Format money only through Format.money, which uses en-IN grouping for INR (§10).

## 3. Persistence (SwiftData, CloudKit-safe)

The full design is in DATABASE.md: the two stores, entities, keys, upserts, the rewards ledger, what each action writes, backup and versioning. In short:

- **Synced store** (iCloud private database, only when backup is on, M6): ChallengeRecord, RewardEntry (the append-only rewards ledger) and ManualLog.
- **Local store** (never synced): MetricDay (Health and Motion values per metric per day), AppSettings and NotificationLog.
- **Derived, not stored:** days are stored as DayKey text. Records link by ID, not by relationships. Wins, best, done and money are worked out by the Engine and never stored.

Scrap means archive (set the archived date). Never delete a challenge: its rewarded history must stay (SPEC §8).

## 4. Engine (Domain/Engine.swift)

Engine.snapshot takes a challenge, its list of DayResults, the best value so far (for One time), the current time and a calendar. It returns a **Snapshot** with:

- **wins and misses:** counted as described below.
- **dayIndex:** the 0-based day number since start, from the calendar only.
- **daysLeft:** Flexible only, the days still available to win.
- **need:** wins still needed.
- **todayValue, todayWon and todayRatio:** today's value, whether it reached the target, and value ÷ target capped at 0.999.
- **outOfReach and extendBy:** Flexible only.
- **streakBrokenOnDay:** the 1-based day of the first miss, only while a streak is broken.
- **done:** the challenge is complete.
- **base and layer:** fill progress from 0 to 1 (SPEC §6).
- **endDate:** a DayKey, or none.
- **moneyEarned, moneyLeft and perWin:** SPEC §6.

### How to compute it, in order

1. **Today and day index.** Today is the DayKey for the current time in the given calendar. This is the only step where the time zone matters. dayIndex is the number of days from start to today, never below 0.
2. **Merge duplicate days.** If two results share a DayKey, keep the higher value. A day is won when its value is at least the target.
3. **Window.** Flexible: y days. Streak: x days. One time and No end: no limit.
4. **Past days.** Go through each day from start up to, but not including, today, stopping at the end of the window. Each day is a win or a miss. For a streak, remember the first missed day before the streak was complete; that is the broken day.
5. **Today.**
   - Today is "in the window" if dayIndex is inside it.
   - It counts as a win only if it is in the window and its value is at least the target.
   - Below the target it is neither a win nor a miss.
6. **Done.**
   - Flexible and Streak: wins ≥ x.
   - One time: best ≥ target.
   - No end with a money jar: amount × wins ≥ jar target.
   - Any other No end: done only when the closed date is set.
7. **Need and reach (Flexible, not done):**
   - need = x − wins, never below 0.
   - daysLeft = the days after today still inside the window (y − dayIndex − 1, never below 0), plus 1 for today only if today is in the window and not yet won.
   - outOfReach when need > daysLeft; then extendBy = need − daysLeft.
   - A streak is broken when it is not done and has a broken day.
8. **Progress.** Exactly as in SPEC §6.
   - A done challenge has base 1.
   - The today layer shows only when today is not won, the challenge is not done, out of reach or broken, and today is in the window. Otherwise layer is 0.
9. **Money.** Exactly as in SPEC §6. A challenge counts as claimed only if it is done and has a claimed date.
   - **Each:** earned = amount × wins. Left = amount × the wins still needed, or 0 for No end.
   - **Bonus:** like each. The bonus counts as earned once claimed, and as left until then.
   - **End:** earned = amount once claimed (left 0). Before that, earned 0 and left = amount.
   - **Jar:** like end, using the jar target.
   - **Item rewards:** give 0 earned and 0 left. Item savings are tracked separately (step 11).
10. **End date.**
    - Flexible: start + (y − 1) days.
    - Streak that is not broken and not done: today + (need − 1) days, or today + need days if today is already won.
    - Otherwise none.
11. **Per win and item savings.**
    - perWin is the money amount for each, bonus and jar (0 for end).
    - For an item with the save payout, perWin = item value ÷ x, rounded to a whole number (round half up).
    - The item amount saved after w wins is perWin × w. Once w reaches x it is exactly the item value, so the last win saves the remainder and the total never goes over the price (SPEC §5).
    - The footer's NEXT WIN is the amount saved after the next win minus the amount saved now.

The Snapshot holds no display text. Derive and the UI build the strings, including the max reward text.

Note on a prototype bug: in the prototype, winning today made a Flexible challenge look out of reach, because "today" was a marker that moved. Here dayIndex comes only from the calendar, and once today is won it no longer counts as a day left. Tests A07 and A08 cover this.

### 4.1 Derived helpers (Domain/Derive.swift)

All are pure. They are shared by the Create preview, notifications and widgets.

- Item amounts: the per-win amount and the amount saved, as in step 11.
- End date: as in step 10, always as a DayKey.
- Level up (SPEC §6): returns the new challenge, or nothing when level up is not offered (No end, or rings at target 3).
- Reward phrase (SPEC §5), including the a/an rule.
- Create sentence for a draft (SPEC §7.6).
- Create validation: returns the SPEC §7.6 message for the first problem found, or nothing when the draft is valid.

## 5. Activity data

### 5.1 Activity sources

ActivitySource is an async, Sendable protocol with two jobs:

- give the value of one metric on one DayKey;
- give the best single-day or single-run value since a DayKey (for One time).

There are three sources: HealthKitSource, MotionSource and ManualSource. ActivityService picks one per metric:

- in manual mode, the manual source (it reads ManualLog);
- otherwise HealthKit;
- for steps only, when HealthKit has no data and Motion & Fitness is allowed, Core Motion.

### 5.2 HealthKit authorization

- **Capability:** add HealthKit with background delivery.
- **Usage text:** set the Health share usage description to: "fill. reads your activity on this iPhone to check your challenges. It never uploads, writes or shares your data."
- **No write access:** do not add a Health update usage description. The app never writes to Health.
- **What to request (read only, share nothing):** activity summaries, step count, walking and running distance, active energy, basal energy, exercise time, stand hours, workouts and sleep analysis.
- **Prompt:** iOS shows it only once. After that, Settings → Connect Apple Health opens a short help sheet, then the Health app. If Health can't be opened, fall back to the app's page in iOS Settings.

### 5.3 How each metric's day value is read

- **Steps:** the total step count for the day.
- **Calories:** the total active energy for the day, in kcal.
- **Exercise:** the total exercise time for the day, in minutes.
- **Run:** the running workouts that day; take the longest single run's distance, in km.
- **Sleep:** the asleep samples (core, deep, REM and unspecified) whose end time falls between 12:00 the day before and 12:00 this day. Add up their durations, in hours.
- **Rings:** that day's activity summary. Count how many of Move, Exercise and Stand reached their goal (0 to 3).

### Rules for reading

- **Day range:** a day's time range is its DayKey's midnight to midnight in the **current** time zone.
- **Bulk loading:** when loading many days at once (first load, backfill), ask HealthKit for daily buckets anchored at local midnight, and turn each bucket's start back into a DayKey.
- **No Apple Watch:** exercise, stand and rings data may be missing. In Create, if there are no stand-hour samples in the last 7 days, disable the Rings chip and show "Needs Apple Watch".

### 5.4 Background delivery

- **Register at every launch:** before the first frame, register a HealthKit observer for step count, active energy, exercise time, workouts and sleep.
- **Delivery frequency:** turn on background delivery for each. Use hourly for steps (iOS limits steps to that) and immediate for the rest.
- **When an observer fires:** run the Evaluator (§6), then tell HealthKit the update has been handled. Otherwise iOS stops delivering.

### 5.5 Core Motion fallback (steps only)

- **What to read:** the pedometer, for the day's time range.
- **Usage text:** set the motion usage description to "fill. counts your steps on this iPhone when Apple Health is not connected."
- **History:** Core Motion keeps only 7 days.

### 5.6 Manual logs

- **Saving:** Log today saves a ManualLog for the metric and today. It never lowers a value already saved (DATABASE §4.4).
- **Health values** go in MetricDay and never overwrite a manual log.
- **Both present:** the higher value counts (DATABASE §5).

## 6. Evaluator (the loop)

The Evaluator is an actor with one entry point, "refresh today". Calls within 2 seconds of each other are merged into one run.

It runs:

- when the app comes to the foreground;
- when a HealthKit observer fires;
- on a background app refresh task;
- after Log today is saved;
- at midnight (the system's day-changed notification);
- when the time zone changes (always use the auto-updating current calendar).

### Each run:

1. **Fetch.**
   - For each metric used by an active challenge, read the value of every day from the last evaluated day (stored in AppSettings) through today. This fills in days when the app was closed.
   - Save each value into MetricDay, keeping the higher of the old and new value.
   - Then update the last evaluated day.
2. **Finalize.**
   - Keep reading yesterday until 03:00 local, then mark it final.
   - Never change a final day from Health again.
   - Ignore any stored day after today (SPEC §11, device date moved back).
3. **Evaluate.** For each challenge, build its day results and best value (DATABASE §5) and run the Engine.
4. **Compare** the old and new snapshots, and act on what changed:
   - **A day became a win** (today, or a past day that turned into a win within the grace period):
     - add a RewardEntry if the reward pays per win (DATABASE §4.2);
     - show the Day won overlay if the app is open, otherwise send the day won notification.
   - **The challenge became done:** show the celebration if the app is open, otherwise send the complete notification.
   - **The challenge became out of reach for the first time** (no out-of-reach date saved yet): send the out of reach notification and save the date.
5. **Notifications:** reschedule the nudges (§7).
6. **Widgets:** reload them (M6).

## 7. Notifications (local only)

- **Permission:** ask only on onboarding screen 7, or from Settings.
- **Nudge:** one calendar-triggered notification per challenge per day, at the user's nudge time.
  - Give it a predictable ID made of the challenge ID and the date, so it can be replaced or removed.
  - Remove it when today becomes a win, or when the challenge is done or out of reach.
  - The text uses the numbers at the time it is scheduled, so reschedule on every evaluation.
  - The text depends on the metric (SPEC §10). Never schedule a nudge for sleep.
- **Quiet hours (22:00 to 07:00):** drop non-urgent events. A day won notification in quiet hours is delivered at 07:00, and only if it still matters.
- **Limit:** at most 2 per challenge per day. Count the NotificationLog rows for that challenge and day (DATABASE §4.6).

## 8. UI implementation notes

### 8.1 Pager

- A horizontal paging scroll view that tracks the current page.
- Page 0 is Overview, then one challenge page per active challenge, oldest first.
- The bottom bar reads the current page to show "All challenges k/N".

### 8.2 Challenge page

- **Layout:** use the DESIGN §4 measurements, scaled by screen height ÷ 852 so smaller iPhones keep the same proportions.
- **Layers,** from the bottom up: floor and fill, today band, hero, footer, then overlays.
- **Animation:** when base or layer changes, animate with the fill curve (DESIGN §6). With Reduce Motion on, jump straight to the new value.

### 8.3 Create

- **State:** the Create model holds the draft and the set of filled blanks. Blanks go in a fixed order: what you'll do, how often, your reward.
- **Order lock:** a blank can open only when every blank before it is filled.
- **Done:** marks the blank filled, then opens the next unfilled panel after 0.38 s.
- **Item split:** the per-win amount is recalculated on every change (value ÷ wins, see §4 step 11). The user never types it.
- **Main button:** shows the validation message from Derive, or "Start challenge" when the draft is valid.

### 8.4 Overlays

Day won, Celebration, Rescue, Log today and Rewards are sheets or overlays owned by the app-wide state, so the Evaluator can open them.

### 8.5 Onboarding

- **Pages:** eight (SPEC §7.10). Shown once; AppSettings records that onboarding is done.
- **Welcome roll:** moves on a 2.3 s timer. With Reduce Motion on, the user swipes it instead.
- **Connect Apple Health:** shows the HealthKit prompt, then goes to the next page.
- **Not now, I'll log by hand:** turns on manual mode.

## 9. Privacy and App Store

- **Privacy manifest:** tracking off and no data types collected. Declare UserDefaults (used for the iCloud backup switch, DATABASE §2) with reason CA92.1.
- **App Store Connect privacy label:** Data Not Collected.
- **HealthKit review notes:** explain that the app only reads Health data, keeps it on the device and shows no ads. Link a privacy policy; a static page is fine.
- **Store text:** do not say money "payouts". Say "rewards you give yourself".

## 10. Formatting (Domain/Format.swift)

- **INR:** use the system currency format for INR with the en-IN locale and no decimals. This gives Indian grouping, for example ₹1,00,000.
- **Metric values:** steps, rings, exercise and calories are whole numbers with grouping. Run and sleep have 1 decimal (21.1, 7.5).
- **Dates:** day and short month (5 Nov), in capitals on the goal line (ENDS 5 NOV).

## 11. Debug menu (DEBUG builds only)

Open it by shaking the device or long-pressing the "fill." logo on Overview. Actions:

- +1,000 steps today.
- Finish this challenge.
- Miss days until out of reach, or until the streak breaks.
- Apple Health on or off (turns manual mode on or off).
- Replay onboarding.
- Seed demo data: the 8 challenges in §13.
- Advance clock +1 day: moves the "current time" given to the Engine and Evaluator.

## 12. Milestones

Do them in order. Do not start the next milestone before the current one's exit criteria pass.

- **M0: setup.** Xcode project, targets, DesignSystem (colors, fonts, a components gallery) and the Debug menu shell.
  - Done when the components match DESIGN §5 in the gallery screen.
- **M1: domain.** Domain types, Engine, Derive, Format and their tests.
  - Done when ACCEPTANCE A01 to A33 pass.
- **M2: storage and pages.** SwiftData stores and models per DATABASE.md, mapping, Repository upserts, Overview, the challenge page in every state (from seed data), the bottom bar and the pager.
  - Done when screenshots of every SPEC §7.3 state match the prototype, and ACCEPTANCE D01 to D10 pass.
- **M3: Create.** Blanks, order lock, panels, validation and the item split.
  - Done when ACCEPTANCE C01 to C13 pass.
- **M4: data and moments.** HealthKit, Motion and Manual sources, the Evaluator, Day won, Celebration, Level up, Rescue and Log today.
  - Done when ACCEPTANCE H, M and R pass on a device.
- **M5: the rest of the app.** Rewards sheet, Onboarding (eight screens and the roll), Notifications and Settings.
  - Done when ACCEPTANCE O, N, W and S pass. Settings is still a proposal (SPEC §7.11).
- **M6: extras.** The iCloud backup switch, widgets (small: today band; medium: overview bands), a Live Activity for today and a "Log today" App Intent.
  - Done when the manual QA list in ACCEPTANCE §8 passes.
- **M7: polish.** Accessibility, Reduce Motion, performance (60 fps pager) and App Store assets.
  - Done when every item in AGENTS.md §9 is met.

## 14. Known prototype differences (do not copy these from the prototype)

The prototype is a visual reference. Where it differs from SPEC, follow SPEC.

- **Rule line on the challenge page.**
  - Prototype: "10,000 steps a day · 20 of 30 days".
  - Build: "Flexible · 20 of 30 days" and so on (SPEC §7.3 item 4).
- **Names in the prototype's code.**
  - Prototype: owe, oweb, oweBtn, owedStr, renderOwe and a "paid" ledger.
  - Build: no debt words in code or UI. Use names like rewards, rewardsButton, rewardedCount (AGENTS §10).
- **"Today".**
  - Prototype: a moving marker in the history, so winning today could make a Flexible challenge look out of reach.
  - Build: dayIndex from the calendar only (§4, A07 and A08).
- **Days.**
  - Prototype: JavaScript dates at local midnight.
  - Build: DayKey calendar dates (§2).
- **Calories.**
  - Prototype: missing from the metric picker.
  - Build: in scope (SPEC §3).
- **Rings level up.**
  - Prototype: 3 becomes 4.
  - Build: capped at 3, with no level up at 3 (SPEC §6).
- **Item save.**
  - Prototype: stores an amount per win, so the total can go over the price.
  - Build: the per-win amount is derived, and the last win saves the remainder (SPEC §5).
- **Currency.**
  - Prototype: USD stepper sizes in Create.
  - Build: INR only in the UI (SPEC §1).
- **Settings.**
  - Prototype: none.
  - Build: the proposed screen in SPEC §7.11.
- **Debug toasts.**
  - Prototype: "Apple Health is off. Use "Log today"." in the demo controls.
  - Build: Debug menu only, not in the copy deck.
