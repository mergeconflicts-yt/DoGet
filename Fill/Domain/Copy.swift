import Foundation

/// Copy deck reconstructed from SPEC body + design-mockups verbatim.
/// [GAP] SPEC §12 / COPY.md missing in repo — strings below are the exact
/// quotes found in SPEC §§7–10 + mockup photos. Flagged proposals kept.
public enum Copy {
    // Overview
    public static let today = "Today"
    public static let rewardsClaimed = "Rewards claimed"
    public static let seeAll = "See all"
    public static let noChallenges = "No challenges yet."
    public static let firstChallenge = "Make your first challenge"
    public static let allChallenges = "Challenges"
    /// [GAP] Challenges section headers have no SPEC text;
    /// proposed, needs product review.
    public static let sectionInProgress = "In progress"
    public static let sectionCompleted = "Completed"
    public static let sectionEmptyInProgress = "No challenges in progress."
    public static let sectionEmptyCompleted = "No completed challenges yet."

    // Challenge page
    public static let outOfReach = "OUT OF REACH"
    public static let streakBroken = "STREAK BROKEN"
    public static let completed = "COMPLETED"
    public static let rewarded = "REWARDED"
    public static let todayWon = "TODAY · WON"
    public static let byHand = "· BY HAND"
    public static let byHandShort = "✎ by hand"
    public static let firstWin = "YOUR FIRST WIN"
    public static let seeTrophy = "See your trophy"

    // Day won / celebration
    public static let dayWon = "DAY WON"
    public static let challengeComplete = "CHALLENGE COMPLETE"
    public static let claimReward = "Claim reward"
    public static let rewardedCheck = "Rewarded ✓"
    public static let isYours = "is yours"

    // Create
    public static let newChallenge = "NEW CHALLENGE"
    public static let mostYouCanWin = "MOST YOU CAN WIN"
    public static let ends = "ENDS"
    public static let missesAllowed = "MISSES ALLOWED"
    /// [GAP] SPEC §7.6 "The toast is different in manual mode" — text not in
    /// SPEC/mockups (COPY.md missing); proposed, needs product review.
    public static let challengeStarted = "Challenge started."
    public static let challengeStartedManual = "Challenge started. Log today to keep score."
    public static let whatYouWillDo = "What you'll do"
    public static let howOften = "How often"
    public static let yourReward = "Your reward"
    public static let needsAppleWatch = "Needs Apple Watch"

    // Challenge page footer (SPEC §7.3 item 11)
    public static let earned = "EARNED"
    public static let nextWin = "NEXT WIN"
    public static let savedTowardIt = "SAVED TOWARD IT"
    public static let rewardAtTheEnd = "REWARD AT THE END"
    public static let reward = "REWARD"
    public static let worth = "WORTH"
    public static let missADay = "MISS A DAY"
    public static let backToZero = "Back to 0"
    public static func imDoneClaim(_ name: String) -> String {
        "I'm done · claim \(name)"
    }
    /// [GAP] Hero line for a broken streak (SPEC §7.3 item 8 "broken … own
    /// line", text not given); proposed, needs product review.
    public static func brokenLine(_ day: Int) -> String {
        "Broken on day \(day)."
    }

    // Rescue
    public static let rescueOOR = "Out of reach"
    public static func extend(days: Int, date: String) -> String {
        "Extend by \(days) day\(days == 1 ? "" : "s") · ends \(date)"
    }

    // Log today
    public static let logToday = "Log today"
    /// [GAP] Manual-mode today pill text; proposed, needs product review.
    public static let logProgress = "TODAY · LOG YOUR PROGRESS"
    public static let saved = "Saved."

    // Onboarding (SPEC §7.10 + mockups)
    public static let rewardYourself = "Reward yourself"
    public static let toMove = "to move."
    public static let dealLine = "You set the goal. You choose the reward. We keep score. You pay for your rewards."
    public static let getStarted = "Get started"
    public static let noSignup = "No sign-up"
    public static let noAccount = "No account"
    public static let noServer = "No server"
    public static let makeDeal = "You make the deal."
    public static let winItClaimIt = "Win it. Claim it."
    public static let nudgeTitle = "A nudge before the day ends."
    public static let youreSet = "You're set."
    public static let makeFirst = "Make my first challenge"
    public static let exploreDemo = "Explore the demo first"
    public static let connectHealth = "Connect Apple Health"
    public static let logByHand = "Not now, I'll log by hand"
    public static let allowNotifs = "Allow notifications"
    public static let notNow = "Not now"

    // Share (no SPEC text; user-initiated system sheet, on-device only).
    // Proposed, needs product review.
    public static let shareProgress = "Share progress"
    public static let playingFor = "Playing for"
    public static let viaFill = "via fill."
    public static let shareCaption = "Look at my progress!"
    /// [GAP] No App Store URL yet — paste the real link; the shared message
    /// omits the link until this parses as a URL.
    public static let appStoreLink = ""
}
