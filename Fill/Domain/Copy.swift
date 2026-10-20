import Foundation

/// Copy deck. Source: docs/COPY.md (reconstructed from SPEC §7–10, ACCEPTANCE
/// and the mockups; the original SPEC §12 deck is missing). Strings marked
/// proposal/gap in COPY.md are flagged here too.
public enum Copy {
    // MARK: - Overview (SPEC §7.2)
    public static let today = "Today"
    public static let allChallenges = "Challenges"
    public static let rewardsClaimed = "Rewards claimed"
    public static let seeAll = "See all"
    public static let noChallenges = "No challenges yet."
    public static let firstChallenge = "Make your first challenge"
    public static let sectionInProgress = "In progress"
    public static let sectionCompleted = "Completed"
    public static let sectionEmptyInProgress = "No challenges in progress."
    public static let sectionEmptyCompleted = "No completed challenges yet."
    public static let bandDone = "DONE · TROPHY"
    public static let bandFix = "tap to fix"
    public static func bandPercent(_ pc: Int) -> String { "\(pc)% OF GOAL" }
    public static func bandSubFlex(wins: Int, x: Int, today: String, unit: String) -> String {
        "Flexible · \(wins) of \(x) wins · today \(today) \(unit)"
    }
    public static func bandSubStreak(wins: Int, x: Int, today: String, unit: String) -> String {
        "Streak · \(wins) of \(x) days · today \(today) \(unit)"
    }
    public static func bandSubOnce(best: String, unit: String) -> String {
        "One time · best \(best) \(unit)"
    }
    public static func bandSubJar(saved: String, target: String) -> String {
        "Jar · \(saved) of \(target)"
    }
    public static func bandSubOpen(wins: Int) -> String { "No end · \(wins) wins" }

    // MARK: - Challenge page (SPEC §7.3)
    public static let outOfReach = "OUT OF REACH"
    public static let streakBroken = "STREAK BROKEN"
    public static let completed = "COMPLETED"
    public static let rewarded = "REWARDED"
    public static let claimed = "Rewarded"
    public static let todayWon = "TODAY · WON"
    public static let byHand = " · MANUALLY"
    public static let byHandShort = "✎ manually"
    public static let firstWin = "YOUR FIRST WIN"
    public static let seeTrophy = "See your trophy"
    public static let anyDay = "Any day"
    public static let finishedSuffix = " · finished"

    public static func pillSteps(_ target: String) -> String { "\(target) STEPS" }
    public static func pillRings(_ target: String) -> String { "\(target) RINGS" }
    public static func pillExercise(_ target: String) -> String { "\(target) MIN EXERCISE" }
    public static func pillRun(_ target: String) -> String { "\(target) KM RUN" }
    public static func pillSleep(_ target: String) -> String { "\(target) H SLEEP" }
    public static func pillCalories(_ target: String) -> String { "\(target) KCAL" }

    public static func dayFlex(_ day: Int, of y: Int) -> String { "Day \(day) of \(y)" }
    public static func dayStreak(_ day: Int, of x: Int) -> String { "Day \(day) of \(x)" }
    public static func dayOpen(_ wins: Int) -> String { "\(wins) wins so far" }

    public static func ruleFlex(_ x: Int, _ y: Int) -> String { "Flexible · \(x) of \(y) days" }
    public static func ruleStreak(_ x: Int) -> String { "Streak · \(x) days in a row" }
    public static let ruleOnce = "One time · any day"
    public static let ruleOpen = "No end · never ends"
    public static func ruleJar(_ target: String) -> String { "No end · jar opens at \(target)" }

