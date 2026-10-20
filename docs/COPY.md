# fill. — Copy deck (v1)

Source order: `SPEC.md` > this file > `DESIGN.md` > prototype > `IMPLEMENTATION.md` examples.
`SPEC.md` refers to `COPY.md` §12. The original §12 deck was missing from the
repository, so this file is reconstructed from the SPEC body, `ACCEPTANCE.md`
and the mockup photos. Strings marked **[proposal]** need product review.
Strings marked **[gap]** had no source text at all.

Writing rules: sentence case for UI, mono UPPERCASE only for labels/pills.
Never use debt words (`owe`, `owed`, `debt`, `pay back`). Money is always
shown through `Format.money` (en-IN: `₹1,00,000`).

## 1. Words (SPEC §2)

| Use | Not |
| --- | --- |
| Challenge (the whole deal) | goal |
| Goal (the daily target) | target, aim |
| Day | date |
| Win | success, check-in |
| Miss | fail, loss |
| Rewarded | paid, earned back |
| Claimed | collected, redeemed |
| Out of reach | impossible, failed |
| Streak broken | lost, dead |
| Manual mode / by hand | offline, no data |
| Each time (per-win money) | a win, per win |

## 2. Overview (SPEC §7.2)

| Key | Text |
| --- | --- |
| `overview.title` | Today |
| `overview.challenges` | Challenges **[proposal]** (redesign title) |
| `overview.rewardsClaimed` | Rewards claimed |
| `overview.seeAll` | See all |
| `overview.empty` | No challenges yet. |
| `overview.firstChallenge` | Make your first challenge |
| `overview.section.inProgress` | In progress |
| `overview.section.completed` | Completed |
| `overview.section.emptyInProgress` | No challenges in progress. |
| `overview.section.emptyCompleted` | No completed challenges yet. |
| `band.percent` | {pc}% OF GOAL |
| `band.done` | DONE |
| `band.trophy` | TROPHY |
| `band.doneTrophy` | DONE · TROPHY **[proposal]** (combined band label) |
| `band.fix` | tap to fix |
| `band.sub.flex` | Flexible · {wins} of {x} wins · today {todayValue} {unit} |
| `band.sub.streak` | Streak · {wins} of {x} days · today {todayValue} {unit} |
| `band.sub.once` | One time · best {best} {unit} |
| `band.sub.jar` | Jar · {saved} of {target} |
| `band.sub.open` | No end · {wins} wins |

## 3. Challenge page (SPEC §7.3)

### Status pill

| Key | Text |
| --- | --- |
| `pill.steps` | {target} STEPS |
| `pill.rings` | {target} RINGS |
| `pill.exercise` | {target} MIN EXERCISE |
| `pill.run` | {target} KM RUN |
| `pill.sleep` | {target} H SLEEP |
| `pill.calories` | {target} KCAL |
| `pill.outOfReach` | OUT OF REACH |
| `pill.streakBroken` | STREAK BROKEN |
| `pill.completed` | COMPLETED |
| `pill.rewarded` | REWARDED |

### Beside the pill

| Key | Text |
| --- | --- |
| `page.day.flex` | Day {dayIndex+1} of {y} |
| `page.day.streak` | Day {wins+1} of {x} |
| `page.day.once` | Any day |
| `page.day.open` | {wins} wins so far |
| `page.finished` | {Type} · finished |
| `page.claimed` | Rewarded |
| `page.byHand` | ✎ by hand |

### Rule line

The rule line is the type and its rule, not the daily target.

| Key | Text |
| --- | --- |
| `page.rule.flex` | Flexible · {x} of {y} days |
| `page.rule.streak` | Streak · {x} days in a row |
| `page.rule.once` | One time · any day |
| `page.rule.open` | No end · never ends |
| `page.rule.jar` | No end · jar opens at {jarTarget} |

### Goal line

| Key | Text |
| --- | --- |
| `goal.money.each` | {amount × x} |
| `goal.money.bonus` | {amount × x + bonus} |
| `goal.money.end` | {amount} |
| `goal.money.jar` | {jarTarget} |
| `goal.item` | {name} · {value} |
| `goal.item.noValue` | {name} |
| `goal.noEndEach` | {amount} a win |
| `goal.ends` | ENDS {d MMM} |
| `goal.streakDone` | DONE |
| `goal.jar` | JAR OPENS |

