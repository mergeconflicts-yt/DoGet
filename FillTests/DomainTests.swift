import Testing
import Foundation
#if SWIFT_PACKAGE
@testable import FillDomain
#endif

// "Today" = 19 Oct 2026, en-IN. Helpers below.

func cal() -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    return c
}
func noon(_ k: DayKey) -> Date {
    var c = cal(); var comp = DateComponents()
    comp.year = k.year; comp.month = k.month; comp.day = k.day; comp.hour = 12
    return c.date(from: comp)!
}
let today = DayKey(year: 2026, month: 10, day: 19)

func flexChallenge(start: DayKey, target: Double = 10_000, x: Int = 20, y: Int = 30,
                   reward: Reward = .moneyEach(amount: 10_000)) -> Challenge {
    Challenge(name: "October 10K", colorToken: "orange", metric: .steps,
              target: target, type: .flex, x: x, y: y, start: start, reward: reward)
}
/// Build day results: wins = first `w` days won (value=target), misses next `m` (value=0).
func days(start: DayKey, w: Int, m: Int, target: Double, todayValue: Double) -> [DayResult] {
    var out: [DayResult] = []
    for i in 0..<(w + m) {
        let v = i < w ? target : 0.0
        out.append(DayResult(date: start.adding(days: i), value: v, isFinal: true))
    }
    out.append(DayResult(date: today, value: todayValue))
    return out
}