    // Hero lines (COPY.md §3) and goal-line labels.
    public static func heroFlexActive(need: Int, daysLeft: Int) -> String {
        "\(need) wins to go in \(daysLeft) days"
    }
    public static func heroFlexDone(_ x: Int) -> String { "\(x) wins · done" }
    public static func heroStreakActive(need: Int) -> String { "\(need) days to go" }
    public static func heroStreakDone(_ x: Int) -> String { "\(x) days in a row · done" }
    public static func heroOnceActive(left: String, unit: String, run: Bool) -> String {
        "\(left) \(unit) to go in one \(run ? "run" : "day")"
    }
    public static func heroOnceDone(target: String, unit: String, run: Bool) -> String {
        "\(target) \(unit) in one \(run ? "run" : "day") · done"
    }
    public static func heroJarLeft(_ left: String, wins: Int) -> String {
        "\(left) to go in \(wins) wins"
    }
    public static func heroOutOfReach(need: Int, daysLeft: Int) -> String {
        "\(need) wins needed, \(daysLeft) days left"
    }
    public static func goalNoEndEach(_ amount: String) -> String { "\(amount) a win" }
    public static let goalStreakDone = "DONE"
    public static let goalJar = "JAR OPENS"

    public static func todayToGo(_ remaining: String) -> String { "TODAY · \(remaining) TO GO" }
    public static func todayWonByHand() -> String { todayWon + byHand }

    public static func logValue(_ value: String, _ target: String) -> String { "\(value) / \(target)" }
    public static func logHint(_ unit: String) -> String { "Log today's \(unit)" }

    public static func firstWinWhat(verb: String, target: String, unit: String) -> String {
        "\(verb) \(target) \(unit) today"
    }
    public static func firstWinGetsMoney(_ amount: String) -> String { "and get \(amount)" }
    public static func firstWinGetsSave(_ amount: String, name: String) -> String {
        "and get \(amount) toward \(name)"
    }
    public static func firstWinGetsOther(_ name: String) -> String {
        "and you are one step closer to \(name)"
    }

    // MARK: - Footer (SPEC §7.3 item 11)
    public static let earned = "EARNED"
    public static let nextWin = "NEXT WIN"
    public static let savedTowardIt = "SAVED TOWARD IT"
    public static let rewardAtTheEnd = "REWARD AT THE END"
    public static let reward = "REWARD"
    public static let worth = "WORTH"
    public static let missADay = "MISS A DAY"
    public static let backToZero = "Back to 0"
    public static func imDoneClaim(_ name: String) -> String { "I'm done · claim \(name)" }
    public static func plus(_ amount: String) -> String { "+\(amount)" }
    public static func brokenLine(_ day: Int) -> String { "Broken on day \(day)." }

    // MARK: - Create (SPEC §7.6)
    public static let newChallenge = "NEW CHALLENGE"
    public static let mostYouCanWin = "MOST YOU CAN WIN"
    public static let ends = "ENDS"
    public static let missesAllowed = "MISSES ALLOWED"
    public static let anyDayFact = "Any day"
    public static let never = "Never"
    public static let whatYouWillDo = "What you'll do"
    public static let howOften = "How often"
    public static let yourReward = "Your reward"
    public static let blankWhat = "what you'll do"
    public static let blankHowOften = "how often"
    public static let blankReward = "your reward"
    public static let tileFlexSub = "X of Y days"
    public static let tileStreakSub = "In a row"
    public static let tileOnceSub = "Just once"
    public static let tileOpenSub = "Every day"
    public static let tileFlex = "Flexible"
    public static let tileStreak = "Streak"
    public static let tileOnce = "One time"
    public static let tileOpen = "No end"
    public static let itemOtherPlaceholder = "What is it? e.g. Concert tickets"
    public static let itemTripPlaceholder = "Where to? e.g. Taiwan"
    public static let itemFoodPlaceholder = "What treat? e.g. Pizza night"
    public static let itemBuyPlaceholder = "What to buy? e.g. DGX Spark"
    public static let needsAppleWatch = "Needs Apple Watch"
    public static let done = "Done"
    public static let startChallenge = "Start challenge"
    public static let addPrice = "Add the price to see options."
    public static let itemWorth = "WORTH"
    public static let howYouGetIt = "How do you get it?"
    public static let allAtTheEnd = "All at the end"
    public static let rewardMoney = "Money"
    public static let rewardTrip = "Trip"
    public static let rewardFood = "Food"
    public static let rewardBuy = "Buy"
    public static let rewardOther = "Other"
    public static let pickReward = "Pick a reward above."
    public static let pickWhat = "Pick what you'll do."
    public static let pickHowOften = "Pick how often."
    public static let pickYourReward = "Pick your reward."
    public static let challengeNameLabel = "Challenge name"
    public static let rewardNameLabel = "Reward name"
    public static let closePanel = "Close panel"
    public static let winsUnit = "wins"
    public static let daysUnit = "days"
    public static let targetLabel = "Goal"
    public static let amountLabel = "Amount"
    public static let bonusLabel = "Bonus"
    public static let jarTargetLabel = "Jar opens at"
    public static func colorLabel(_ token: String) -> String { "Color \(token)" }