### Hero

| State | Number | Unit | Line |
| --- | --- | --- | --- |
| Flexible, active | {wins} | of {x} wins | {need} wins to go in {daysLeft} days |
| Flexible, done | {wins} | of {x} wins | {x} wins · done |
| Streak, active | {wins} | of {x} days | {need} days to go |
| Streak, done | {wins} | days in a row | {x} days in a row · done |
| One time, active | {best} | of {target} {unit} | {left} {unit} to go in one run/day |
| One time, done | {best} | of {target} {unit} | {target} {unit} in one run/day · done |
| No end, jar | {saved} | of {jarTarget} | {left} to go in {n} wins |
| No end, money each | {earned} | earned | {wins} wins so far |
| No end, item | {wins} | wins | {wins} wins so far |
| Out of reach | {wins} | of {x} wins | {need} wins needed, {daysLeft} days left |
| Streak broken | {wins} | of {x} days | Broken on day {d}. |

### Today

| Key | Text |
| --- | --- |
| `today.toGo` | TODAY · {remaining} TO GO |
| `today.won` | TODAY · WON |
| `today.wonByHand` | TODAY · WON · BY HAND |
| `today.log` | Log today |
| `today.logValue` | {value} / {target} |
| `today.logHint` | Log today's {unit} |

### First-win card

| Key | Text |
| --- | --- |
| `firstWin.label` | YOUR FIRST WIN |
| `firstWin.what` | {Verb} {target} {unit} today |
| `firstWin.gets.money` | and get {amount} |
| `firstWin.gets.save` | and get {perWin} toward {name} |
| `firstWin.gets.other` | and you are one step closer to {name} |

### Footer

| Key | Text |
| --- | --- |
| `foot.earned` | EARNED |
| `foot.nextWin` | NEXT WIN |
| `foot.saved` | SAVED TOWARD IT |
| `foot.rewardAtEnd` | REWARD AT THE END |
| `foot.reward` | REWARD |
| `foot.worth` | WORTH |
| `foot.missADay` | MISS A DAY |
| `foot.backToZero` | Back to 0 |
| `foot.imDone` | I'm done · claim {name} |
| `foot.seeTrophy` | See your trophy |
| `foot.nextWinValue` | +{amount} |

## 4. Create (SPEC §7.6)

| Key | Text |
| --- | --- |
| `create.title` | NEW CHALLENGE |
| `create.sentence` | I'll [what you'll do] [how often] to win [your reward] |
| `create.blank.what` | what you'll do |
| `create.blank.howOften` | how often |
| `create.blank.reward` | your reward |
| `create.locked` | First set “[blank]”. |
| `create.done` | Done |
| `create.namePlaceholder` | {autoName} |
| `create.start` | Start challenge |
| `create.fillBlanks` | Fill in {n} blank(s) |
| `create.facts.max` | MOST YOU CAN WIN |
| `create.facts.ends` | ENDS |
| `create.facts.misses` | MISSES ALLOWED |
| `create.facts.anyDay` | Any day |
| `create.facts.never` | Never |
| `create.valid.money` | {amount} each time |
| `create.valid.atEnd` | {amount} at the end |
| `create.valid.bonus` | {amount} each time + {bonus} at the end |
| `create.valid.jar` | a jar that opens at {jarTarget} |
| `create.valid.item` | {a/an} {item} |
| `create.valid.save` | {a/an} {item} worth {value}, {perWin} a win |
| `create.valid.noValue` | {a/an} {item} |
| `create.act.steps` | walk {target} steps |
| `create.act.rings` | close {target} rings |
| `create.act.exercise` | exercise for {target} minutes |
| `create.act.run` | run {target} km |
| `create.act.sleep` | sleep {target} hours |
| `create.act.calories` | burn {target} kcal |
| `create.rule.flex` | on {x} of {y} days |
| `create.rule.streak` | {x} days in a row |
| `create.rule.once` | one time |
| `create.rule.open` | every day, no end |
| `create.panel.what` | What you'll do |
| `create.panel.howOften` | How often |
| `create.panel.reward` | Your reward |
| `create.tile.flex` | Flexible · X of Y days |
| `create.tile.streak` | Streak · In a row |
| `create.tile.once` | One time · Just once |
| `create.tile.open` | No end · Every day |
| `create.reward.money` | Money |
| `create.reward.trip` | Trip |
| `create.reward.food` | Food |
| `create.reward.buy` | Buy |
| `create.reward.other` | Other |
| `create.item.trip` | Where to? e.g. Taiwan |
| `create.item.food` | What treat? e.g. Pizza night |
| `create.item.buy` | What to buy? e.g. DGX Spark |
| `create.item.other` | What is it? e.g. Concert tickets |
| `create.item.worth` | WORTH |
| `create.item.how` | How do you get it? |
| `create.item.noPrice` | Add the price to see options. |
| `create.item.end` | All at the end |
| `create.item.endSub` | {value} when you finish |
| `create.item.save` | {perWin} each win |
| `create.item.saveSub` | {x} wins × {perWin} |
| `create.payout.each` | Each win |
| `create.payout.end` | At the end |
| `create.payout.once` | One reward |
| `create.payout.bonus` | Win + bonus |
| `create.payout.jar` | Jar |
| `create.ringsNeedsWatch` | Needs Apple Watch |

