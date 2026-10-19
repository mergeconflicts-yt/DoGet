# fill. — Product Specification (v1)

iPhone, iOS 18+. English with en-IN number format. Currency INR (₹).

This file is the source of truth for behaviour. Text is in COPY.md, the look in DESIGN.md, storage in DATABASE.md. The clickable reference is prototype/rewards-revamp.html.

Writing conventions: UI text is in "quotes", copy keys are in *italics* (see COPY.md), and placeholders are in {braces}.

## 1. Product

*Reward yourself to move.* You set the goal and choose the reward. The app keeps score. You pay for your own rewards. There is no sign-up, no account and no server, and everything stays on the iPhone.

### Principles

1. The screen is the progress bar: each challenge is a full-screen page in its own color.
2. The solid fill shows progress toward the whole challenge. A striped band on top shows today.
3. Plain language, with numbers you can act on ("11 wins to go in 18 days").
4. Never punish silently. If a challenge can't be won any more, say so and offer a fix.
5. Private: Health is read only and stays on the device.

Not in v1: social challenges, Android or web, moving money, server sync, a Watch app, widgets (M6), suggested rewards, and choosing a currency.

**Currency:** the model stores a currency for each reward, and the Rewards sheet totals each currency separately (ACCEPTANCE W05). The UI only creates INR challenges. The one USD seed challenge exists only to test this.

## 2. Words (use exactly)

- **Challenge:** the whole deal (goal + type + reward), shown as one page. Never call it a "goal".
- **Goal:** the daily target, for example 10,000 steps. The goal line marks 100% of the challenge.
- **Day:** the local calendar day, midnight to midnight, in the current time zone. It is stored as a date (year-month-day), never as a timestamp (§11).
- **Win:** a day that reached the goal.
- **Miss:** a past day in the window that did not. Today is neither until it is won or ends.
- **Rewarded:** a per-win reward that has been given.
- **Claimed:** the final reward, after "Claim reward".
- **Out of reach:** a Flexible challenge that can no longer be won in the time left.
- **Streak broken:** a Streak with a missed day.
- **Manual mode:** Health is not connected, and the user logs each day by hand.

## 3. Metrics

A day is a win when its value is at least the target. For each metric, the list gives the picker label, unit, sentence suffix, default target, stepper step, presets, decimals, pill label and the verb used in sentences.

- **steps:** "Steps", steps, "a day". Default 10,000, step 500, presets 5K, 8K, 10K, 12K. No decimals. Pill "10,000 STEPS". Verb "walk".
- **rings:** "Close rings", rings, "a day". Default 3, step 1, presets 1, 2, 3. No decimals. Pill "3 RINGS". Verb "close". The value is how many of Move, Exercise and Stand were closed, so the target is always 1 to 3.
- **exercise:** "Exercise", minutes, "a day". Default 30, step 5, presets 20, 30, 45, 60. No decimals. Pill "30 MIN EXERCISE". Verb "exercise for".
- **run:** "Run", km, "in one run". Default 5, step 0.5, presets 3, 5, 10, 21.1. 1 decimal. Pill "5 KM RUN". Verb "run".
- **sleep:** "Sleep", hours, "a night". Default 8, step 0.5, presets 7, 7.5, 8. 1 decimal. Pill "8 H SLEEP". Verb "sleep".
- **calories:** "Calories", kcal, "a day". Default 500, step 50, presets 300, 500, 700. No decimals. Pill "500 KCAL". Verb "burn". This is active energy. It is in scope even though the prototype's picker lacks it.

## 4. Challenge types

- **Flexible (flex):** win x days out of y days, with 1 ≤ x ≤ y ≤ 365. Complete when wins ≥ x. The window is y days.
- **Streak:** x days in a row, with 1 ≤ x ≤ 365. Complete after x wins in a row. The window is x days.
- **One time (once):** no settings. Complete when the best single day reaches the target. No deadline.
- **No end (open):** no settings and no deadline.
  - With a jar, it is complete when the amount saved reaches the jar target.
  - With an item, it is complete when the user claims it.
  - Otherwise it is never complete.

Day 1 is the day the challenge is created.

## 5. Rewards

Kinds: money, or an item: Trip, Food, Buy (stored as "item") or Other.

- Each kind has its own phrase in the Create sentence (*reward.phrase*).
- Buy uses "an" before a name that starts with a vowel.
- An item worth more than 0 adds "worth ₹{value}".