    public static func fillBlanks(_ n: Int) -> String { "Fill in \(n) blank\(n == 1 ? "" : "s")" }
    public static func lockedHint(_ blank: String) -> String { "First set “\(blank)”." }
    public static func actSteps(_ target: String) -> String { "walk \(target) steps" }
    public static func actRings(_ target: String) -> String { "close \(target) rings" }
    public static func actExercise(_ target: String) -> String { "exercise for \(target) minutes" }
    public static func actRun(_ target: String) -> String { "run \(target) km" }
    public static func actSleep(_ target: String) -> String { "sleep \(target) hours" }
    public static func actCalories(_ target: String) -> String { "burn \(target) kcal" }
    public static func createRuleFlex(_ x: Int, _ y: Int) -> String { "on \(x) of \(y) days" }
    public static func createRuleStreak(_ x: Int) -> String { "\(x) days in a row" }
    public static let createRuleOnce = "one time"
    public static let createRuleOpen = "every day, no end"
    public static func itemEndSub(_ value: String) -> String { "\(value) when you finish" }
    public static func itemSaveSub(_ x: Int, _ per: String) -> String { "\(x) wins × \(per)" }
    public static func itemSaveTitle(_ per: String) -> String { "\(per) each win" }
    public static func createEnds(_ date: String) -> String { date }
    public static let payoutEach = "Each win"
    public static let payoutEnd = "At the end"
    public static let payoutOnce = "One reward"
    public static let payoutBonus = "Win + bonus"
    public static let payoutJar = "Jar"
    public static func validationRings() -> String { "Rings go from 1 to 3" }
    public static func validationName() -> String { "Add a name to your reward" }
    public static let validationTarget = "Set a target"
    public static let validationAmount = "Set an amount"
    /// [proposal] COPY.md §4: no source line exists for a half-filled How
    /// often panel; this is the closest existing wording.
    public static let validationWinsDays = "Set the wins and days"
    public static let validationWinsFit = "Wins must fit in the days"
    public static let validationJar = "Jar must be bigger"

    // MARK: - Log today (SPEC §7.9)
    public static let logToday = "Log today"
    public static let honest = "Be honest — this is your own challenge."
    public static let connectInstead = "Connect Apple Health instead"
    public static let save = "Save"
    public static let saved = "Saved."
    public static let half = "50%"
    public static let eighty = "80%"
    public static let goalReached = "Goal reached ✓"

    // MARK: - Day won (SPEC §7.4)
    public static let dayWon = "DAY WON"
    public static let oneWin = "+1 win"
    public static func dayWonSub(_ name: String, _ wins: Int) -> String { "\(name) · \(wins) wins" }

    // MARK: - Celebration (SPEC §7.5)
    public static let challengeComplete = "CHALLENGE COMPLETE"
    public static let claimReward = "Claim reward"
    public static let rewardedCheck = "Rewarded ✓"
    public static let isYours = "is yours"
    public static let unitWins = "WINS"
    public static let unitInARow = "IN A ROW"
    public static let unitSaved = "SAVED"