### Create hints and field labels

These had no line in SPEC or the mockups. **[proposal]** — review before release.

| Key | Text |
| --- | --- |
| `create.hint.what` | Pick what you'll do. **[proposal]** |
| `create.hint.howOften` | Pick how often. **[proposal]** |
| `create.hint.reward` | Pick your reward. **[proposal]** |
| `create.hint.payout` | Pick a reward above. **[proposal]** |
| `create.name.challenge` | Challenge name **[proposal]** |
| `create.name.reward` | Reward name **[proposal]** |
| `create.field.goal` | Goal **[proposal]** |
| `create.field.amount` | Amount **[proposal]** |
| `create.field.bonus` | Bonus **[proposal]** |
| `create.field.jarTarget` | Jar opens at **[proposal]** |
| `create.unit.wins` | wins **[proposal]** |
| `create.unit.days` | days **[proposal]** |
| `create.closePanel` | Close panel **[proposal]** (spoken only) |

### Create validation (in order)

1. Blanks left: `Fill in {n} blank(s)`
2. Reward:
   - item name missing: `Add a name to your reward` **[proposal]**
   - money amount missing/zero: `Set an amount` **[proposal]**
3. Target:
   - missing/zero: `Set a target` **[proposal]**
   - rings outside 1–3: `Rings go from 1 to 3` **[proposal]**
4. Wins fit in the days:
   - wins or days not set yet: `Set the wins and days` **[proposal]**
   - wins greater than days: `Wins must fit in the days`
5. Amount (already checked in 2 for money).
6. Jar bigger than each win: `Jar must be bigger`

## 5. Log today (SPEC §7.9)

| Key | Text |
| --- | --- |
| `log.title` | Log today |
| `log.honest` | Be honest — this is your own challenge. |
| `log.connect` | Connect Apple Health instead |
| `log.save` | Save |
| `log.saved` | Saved. |
| `log.chip.half` | 50% |
| `log.chip.eighty` | 80% |
| `log.chip.goal` | Goal reached ✓ |

## 6. Day won (SPEC §7.4)

| Key | Text |
| --- | --- |
| `dayWon.title` | DAY WON |
| `dayWon.amount` | +{amount} |
| `dayWon.win` | +1 win |
| `dayWon.sub` | {name} · {wins} wins |

## 7. Celebration and level up (SPEC §7.5, §6)