### Money payouts

- **Each win (each):** the amount for every win. For Flexible, Streak and No end.
- **At the end (end):** one amount when the challenge is complete. For Flexible, Streak and One time. For One time it is the only option, labelled "One reward".
- **Win + bonus (bonus):** the amount for every win, plus a bonus when complete. For Flexible and Streak.
- **Jar (jar):** each win puts the amount in a jar, and the reward is the jar target. No end only.

### Item payouts

- **All at the end (end):** get the item when the challenge is complete. For every type.
- **Save each win (save):** for Flexible and Streak, and only when the item has a value.
  - Each win puts aside per = value ÷ x, rounded to a whole number. The user never types it.
  - Wins 1 to x − 1 each save per. The last win saves what is left, so the total is exactly the value. Example: ₹5,00,000 over 30 wins is 29 wins of ₹16,667 and a last win of ₹16,657.

### Reward states

- **In progress:** not earned yet.
- **Rewarded:** given at a win.
- **Ready:** the challenge is complete but not claimed.
- **Claimed:** after "Claim reward", stamped CLAIMED.

Never use debt language such as "you owe". The user pays outside the app.

## 6. Rules (engine)

Terms: wins = the number of won days. dayIndex = today's day number counted from 0 at the start. It depends only on the calendar. target = the daily goal.

### Flexible

- need = x − wins, never below 0.
- daysLeft = (y − dayIndex − 1), plus 1 if today is not won yet.
- missesAllowed = daysLeft − need, never below 0.
- The end date is start + (y − 1) days.
- It is out of reach when need > daysLeft. It can then be extended by need − daysLeft days.
- Winning today never changes dayIndex.
  - Example: on day 13 of 30 with 9 wins it reads "11 wins to go in 18 days".
  - After today's win it reads "10 wins to go in 17 days".

### Streak

- need = x − wins.
- While there is no miss, the end date is today + (need − 1) days.
- Any missed day before the streak is complete breaks it.

### One time

- best = the highest single-day value so far.
- Done when best ≥ target. There are no days or misses.

### No end

- Jar: saved = amount × wins. Done when saved ≥ jar target.
- Money each: never done.
- Item: done when the user taps "I'm done · claim {name}".

### Rescue

- Out of reach: Extend, Restart from today, or Scrap.
- Broken streak: Restart from today; Switch to Flexible as x of x + 5 days, keeping existing wins; or Scrap.
- One time and No end never need rescue.

### Progress (the fill)

base is the solid fill and layer is the today band, both from 0 to 1. todayRatio = today's value ÷ target, capped at 0.999.

- Done: base 1, layer 0.
- Flexible and Streak: base = wins ÷ x, layer = todayRatio ÷ x.
- One time: base = best ÷ target, capped at 1. Layer 0.
- No end with a jar: base = amount × wins ÷ jar target, capped at 1. Layer = todayRatio × amount ÷ jar target.
- Other No end: base 0, layer = todayRatio.
- The layer is 0 whenever today is won, or the challenge is out of reach or broken.

### Money

- **Each:** earned = amount × wins. Left = amount × (x − wins), or 0 for No end. Max reward = amount × x; for No end it is "₹{amount} a win".
- **Bonus:** like each. The bonus counts as earned once claimed and as left until then. Max reward = amount × x + bonus.
- **End:** earned = amount once claimed. Before that, left = amount. Max reward = amount.
- **Jar:** like end, using the jar target.
- **Item:** the max reward is "{name} · ₹{value}", or just the name when there is no value.

### Level up (offered after completion)

copies the challenge with these changes:

- **New target:**
  - metrics with decimals: × 1.1, rounded to 1 decimal;
  - targets under 100: + max(1, 10% rounded);
  - other targets: × 1.1, rounded to the nearest 500;
  - rings: + 1, never above 3.
- **Name:** "{name} · Level {n+1}".
- **Color:** the next palette color.
- **Reset:** it starts today, with wins, money and claim state cleared.

It is not offered for No end, or for rings already at 3.

## 7. Screens

Reference size: 393 × 852 pt. Layout and sizes are in DESIGN.md; text is in COPY.md.

### 7.1 Bottom bar (Overview and challenge pages)

