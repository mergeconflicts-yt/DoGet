import XCTest

// Headless visual verification: drives the real app in the simulator and
// attaches screenshots to the xcresult (extract with xcresulttool).
@MainActor
final class CreateFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    func tap(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let el = app.buttons[label]
        XCTAssertTrue(el.waitForExistence(timeout: 5), "missing button \(label)", file: file, line: line)
        el.tap()
    }

    func shot(_ name: String) {
        let s = app.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    /// Fresh install: five Wonday screens, then a real first challenge.
    /// Returns to Overview so the Create flow can start there.
    func completeOnboardingIfNeeded() {
        guard app.buttons["Get started"].waitForExistence(timeout: 3) else { return }
        tap("Get started")
        XCTAssertTrue(app.buttons["Hold to walk"].waitForExistence(timeout: 4))
        app.buttons["Hold to walk"].press(forDuration: 3.0)
        XCTAssertTrue(app.staticTexts["REWARD UNLOCKED"].waitForExistence(timeout: 6))
        sleep(2)
        tap("Next") // Walk demo → Apple Health (no Skip in v1)
        tap("Not now, I'll log manually")
        tap("Not now") // notifications
        XCTAssertTrue(app.buttons["Start this challenge"].waitForExistence(timeout: 8))
        sleep(2) // let the You're set sequence finish
        tap("Start this challenge")
        XCTAssertTrue(app.buttons["All challenges"].waitForExistence(timeout: 5))
        tap("All challenges")
    }

    func test_createFlow() throws {
        app = XCUIApplication()
        app.launch()
        shot("01-launch")
        completeOnboardingIfNeeded()
        shot("02-overview")
        tap("New challenge") // bottom bar +
        // Wait for the fullScreenCover to finish presenting: tapping while it
        // is still sliding up can use a stale frame and dismiss the cover.
        sleep(2)
        shot("03-create-empty")
        // C02: locked blank first → hint, no panel
        tap("your reward")
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH 'First set'")).firstMatch.waitForExistence(timeout: 3))
        shot("04-create-hint")
        // What you'll do (settle: SwiftUI conditional insert needs a commit
        // before the first tap lands, or the tap is dropped)
        tap("what you'll do")
        sleep(1)
        shot("05-panel-what")
        tap("Steps")
        tap("10K")
        tap("Done")
        // How often auto-opens after 0.38s
        XCTAssertTrue(app.buttons["Flexible, X of Y days"].waitForExistence(timeout: 5))
        sleep(1)
        shot("06-panel-howoften")
        tap("Flexible, X of Y days")
        tap("Done")
        XCTAssertTrue(app.buttons["Money"].waitForExistence(timeout: 5))
        sleep(1)
        shot("07-panel-reward-kind")
        tap("Money")
        sleep(1)
        shot("08-panel-money")
        tap("Each win")
        // amount stepper: tap Increase a few times (₹500 steps)
        let inc = app.buttons["Increase"]
        XCTAssertTrue(inc.waitForExistence(timeout: 3))
        for _ in 0..<4 { inc.tap() }
        tap("Done")
        sleep(1)
        shot("09-create-filled")
        // Facts should show real values now
        tap("Start challenge")
        // New challenge page
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Day 1 of 30'")).firstMatch.waitForExistence(timeout: 5))
        shot("10-challenge-day1")
        // Back to overview via bottom bar
        tap("All challenges")
        shot("11-overview-band")
    }

    func test_debugWhatPanel() throws {
        app = XCUIApplication()
        app.launch()
        completeOnboardingIfNeeded()
        tap("New challenge")
        sleep(2)
        tap("what you'll do")
        sleep(1)
        // Airtight tap test: pick a metric first (nothing is pre-selected),
        // then Increase must change the target stepper.
        // FillStepper exposes value + unit as one button label.
        tap("Steps")
        tap("Increase")
        XCTAssertTrue(app.buttons["10,500 steps a day"].waitForExistence(timeout: 3))
        // Done must mark blank 0: HowOften opens, main button counts down, pill appears.
        tap("Done")
        sleep(2)
        XCTAssertTrue(app.buttons["Flexible, X of Y days"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["walk 10,500 steps"].exists)
    }
}