| Key | Text |
| --- | --- |
| `celebrate.title` | CHALLENGE COMPLETE |
| `celebrate.unit.wins` | WINS |
| `celebrate.unit.streak` | IN A ROW |
| `celebrate.unit.saved` | SAVED |
| `celebrate.unit.item` | {UNIT} |
| `celebrate.isYours` | is yours |
| `celebrate.claim` | Claim reward |
| `celebrate.claimed` | Rewarded ✓ |
| `celebrate.toast` | {reward} is yours. |
| `celebrate.stats.flex` | {wins} wins · {misses} misses · {days} days |
| `celebrate.stats.streak` | {x} days in a row |
| `celebrate.stats.once` | {target} {unit} in one {run/day} |
| `celebrate.stats.jar` | {wins} wins · {jarTarget} in the jar |
| `celebrate.stats.openEach` | {wins} wins · {earned} earned |
| `celebrate.stats.openItem` | {wins} wins · for {name} |
| `celebrate.ring` | {name} · {Type} · {d MMM} |
| `levelUp.button` | Level up · {target} {unit} |
| `levelUp.toast` | Level {n} started: {target} {unit}. |

## 8. Rescue (SPEC §7.8)

| Key | Text |
| --- | --- |
| `rescue.outOfReach` | Out of reach |
| `rescue.streakBroken` | Streak broken |
| `rescue.reason.outOfReach` | You need {need} more wins, but only {daysLeft} days are left. |
| `rescue.reason.streak` | You missed day {day}. Your streak is back to 0. |
| `rescue.extend` | Extend by {n} day(s) · ends {date} |
| `rescue.restart` | Restart from today |
| `rescue.switch` | Keep my {wins} days · switch to {x} of {x+5} days |
| `rescue.scrap` | Scrap challenge |
| `rescue.scrapConfirm` | Tap again to scrap |
| `rescue.toast.extend` | Extended by {n} day(s). Ends {date}. |
| `rescue.toast.restart` | Restarted from today. |
| `rescue.toast.switch` | Switched to {x} of {y} days. |
| `rescue.toast.scrap` | Scrapped. Your rewards are kept. |

## 9. Notifications (SPEC §10)

| Key | Text |
| --- | --- |
| `notif.nudge.title` | {name} · {remaining} to go |
| `notif.nudge.steps` | A {minutes}-minute walk{win}. |
| `notif.nudge.run` | One {target} km run{win}. |
| `notif.nudge.rings` | Close your rings{win}. |
| `notif.nudge.exercise` | {left} minutes of exercise{win}. |
| `notif.nudge.calories` | Burn {left} kcal{win}. |
| `notif.win.money` |  wins {amount} today |
| `notif.win.day` |  wins the day |
| `notif.dayWon.title` | {name} |
| `notif.dayWon.body` | Day won. {amount} |
| `notif.complete.title` | {name} |
| `notif.complete.body` | Challenge complete. {reward} is yours. |
| `notif.outOfReach.title` | {name} |
| `notif.outOfReach.body` | Out of reach. Tap to fix. |

## 10. Onboarding (SPEC §7.10)

| Key | Text |
| --- | --- |
| `onb.welcome.title` | Reward / yourself / for moving. |
| `onb.welcome.sub` | Set a health goal. Choose your reward. Win the day. |
| `onb.welcome.kicker` | Your goal → your reward |
| `onb.welcome.deal` | You set the goal. You choose the reward. We keep score. You pay for your rewards. |
| `onb.getStarted` | Get started |
| `onb.chip.noSignup` | No sign-up |
| `onb.chip.noAccount` | No account |
| `onb.chip.noServer` | No server |
| `onb.skip` | Skip |
| `onb.next` | Next |
| `onb.deal.title` | You make the deal. |
| `onb.deal.body` | Pick what you'll do, how often, and your reward. You pay for the reward yourself. The app only tracks it. |
| `onb.mini.title` | Watch it fill. **[proposal]** |
| `onb.mini.body` | Every win fills the page. The striped band on top is today. **[proposal]** |
| `onb.trophy.title` | Win it. Claim it. |
| `onb.trophy.body` | Finish a challenge to claim your reward. Then start a new one. |
| `onb.privacy.title` | Private by design. |
| `onb.privacy.body` | No sign-up, no account, no server. Everything stays on this iPhone. |
| `onb.health.title` | Connect Apple Health |
| `onb.health.body` | The app reads your activity on this iPhone to check your challenges. It never uploads, writes or shares your data. |
| `onb.health.steps` | Steps |
| `onb.health.rings` | Activity rings |
| `onb.health.exercise` | Exercise minutes |
| `onb.health.workouts` | Workouts and distance |
| `onb.health.sleep` | Sleep |
| `onb.health.connect` | Connect Apple Health |
| `onb.health.manual` | Not now, I'll log by hand |
| `onb.notif.title` | A nudge before the day ends. |
| `onb.notif.body` | Only when a win is close, or when you win. No spam. |
| `onb.notif.allow` | Allow notifications |
| `onb.notif.notNow` | Not now |
| `onb.set.title` | You're set. |
| `onb.set.body` | No sign-up, no account. Everything stays on this iPhone. Make your first challenge. It takes 3 taps. |
| `onb.set.create` | Make my first challenge |
| `onb.set.explore` | Explore first |