- Left pill: "All challenges" (shows k/N on a challenge page) and "Rewards".
- Right: a round + button that opens Create.
- All challenges is highlighted unless Rewards is open. Tapping it goes to Overview.

### 7.2 Overview (page 0)

- **Header:** the date, the title "Today", and a gear button that opens Settings (§7.11).
- **Dark card:** "Rewards claimed" with the count, and "See all", which opens Rewards.
- **One band per challenge.**
  - The fill shows base, with a lighter segment for today. Text turns white where the fill passes under it.
  - Right side: "{pc}% OF GOAL", or "DONE" and "TROPHY" when complete.
  - The subtitle depends on the type (*band.sub*). Out of reach and broken challenges say "tap to fix" instead.
  - Tapping a band opens that challenge's page.
- **Empty state:** "No challenges yet." and the button "Make your first challenge".

### 7.3 Challenge page

Swipe between pages. The background is white, and the challenge color fills from the bottom. From top to bottom:

1. **Pill:** the metric icon and "{target} {PILL}".
   - It is replaced by "OUT OF REACH" or "STREAK BROKEN" (red), "COMPLETED", or "REWARDED".
2. **Beside the pill:**
   - Flexible: "Day {dayIndex+1} of {y}".
   - Streak: "Day {wins+1} of {x}".
   - One time: "Any day".
   - No end: wins so far.
   - When complete: "{Type} · finished", or "Rewarded" once claimed.
   - Manual mode adds "✎ by hand".
3. **Name.**
4. **Rule line:** depends on the type (*page.ruleLine*), for example "Flexible · 20 of 30 days".
5. **Day bars** (not for One time), one per day:
   - won: solid;
   - won by hand: striped;
   - missed: a short red stub;
   - today: partly filled;
   - future: a dot.
6. **Goal line at 100%.**
   - The left label is the max reward.
   - The right label (*goal*) is the end date for Flexible and Streak, "DONE" for a finished streak, "JAR OPENS" for a jar, and empty for One time.
7. **Fill:** the floor, then base, then a striped, pulsing band for today's layer.
8. **Hero:** a big number with its unit and a line under it (*hero*). It sits above the fill, or inside it in white when the fill is high.
   - The number is the wins (Flexible), the days (Streak), the best (One time), the amount saved (jar) or the amount earned (No end each).
   - Example: "9", "of 20 wins", "11 wins to go in 18 days".
   - Done, out of reach and broken each have their own line.
9. **Today pill on the today band:** "TODAY · 2,158 STEPS TO GO", then "TODAY · WON", adding "· BY HAND" if it was logged by hand.
   - Hidden for One time, done and out of reach.
   - In manual mode the Log today button (§7.9) takes its place.
10. **First-win card** (no wins yet, not done, not out of reach): what to do today and what the first win gets (*firstWin*).
11. **Footer** (*foot*):
    - Money each or bonus: EARNED and NEXT WIN.
    - Money end: "REWARD AT THE END", then "REWARD" once done.
    - Item save: SAVED TOWARD IT and NEXT WIN. On the last win, NEXT WIN shows the remainder.
    - Streak with no per-win reward: "MISS A DAY", "Back to 0".
    - No end money: NEXT WIN.
    - Item end with a value: WORTH.
    - No end item: the button "I'm done · claim {name}".
    - Completed: the button "See your trophy", which replays the celebration.

### 7.4 Day won

- When a day becomes a win, the screen fills with the challenge color for 2.6 s.
- It shows "DAY WON", the amount won (or "+1 win") and the win count (*won*), with a success haptic.
- If this win completes the challenge, the celebration follows.

### 7.5 Celebration

- **Entrance:** the challenge color rises from the bottom, with confetti (white, near-black, yellow and the challenge color), haptics, and "CHALLENGE COMPLETE".
- **Trophy:** a number that counts up, its unit, and ring text around it.
- **Reward:** the reward (counting up for money), then "is yours".
- **Stats:** one line for each type (*celebrate.stats*).
- **Claim reward:** the button changes to "Rewarded ✓" and marks the challenge Claimed. The screen closes after 0.9 s, then a toast shows.
- **Level up · {target} {unit}:** shown only when level up is offered (§6).

### 7.6 Create

**Screen:** full screen in the chosen color, with × and "NEW CHALLENGE" at the top. It holds one sentence with three blanks:

I'll [what you'll do] [how often] to win [your reward]