    public static func statsFlex(wins: Int, misses: Int, days: Int) -> String {
        "\(wins) wins · \(misses) misses · \(days) days"
    }
    public static func statsStreak(_ x: Int) -> String { "\(x) days in a row" }
    public static func statsOnce(_ target: String, _ unit: String, run: Bool) -> String {
        "\(target) \(unit) in one \(run ? "run" : "day")"
    }
    public static func statsJar(_ wins: Int, _ target: String) -> String {
        "\(wins) wins · \(target) in the jar"
    }
    public static func statsOpenEach(_ wins: Int, _ earned: String) -> String {
        "\(wins) wins · \(earned) earned"
    }
    public static func statsOpenItem(_ wins: Int, _ name: String) -> String {
        "\(wins) wins · for \(name)"
    }
    public static func ringText(_ name: String, _ type: String, _ date: String) -> String {
        "\(name) · \(type) · \(date)"
    }
    public static func levelUpButton(_ target: String, _ unit: String) -> String {
        "Level up · \(target) \(unit)"
    }
    public static func levelUpToast(_ n: Int, _ target: String, _ unit: String) -> String {
        "Level \(n) started: \(target) \(unit)."
    }
    public static func claimToast(_ reward: String) -> String { "\(reward) is yours." }

    // MARK: - Rescue (SPEC §7.8)
    public static let rescueOOR = "Out of reach"
    public static let rescueBroken = "Streak broken"
    public static let restartFromToday = "Restart from today"
    public static let scrapChallenge = "Scrap challenge"
    public static let tapAgainToScrap = "Tap again to scrap"
    public static func extend(days: Int, date: String) -> String {
        "Extend by \(days) day\(days == 1 ? "" : "s") · ends \(date)"
    }
    public static func switchToFlex(wins: Int, x: Int) -> String {
        "Keep my \(wins) days · switch to \(x) of \(x + 5) days"
    }
    public static func rescueReasonOOR(need: Int, daysLeft: Int) -> String {
        "You need \(need) more wins, but only \(daysLeft) days are left."
    }
    public static func rescueReasonStreak(day: Int) -> String {
        "You missed day \(day). Your streak is back to 0."
    }
    public static func toastExtended(days: Int, date: String) -> String {
        "Extended by \(days) day\(days == 1 ? "" : "s"). Ends \(date)."
    }
    public static let toastRestarted = "Restarted from today."
    public static func toastSwitched(x: Int, y: Int) -> String { "Switched to \(x) of \(y) days." }
    public static let toastScrapped = "Scrapped. Your rewards are kept."

    // MARK: - Notifications (SPEC §10)
    public static func nudgeTitle(_ name: String, _ remaining: String) -> String {
        "\(name) · \(remaining) to go"
    }
    public static func nudgeSteps(minutes: Int, win: String) -> String {
        "A \(minutes)-minute walk\(win)."
    }
    public static func nudgeRun(target: String, win: String) -> String {
        "One \(target) km run\(win)."
    }
    public static func nudgeRings(win: String) -> String { "Close your rings\(win)." }
    public static func nudgeExercise(left: Int, win: String) -> String {
        "\(left) minutes of exercise\(win)."
    }
    public static func nudgeCalories(left: Int, win: String) -> String {
        "Burn \(left) kcal\(win)."
    }
    public static func nudgeWinMoney(_ amount: String) -> String { " wins \(amount) today" }
    public static let nudgeWinDay = " wins the day"
    public static func notifDayWonBody(_ amount: String) -> String { "Day won. \(amount)" }
    public static func notifCompleteBody(_ reward: String) -> String {
        "Challenge complete. \(reward) is yours."
    }
    public static let notifOutOfReachBody = "Out of reach. Tap to fix."

    // MARK: - Wonday welcome + onboarding (onboarding.txt)
    // Screen 0 — Welcome
    public static let onbHeadline1 = "Reward"
    public static let onbHeadline2 = "yourself"
    public static let onbHeadline3 = "for moving."
    public static let onbIntro = "Set a health goal. Choose your reward. Win the day."
    public static let onbScore = "We only keep the score."
    public static let onbPay = "You pay for your rewards."
    public static let onbGetStarted = "Get started"
    public static let onbNoSignup = "No sign-up"
    public static let onbNoAccount = "No account"
    public static let onbNoServer = "No server"
    public static let onbYourReward = "YOUR REWARD"
    public static let onbStamp = "wonday ✓"