### Welcome roll examples

| Color | Number | Label | Reward |
| --- | --- | --- | --- |
| orange | 10,000 | steps a day | ₹10,000 each day |
| pink | 500 | calories burned | Pizza night |
| violet | 30 | days of closed rings | A trip to Taiwan |
| blue | 21.1 | km in one run | New running shoes |
| teal | 8 | hours of sleep | A spa day |
| green | 70 | days of 10K steps | A DGX Spark |

### Violet mini-page example

Fixed demo values shown on the violet onboarding page. **[proposal]** — these
are illustration data, not user copy; they mirror the October 10K seed.

| Element | Text |
| --- | --- |
| Card title | October 10K |
| Hero number | 9 |
| Hero unit | of 20 wins |
| Band | TODAY · 2,158 STEPS TO GO |
| Notification 1 | October 10K · 2,158 steps to go |
| Notification 2 | Day won. +₹10,000 |
| Demo sentence | I'll walk 10,000 steps a day on 20 of 30 days to win a trip to Taiwan |

## 11. Settings (SPEC §7.11, proposed)

| Key | Text |
| --- | --- |
| `settings.title` | Settings |
| `settings.connect` | Connect Apple Health |
| `settings.manual` | Log by hand |
| `settings.nudge` | Nudge time: {hour}:{minute} |
| `settings.backup` | Back up to iCloud |
| `settings.replay` | Replay welcome |
| `settings.footer` | fill. keeps your activity on this iPhone. It never uploads or shares Health data. |

## 12. Toasts

| Key | Text |
| --- | --- |
| `toast.started` | Challenge started. |
| `toast.started.manual` | Challenge started. Every challenge now uses Log today. |
| `toast.saved` | Saved. |
| `toast.claimed` | {reward} is yours. |
| `toast.extended` | Extended by {n} day(s). Ends {date}. |
| `toast.restarted` | Restarted from today. |
| `toast.switched` | Switched to {x} of {y} days. |
| `toast.scrapped` | Scrapped. Your rewards are kept. |
| `toast.levelUp` | Level {n} started: {target} {unit}. |

## 13. Accessibility labels (proposed)

These are spoken labels; visible text is above.

| Element | Label |
| --- | --- |
| Gear | Settings |
| Bottom bar left | All challenges |
| Bottom bar plus | New challenge |
| Challenge band | {name}, {pc}% of goal |
| Today pill | {visible text} |
| Log today button | Log today, {value} of {target} {unit} |
| Stepper minus/plus | Decrease / Increase |
| Stepper value | {value} {unit}. Double tap to type a value. |
| Color swatch | Color {token} |
| Health switch | {health type} |
| Create close | Close |
| Create panel close | Close panel |
| Challenge name field | Challenge name |
| Reward name field | Reward name |
| Footer stat | {left} {value}, {right} {value} |

## 14. Gaps and conflicts

- The original `SPEC.md` §12 copy deck and `prototype/rewards-revamp.html`
  are not in this repository. This deck is reconstructed and every invented
  line is marked.
- `DATABASE.md` §2 stores `iCloudBackup` in `AppSettings`; the review notes it
  should live in `UserDefaults`. `DATABASE.md` is the storage source of truth,
  so the flag stays in `AppSettings` until the docs agree. Flagged in `TASK.md`.
- `DESIGN.md` §5 specifies the gel press dent; `SPEC.md` does not. Kept,
  because DESIGN explicitly describes it; share cards were removed because
  their strings have no SPEC/COPY source.