#### Blanks

- They are filled strictly in order.
- An unfilled blank is dashed and pulses. A locked blank (one whose earlier blank isn't filled) is fainter and does not pulse.
- Tapping a locked blank does not open it. Instead it blinks, the blank that is needed shakes, and a hint appears: "First set "…""
- Each blank opens a bottom panel. "Done" fills the blank and opens the next unfilled one.
- A filled blank becomes a white pill. Tap it to edit at any time.
- Filled values come from *create.filled*. Example: I'll **walk 10,000 steps** a day **on 20 of 30 days** to win **a DGX Spark worth ₹7,00,000, ₹10,000 a win**.

**Facts row:** three tiles. Each shows "—" until the blanks it needs are filled.

- MOST YOU CAN WIN: needs how often and the reward. Shows the max reward.
- ENDS: needs how often. Shows the end date, "Any day" for One time, or "Never" for No end.
- MISSES ALLOWED: needs how often. Shows y − x for Flexible, 0 for Streak, and "—" for One time and No end.

#### Bottom of the screen

- **Name field:** the placeholder uses the auto name, which is the item name, or else "{target}{unit}".
- **Colors:** 8 swatches.
- **Main button:** shows the first problem until the challenge is valid, then "Start challenge" (*create.fill*, *create.valid*). The checks, in order: blanks left, reward, target, wins ≤ days, amount, and a jar bigger than the amount.

#### Panels

- **What you'll do:** metric chips, and a target stepper (tap to type) with presets. Without Apple Watch data, the Rings chip is disabled with "Needs Apple Watch".
- **How often:** tiles for Flexible, Streak, One time and No end.
  - Flexible has two steppers, wins and days.
  - Streak has one stepper with presets 7, 14 and 30.
- **Your reward:** tiles for Money, Trip, Food, Buy and Other. There is no currency picker and there are no suggestions.
  - **Money:** payout chips, showing only those allowed for the type (§5), plus amount, bonus and jar steppers as needed.
    - Presets for each win: ₹500, ₹1K, ₹10K.
    - Presets for end: ₹25K, ₹50K, ₹1L.
  - **Item:** a name field (the placeholder depends on the category), a "Worth" stepper, and "How do you get it?", which offers all at the end or save each win.
    - The split is hidden for One time and No end.
    - With no price, it says "Add the price to see options."

**Start:** creates the challenge, closes Create, goes to the new page and shows a toast. The toast is different in manual mode.

### 7.7 Rewards sheet

- **Opening:** from the Rewards tab or "See all". A toggle switches between "Claimed" and "In progress".
- **Money card:** "MONEY REWARDED" or "MONEY STILL TO WIN".
  - It counts money only. Item savings show only on that item's card and in its challenge footer.
  - Below the total: a stacked bar by challenge, and a legend.
  - Tapping it lists the amount for each challenge.
- **Category chips:** All, Trips, Food, Buy, and Other (only when there are any), each with a count.
- **Item cards,** in two columns:
  - The card fills to its progress and shows the percent or a CLAIMED stamp, plus the name, value and challenge.
  - Tapping a card opens its challenge.
- **Empty states:** each tab has its own empty text.

### 7.8 Rescue card

- **Look:** a white card, with the page fill greyed out.
- **Out of reach:** a title and the reason, then "Extend by {n} day(s) · ends {date}", "Restart from today" and "Scrap challenge".
- **Broken streak:** a title and the reason, then "Restart from today", "Keep my {wins} days · switch to {x} of {x+5} days" and "Scrap challenge".
- **Scrap:** needs two taps. The first changes it to "Tap again to scrap".
- **Toasts:** every action shows one.

### 7.9 Log today (manual mode)

- **Button:** a large black "Log today" button where the today band would be, showing {value} / {target}, with a pulsing ring.
- **Sheet:**
  - a stepper (tap to type);
  - chips for 50% and 80% of the target, and "Goal reached ✓";
  - a note about being honest;
  - "Connect Apple Health instead";
  - "Save".
- **Saving:** sets today's total for the metric. It is not added on top.
  - A lower value never replaces a higher one, because a win is never taken back.
  - Every challenge on that metric uses the value.
  - If it reaches the goal, the day is a manual win and Day won shows.
  - For One time it updates the best.

### 7.10 Onboarding (first launch; replay from Settings)

Eight screens. "Skip" on screens 2 to 5 jumps to screen 8. Text is in COPY.md §3.

1. **Welcome,** white over a color fill:
   - the logo and a two-line headline;
   - the deal line;
   - a rolling example that changes every 2.3 s and recolors the screen;
   - "Get started";
   - three privacy chips.
2. **Pink:** the sentence "I'll [walk 10,000 steps] a day [on 20 of 30 days] to win [a trip to Taiwan]", with its blanks filling one by one, then dots and "Next".
3. **Violet:** a mini challenge page whose fill rises to 9 of 20.
4. **Green:** the trophy, showing 20.
5. **Near-black:** a lock, with no sign-up, no account and no server.
6. **Light grey:** the Health types the app reads, shown as switches.
   - "Connect Apple Health" shows the system prompt.
   - "Not now, I'll log by hand" turns on manual mode.
7. **Blue:** two sample notifications.
   - "Allow notifications" shows the system prompt.
   - "Not now" skips it.
8. **Near-black:** a ✓ disc.
   - "Make my first challenge" opens Create.
   - "Explore first" opens Overview.

**Welcome examples,** in order (color: number, label, reward):

- orange: 10,000, steps a day, ₹10,000 each day
- pink: 500, calories burned, Pizza night
- violet: 30, days of closed rings, A trip to Taiwan
- blue: 21.1, km in one run, New running shoes
- teal: 8, hours of sleep, A spa day
- green: 70, days of 10K steps, A DGX Spark

### 7.11 Settings (proposed, not in the prototype)

This is a sheet opened from the gear on Overview, with:

- **Connect Apple Health:** a help sheet, then the Health app.
- **Log by hand:** a switch.
- **Nudge time:** 20:00 by default. Times from 22:00 to 07:00 are not allowed.
- **Back up to iCloud:** a switch (M6).
- **Replay welcome.**
- **A privacy footer.**

Review this before M5.

## 8. Rewards accounting

- **Rewarded at the win:** per-win money (each and bonus) and item savings. History shows them as "Day won" or "toward {item}".
- **Claimed:** end, jar, bonus and item rewards, only after "Claim reward".
- **"Rewards claimed" on Overview:** the rewarded entries plus the claimed challenges.
- **Scrap and Restart:** Scrap archives the challenge. Both keep the rewarded history.
- **Never taken back:** day values only go up, so a reward is never removed. Storage is described in DATABASE §4.2.

## 9. Health and manual mode

- **What it reads (read only):** rings, active and basal energy, exercise, stand, steps, walking and running distance, workouts, and sleep.
- **No data is not an error:** iOS does not say whether access was refused, so missing data shows as 0 and never as an error. "✎ by hand" appears only in manual mode.
- **Manual mode** comes on from onboarding ("Not now, I'll log by hand") or from Settings.
  - Every challenge then uses Log today.
  - Steps may also use Core Motion if the user allows it.
  - Manual wins are drawn striped.

## 10. Notifications (local)

- **Nudge:** at the nudge time (20:00 by default), when today is not won and can still be won. Never for sleep.
- **Day won:** when a day becomes a win.
- **Complete:** when the challenge is complete.
- **Out of reach:** the first time a Flexible challenge goes out of reach.

**Limits:** at most 2 per challenge per day, and none between 22:00 and 07:00.

**Nudge text depends on the metric.**

- For steps it gives minutes of walking: steps left ÷ 100, rounded up to 5.
- Run, rings, exercise and calories each have their own line.
- {win} is what today's win earns: "₹{amount} today" for per-win money or item save, and "the day" otherwise.
- All text is in COPY.md.

## 11. Edge cases

- **Time zone change:**
  - Days are dates, so stored days never move. "Today" is the date in the current zone.
  - Health reads a day as midnight to midnight in the current zone.
  - A day is never duplicated. A date skipped while travelling is an ordinary past day.
- **Late Health data:** a day can turn from a miss into a win until 03:00 the next day. After that it is final.
- **Device date moved back:** ignore data dated in the future.
- **One metric, several challenges:** they share one value per day, and each is judged on its own target and window.
- **Rename and recolor:** allowed (v1.1). Rules and target change only through Rescue.
- **Deleting the app:** the data is lost unless iCloud backup is on.
  - Backup holds challenges, rewards and manual logs, never Health values.
  - Health values are read again after a restore.