    // Header
    public static let onbSkip = "Skip"
    public static let onbNext = "Next"
    public static let onbBack = "Back"
    public static func onbProgress(_ part: Int) -> String { "Step \(part) of 3" }

    // Screen 1 — Walk to unlock (demo only; never reads Health or saves a win)
    public static func onbWalkTitle(_ target: String) -> String { "Walk \(target) steps" }
    public static let onbWalkSub = "to unlock your reward."
    public static let onbStepsUnit = "steps"
    public static let onbHoldToWalk = "Hold to walk"
    public static let onbHoldHint = "Press and hold."
    public static let onbCompleteWalk = "Complete the walk"
    public static let onbRewardUnlocked = "REWARD UNLOCKED"

    // Screen 2 — Apple Health
    public static let onbHealthTitle = "Connect Apple Health"
    public static let onbHealthSub = "wonday reads your activity to check your goal.\nIt never writes, uploads or shares your data."
    public static let onbYourGoal = "YOUR GOAL"
    public static let onbHealthNote = "Read only. Stays on this iPhone."
    public static let onbActiveCalories = "Active calories"
    public static let onbConnected = "Connected ✓"
    public static let onbManualToast = "OK. Tap “Log today” to add your activity."

    // Screen 3 — Notifications
    public static let onbNotifTitle1 = "A nudge,"
    public static let onbNotifTitle2 = "not spam."
    public static let onbNotifSub = "Only when a win is close, or when you win."
    public static let onbNotifLockTime = "8:00"
    public static let onbNotifLockDate = "Tuesday, 20 October"
    public static let onbSample1Title = "4 hours left"
    public static let onbSample1Body = "2,158 steps to make today a wonday."
    public static let onbSample2Title = "That’s a wonday! ✓"
    public static let onbSample2Body = "10 of 20 done. ₹10,000 is getting closer."
    public static let onbAllow = "Allow notifications"
    public static let onbAllowed = "Allowed ✓"
    public static let onbNotNow = "Not now"

    // Screen 4 — You're set
    public static let onbSetTitle = "You're set."
    public static let onbSetSub = "Start with this challenge,\nor make your own."
    public static let onbFirstChallenge = "YOUR FIRST CHALLENGE"
    public static let onbFirstChallengeName = "October 10K"
    public static let onbFirstSentence = "I'll walk 10,000 steps a day on 20 of 30 days to win ₹10,000 for each wonday."
    public static let onbStartThis = "Start this challenge"
    public static let onbMakeOwn = "Make my own"
    public static let onbStartedToast = "Challenge started. Go make it a wonday!"

    // Health permission rows (the switches are display only)
    public static let healthSteps = "Steps"
    public static let healthRings = "Activity rings"
    public static let healthExercise = "Exercise minutes"
    public static let healthWorkouts = "Workouts and distance"
    public static let healthSleep = "Sleep"

    // MARK: - Settings (SPEC §7.11)
    public static let settings = "Settings"
    public static let connectHealth = "Connect Apple Health"
    public static let logByHand = "Not now, I'll log manually"
    public static let logByHandSetting = "Log manually"
    public static let backup = "Back up to iCloud"
    public static let replayWelcome = "Replay welcome"
    public static let settingsFooter = "wonday keeps your activity on this iPhone. It never uploads or shares Health data."
    public static func nudgeTime(_ hour: Int, _ minute: Int) -> String {
        String(format: "Nudge time: %d:%02d", hour, minute)
    }

    // MARK: - Toasts
    public static let challengeStarted = "Challenge started."
    public static let challengeStartedManual = "Challenge started. Every challenge now uses Log today."

    // MARK: - Accessibility labels (proposed)
    public static let close = "Close"
    public static let settingsLabel = "Settings"
    public static let newChallengeLabel = "New challenge"
    public static let overviewAllChallenges = "All challenges"
    public static let decrease = "Decrease"
    public static let increase = "Increase"
}