@Suite("Engine A01-A33")
struct EngineTests {
    // A01: F(20/30) d13 W9 M3 today 7,842
    @Test func test_A01_midProgress() {
        let start = today.adding(days: -12) // d13
        let c = flexChallenge(start: start)
        let s = Engine.snapshot(challenge: c, days: days(start: start, w: 9, m: 3, target: 10_000, todayValue: 7_842),
                                now: noon(today), calendar: cal())
        #expect(s.need == 11)
        #expect(s.daysLeft == 18)
        #expect(s.missesAllowed == 7)
        #expect(abs(s.base - 0.45) < 0.001)
        #expect(abs(s.layer - 0.7842 / 20) < 0.001)
        #expect(!s.outOfReach)
    }
    @Test func test_A02_todayWin() {
        let start = today.adding(days: -12)
        let c = flexChallenge(start: start)
        let s = Engine.snapshot(challenge: c, days: days(start: start, w: 9, m: 3, target: 10_000, todayValue: 10_000),
                                now: noon(today), calendar: cal())
        #expect(s.todayWon)
        #expect(s.wins == 10)
        #expect(s.need == 10)
        #expect(s.daysLeft == 17)
        #expect(s.layer == 0)
    }
    @Test func test_A03_justShort() {
        let start = today.adding(days: -12)
        let c = flexChallenge(start: start)
        let s = Engine.snapshot(challenge: c, days: days(start: start, w: 9, m: 3, target: 10_000, todayValue: 9_999),
                                now: noon(today), calendar: cal())
        #expect(!s.todayWon)
    }
    @Test func test_A04_newChallenge() {
        let c = flexChallenge(start: today)
        let s = Engine.snapshot(challenge: c, days: [DayResult(date: today, value: 0)],
                                now: noon(today), calendar: cal())
        #expect(s.need == 20 && s.daysLeft == 30 && s.base == 0 && s.layer == 0)
    }
    @Test func test_A05_outOfReach() {
        let start = DayKey(year: 2026, month: 9, day: 29) // d21, ends 28 Oct
        let c = flexChallenge(start: start)
        let s = Engine.snapshot(challenge: c, days: days(start: start, w: 9, m: 11, target: 10_000, todayValue: 0),
                                now: noon(today), calendar: cal())
        #expect(s.daysLeft == 10 && s.need == 11 && s.outOfReach && s.extendBy == 1)
    }
    @Test func test_A06_extend() {
        let start = DayKey(year: 2026, month: 9, day: 29)
        let c = flexChallenge(start: start)
        let ext = Derive.extended(c, by: 1)
        let s = Engine.snapshot(challenge: ext, days: days(start: start, w: 9, m: 11, target: 10_000, todayValue: 0),
                                now: noon(today), calendar: cal())
        #expect(ext.y == 31)
        #expect(!s.outOfReach)
        #expect(s.endDate == DayKey(year: 2026, month: 10, day: 29))
    }
    @Test func test_A07_flexWinDoesNotTriggerOutOfReach() {
        let start = today.adding(days: -28) // d29
        let c = flexChallenge(start: start)
        var d = days(start: start, w: 18, m: 10, target: 10_000, todayValue: 10_000)
        let s = Engine.snapshot(challenge: c, days: d, now: noon(today), calendar: cal())
        #expect(s.wins == 19 && s.need == 1 && s.daysLeft == 1 && !s.outOfReach)
    }
    @Test func test_A08_finalWinCompletes() {
        let start = today.adding(days: -29) // d30
        let c = flexChallenge(start: start)
        let s = Engine.snapshot(challenge: c, days: days(start: start, w: 19, m: 10, target: 10_000, todayValue: 10_000),
                                now: noon(today), calendar: cal())
        #expect(s.wins == 20 && s.done && s.base == 1)
    }
    @Test func test_A09_streakProgress() {
        // S(30) d19 W18 consecutive rings 3, today 2
        var c = Challenge(name: "Kyoto", colorToken: "violet", metric: .rings, target: 3,
                          type: .streak, x: 30, y: 30, start: today.adding(days: -18),
                          reward: Reward(kind: .item, category: .trip, name: "Kyoto", value: 0, itemPayout: .end))
        var ds: [DayResult] = []
        for i in 0..<18 { ds.append(DayResult(date: c.start.adding(days: i), value: 3, isFinal: true)) }
        ds.append(DayResult(date: today, value: 2))
        let s = Engine.snapshot(challenge: c, days: ds, now: noon(today), calendar: cal())
        #expect(s.need == 12 && !s.done && s.streakBrokenOnDay == nil)
        #expect(s.endDate == DayKey(year: 2026, month: 10, day: 30))
    }
    @Test func test_A10_streakBroken() {
        var c = Challenge(name: "K", colorToken: "violet", metric: .steps, target: 10_000,
                          type: .streak, x: 30, y: 30, start: today.adding(days: -18),
                          reward: .moneyEach(amount: 1000))
        var ds: [DayResult] = []
        for i in 0..<18 {
            ds.append(DayResult(date: c.start.adding(days: i), value: i == 4 ? 0 : 10_000, isFinal: true))
        }
        ds.append(DayResult(date: today, value: 0))
        let s = Engine.snapshot(challenge: c, days: ds, now: noon(today), calendar: cal())
        #expect(s.streakBrokenOnDay == 5 && s.layer == 0)
    }
    @Test func test_A11_switchToFlexKeepsWins() {
        let c = Challenge(name: "K", colorToken: "violet", metric: .steps, target: 10_000,
                          type: .streak, x: 30, y: 30, start: today.adding(days: -18),
                          reward: .moneyEach(amount: 1000))
        var ds: [DayResult] = []
        for i in 0..<18 {
            ds.append(DayResult(date: c.start.adding(days: i), value: i == 4 ? 0 : 10_000, isFinal: true))
        }
        ds.append(DayResult(date: today, value: 0))
        let before = Engine.snapshot(challenge: c, days: ds, now: noon(today), calendar: cal())
        let flex = Derive.switchedToFlex(c)
        let s = Engine.snapshot(challenge: flex, days: ds, now: noon(today), calendar: cal())
        #expect(flex.type == .flex && flex.x == 30 && flex.y == 35)
        #expect(s.wins == before.wins)
        #expect(s.streakBrokenOnDay == nil)
    }
    @Test func test_A12_onceProgress() {
        let c = Challenge(name: "HM", colorToken: "blue", metric: .run, target: 21.1,
                          type: .once, x: 1, y: 0, start: today.adding(days: -10),
                          reward: Reward(kind: .money, payout: .end, amount: 50_000))
        let s = Engine.snapshot(challenge: c, days: [], best: 14.2, now: noon(today), calendar: cal())
        #expect(abs(s.base - 14.2 / 21.1) < 0.002 && s.layer == 0 && !s.done)
    }
    @Test func test_A13_onceDone() {
        let c = Challenge(name: "HM", colorToken: "blue", metric: .run, target: 21.1,
                          type: .once, x: 1, y: 0, start: today,
                          reward: Reward(kind: .money, payout: .end, amount: 50_000))
        // Today's run counts as the best attempt (the old test passed best in
        // directly, so it never exercised the engine's today handling).
        let s = Engine.snapshot(challenge: c,
                                days: [DayResult(date: today, value: 21.1)],
                                now: noon(today), calendar: cal())
        #expect(s.best == 21.1 && s.done)
    }
    @Test func test_A14_jarProgress() {
        let c = Challenge(name: "Jar", colorToken: "green", metric: .steps, target: 8_000,
                          type: .open, x: 0, y: 0, start: today.adding(days: -100),
                          reward: Reward(kind: .money, payout: .jar, amount: 1_000, jarTarget: 200_000))
        var ds: [DayResult] = []
        for i in 0..<86 { ds.append(DayResult(date: c.start.adding(days: i), value: 8_000, isFinal: true)) }
        ds.append(DayResult(date: today, value: 0))
        let s = Engine.snapshot(challenge: c, days: ds, now: noon(today), calendar: cal())
        #expect(abs(s.base - 0.43) < 0.005)
        #expect(s.moneyLeft == 200_000)
    }
    @Test func test_A15_jarDoneOnWin() {
        let c = Challenge(name: "Jar", colorToken: "green", metric: .steps, target: 8_000,
                          type: .open, x: 0, y: 0, start: today.adding(days: -199),
                          reward: Reward(kind: .money, payout: .jar, amount: 1_000, jarTarget: 200_000))
        var ds: [DayResult] = []
        for i in 0..<199 {
            ds.append(DayResult(date: c.start.adding(days: i), value: 8_000, isFinal: true))
        }
        ds.append(DayResult(date: today, value: 8_000))
        let s = Engine.snapshot(challenge: c, days: ds, now: noon(today), calendar: cal())
        #expect(s.wins == 200 && s.done)
    }
    @Test func test_A16_openEachNeverDone() {
        let c = Challenge(name: "N", colorToken: "teal", metric: .steps, target: 10_000,
                          type: .open, x: 0, y: 0, start: today.adding(days: -10),
                          reward: .moneyEach(amount: 1_000))
        var ds: [DayResult] = []
        for i in 0..<6 { ds.append(DayResult(date: c.start.adding(days: i), value: 10_000, isFinal: true)) }
        ds.append(DayResult(date: today, value: 0))
        let s = Engine.snapshot(challenge: c, days: ds, now: noon(today), calendar: cal())
        #expect(s.moneyEarned == 6_000 && s.moneyLeft == 0 && !s.done)
    }
    @Test func test_A17_openItemDoneOnClose() {
        var c = Challenge(name: "Bike", colorToken: "teal", metric: .steps, target: 10_000,
                          type: .open, x: 0, y: 0, start: today,
                          reward: Reward(kind: .item, category: .item, name: "Bike", itemPayout: .end))
        c.closed = true
        let s = Engine.snapshot(challenge: c, days: [], now: noon(today), calendar: cal())
        #expect(s.done)
    }
    @Test func test_A18_eachMoney() {
        let start = today.adding(days: -12)
        let c = flexChallenge(start: start)
        let s = Engine.snapshot(challenge: c, days: days(start: start, w: 9, m: 3, target: 10_000, todayValue: 0),
                                now: noon(today), calendar: cal())
        #expect(s.moneyEarned == 90_000 && s.moneyLeft == 110_000)
    }
    @Test func test_A21_moneyEndNotYetEarned() {
        let start = today.adding(days: -12)
        let c = flexChallenge(start: start,
                              reward: Reward(kind: .money, payout: .end, amount: 50_000))
        let s = Engine.snapshot(challenge: c,
                                days: days(start: start, w: 2, m: 1, target: 10_000, todayValue: 0),
                                now: noon(today), calendar: cal())
        #expect(s.moneyEarned == 0 && s.moneyLeft == 50_000)
    }
    @Test func test_A19_bonusUnclaimed() {
        let start = today.adding(days: -20)
        var c = flexChallenge(start: start, reward: Reward(kind: .money, payout: .bonus, amount: 1_000, bonus: 10_000))
        var ds: [DayResult] = []
        for i in 0..<20 { ds.append(DayResult(date: start.adding(days: i), value: 10_000, isFinal: true)) }
        let s = Engine.snapshot(challenge: c, days: ds, now: noon(today), calendar: cal())
        #expect(s.done && s.moneyEarned == 20_000 && s.moneyLeft == 10_000)
    }
    @Test func test_A20_bonusClaimed() {
        let start = today.adding(days: -20)
        var c = flexChallenge(start: start, reward: Reward(kind: .money, payout: .bonus, amount: 1_000, bonus: 10_000))
        c.claimed = true
        var ds: [DayResult] = []
        for i in 0..<20 { ds.append(DayResult(date: start.adding(days: i), value: 10_000, isFinal: true)) }
        let s = Engine.snapshot(challenge: c, days: ds, now: noon(today), calendar: cal())
        #expect(s.moneyEarned == 30_000 && s.moneyLeft == 0)
    }
    @Test func test_A22_itemPerWin() {
        #expect(Derive.itemPerWin(value: 700_000, x: 70) == 10_000)
    }
    @Test func test_A23_itemSaveRemainder() {
        #expect(Derive.itemPerWin(value: 500_000, x: 30) == 16_667)
        #expect(Derive.itemSaved(value: 500_000, x: 30, wins: 29) == 483_343)
        #expect(Derive.itemSaved(value: 500_000, x: 30, wins: 30) == 500_000)
        #expect(Derive.itemNextWin(value: 500_000, x: 30, wins: 29) == 16_657)
    }
    @Test func test_A24_dayIndexCalendarOnly() {
        let start = today.adding(days: -12)
        let c = flexChallenge(start: start)
        let a = Engine.snapshot(challenge: c, days: days(start: start, w: 9, m: 3, target: 10_000, todayValue: 0),
                                now: noon(today), calendar: cal())
        let b = Engine.snapshot(challenge: c, days: days(start: start, w: 9, m: 3, target: 10_000, todayValue: 10_000),
                                now: noon(today), calendar: cal())
        #expect(a.dayIndex == b.dayIndex)
    }
    @Test func test_A28_levelUpSteps() {
        let c = flexChallenge(start: today)
        let next = Derive.levelUp(c, today: today)
        #expect(next?.target == 11_000)
        #expect(next?.name == "October 10K · Level 2")
        #expect(next?.level == 2)
        #expect(next?.claimed == false)
    }
    @Test func test_A29_levelUpRings() {
        let c = Challenge(name: "Rings", colorToken: "violet", metric: .rings, target: 2,
                          type: .streak, x: 30, y: 30, start: today, reward: .moneyEach(amount: 1_000))
        #expect(Derive.levelUp(c, today: today)?.target == 3)
    }
    @Test func test_A30_levelUpRun() {
        let c = Challenge(name: "Run", colorToken: "blue", metric: .run, target: 5,
                          type: .once, x: 1, y: 0, start: today,
                          reward: Reward(kind: .money, payout: .end, amount: 1_000))
        #expect(Derive.levelUp(c, today: today)?.target == 5.5)
    }
    @Test func test_A31_levelUpRingsAtThreeNotOffered() {
        let c = Challenge(name: "Rings", colorToken: "violet", metric: .rings, target: 3,
                          type: .streak, x: 30, y: 30, start: today, reward: .moneyEach(amount: 1_000))
        #expect(Derive.levelUp(c, today: today) == nil)
    }
    @Test func test_A32_futureDayIgnored() {
        let start = today.adding(days: -5)
        let c = flexChallenge(start: start)
        var ds = days(start: start, w: 2, m: 3, target: 10_000, todayValue: 0)
        // Device moved west: a row for tomorrow exists.
        ds.append(DayResult(date: today.adding(days: 1), value: 10_000, isFinal: false))
        let s = Engine.snapshot(challenge: c, days: ds, now: noon(today), calendar: cal())
        #expect(s.wins == 2)
        #expect(s.todayWon == false)
    }
    @Test func test_A33_dayKeyDST() {
        var london = Calendar(identifier: .gregorian)
        london.timeZone = TimeZone(identifier: "Europe/London")!
        let a = DayKey(year: 2026, month: 10, day: 24)
        let b = DayKey(year: 2026, month: 10, day: 26)
        #expect(a.days(to: b) == 2)
        #expect(a.adding(days: 2) == b)
        // London leaves BST on 25 Oct: both midnights still map to their own
        // calendar day, exactly as in a fixed-offset zone.
        let before = london.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 12))!
        let after = london.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 12))!
        #expect(DayKey.from(date: before, calendar: london) == a)
        #expect(DayKey.from(date: after, calendar: london) == b)
    }
    @Test func test_Format_INR() {
        #expect(Format.money(100_000) == "1,00,000 bucks")
        #expect(Format.money(90_000) == "90,000 bucks")
    }

    // MARK: - Create validation (C01, C09–C11)

    @Test func test_C01_threeBlanks() {
        #expect(Derive.validate(Derive.Draft()) == "Fill in 3 blanks")
    }
    @Test func test_C09_winsMustFitDays() {
        var d = Derive.Draft()
        d.metric = .steps; d.target = 10_000; d.type = .flex
        d.x = 25; d.y = 20
        d.rewardKind = .money; d.moneyPayout = .each; d.amount = 1_000
        #expect(Derive.validate(d) == "Wins must fit in the days")
    }
    @Test func test_C10_jarMustBeBigger() {
        var d = Derive.Draft()
        d.metric = .steps; d.target = 10_000; d.type = .open
        d.rewardKind = .money; d.moneyPayout = .jar; d.amount = 1_000; d.jarTarget = 1_000
        #expect(Derive.validate(d) == "Jar must be bigger")
    }
    @Test func test_C_validMoneyFlex() {
        var d = Derive.Draft()
        d.metric = .steps; d.target = 10_000; d.type = .flex
        d.x = 20; d.y = 30
        d.rewardKind = .money; d.moneyPayout = .each; d.amount = 10_000
        #expect(Derive.validate(d) == nil)
    }
    @Test func test_C_validItemSave() {
        var d = Derive.Draft()
        d.metric = .steps; d.target = 10_000; d.type = .flex
        d.x = 70; d.y = 90
        d.rewardKind = .item; d.itemCategory = .item
        d.itemName = "DGX Spark"; d.itemValue = 700_000; d.itemPayout = .save
        #expect(Derive.validate(d) == nil)
    }
    @Test func test_C_itemNeedsName() {
        var d = Derive.Draft()
        d.metric = .steps; d.target = 10_000; d.type = .flex
        d.x = 20; d.y = 30
        d.rewardKind = .item; d.itemName = "  "
        #expect(Derive.validate(d) == Copy.validationName())
    }
    @Test func test_C_rewardCheckedBeforeTarget() {
        var d = Derive.Draft()
        d.metric = nil; d.target = nil; d.type = .flex
        d.x = 20; d.y = 30
        d.rewardKind = .item; d.itemName = ""
        // Reward is checked before target, but blanks are still first.
        d.metric = .steps
        #expect(Derive.validate(d) == Copy.validationName())
    }

    // MARK: - CreateLogic order lock + flow (C02–C04)

    @Test func test_C02_lockedBlankHint() {
        var m = CreateLogic()
        m.tapBlank(2) // reward before act
        #expect(m.openPanel == nil)
        #expect(m.hint == Copy.lockedHint("what you'll do"))
        #expect(m.shakeBlank == 0)
    }
    @Test func test_C03_fillActOpensRule() {
        var m = CreateLogic()
        m.tapBlank(0)
        #expect(m.openPanel == 0)
        m.draft.metric = .steps; m.draft.target = 10_000
        m.done(0)
        #expect(m.filled == [0])
        #expect(m.openPanel == nil)
        #expect(m.nextUnfilled == 1)
    }
    @Test func test_createStartsWithStepsAndFlexDefaults() {
        let m = CreateLogic()
        #expect(m.draft.metric == .steps)
        #expect(m.draft.target == 10_000)
        #expect(m.draft.type == .flex)
        #expect(m.draft.x == 20 && m.draft.y == 30)
        #expect(!m.filled.contains(0))
    }
    @Test func test_doneWithNoMetricPromptsInsteadOfFilling() {
        var m = CreateLogic()
        m.draft.metric = nil; m.draft.target = nil
        m.tapBlank(0)
        m.done(0) // no metric: must not fill
        #expect(!m.filled.contains(0))
        #expect(m.hint == Copy.pickWhat)
    }
    @Test func test_C04_factsEndsMisses() {
        var m = CreateLogic()
        m.draft.type = .flex; m.draft.x = 20; m.draft.y = 30
        m.refreshFacts()
        #expect(m.factsMisses == "10")
        #expect(m.factsEnds != "—")
        let today = DayKey.from(date: Date(), calendar: .current)
        #expect(m.factsEnds == Format.date(today.adding(days: 29)))
    }
    @Test func test_C_openEachHasNoMaxAndClearsCounts() {
        var m = CreateLogic()
        m.draft.rewardKind = .money
        m.draft.moneyPayout = .each
        m.draft.amount = 1_000
        m.pickType(.flex)
        #expect(m.factsMax == Format.money(20_000))
        m.pickType(.open)
        #expect(m.draft.x == 0 && m.draft.y == 0)
        #expect(m.factsMax == "—")
        #expect(m.factsEnds == Copy.never)
    }
    @Test func test_C_problemToast() {
        var m = CreateLogic()
        #expect(m.problem == "Fill in 3 blanks")
        m.filled = [0, 1, 2]
        m.draft.metric = .steps; m.draft.target = 10_000
        m.draft.type = .flex; m.draft.x = 25; m.draft.y = 20
        m.draft.rewardKind = .money; m.draft.moneyPayout = .each; m.draft.amount = 1_000
        #expect(m.problem == "Wins must fit in the days")
        #expect(!m.valid)
    }
    @Test func test_C_buildReward() {
        var m = CreateLogic()
        m.draft.rewardKind = .money; m.draft.moneyPayout = .bonus
        m.draft.amount = 1_000; m.draft.bonus = 10_000
        let r = m.buildReward()
        #expect(r.kind == .money && r.payout == .bonus && r.amount == 1_000 && r.bonus == 10_000)
    }
    @Test func test_C_itemNameAndChallengeNameStayIndependent() {
        var m = CreateLogic()
        m.draft.itemName = "DGX Spark"
        #expect(m.autoName == "DGX Spark")
        m.name = "My challenge"; m.nameEdited = true
        m.draft.itemName = "Sony A7"
        #expect(m.name == "My challenge")
    }
}
