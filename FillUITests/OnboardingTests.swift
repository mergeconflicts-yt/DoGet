import XCTest

// Drives the Wonday welcome + onboarding flow and attaches screenshots for
// visual review. Each test starts from the welcome screen.
@MainActor
final class OnboardingTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() {
        app = XCUIApplication()
        app.launchArguments = ["-uiTestResetOnboarding"]
        app.launch()
    }

    private func tap(_ label: String, timeout: TimeInterval = 6,
                     file: StaticString = #filePath, line: UInt = #line) {
        let el = app.buttons[label]
        XCTAssertTrue(el.waitForExistence(timeout: timeout), "missing button \(label)",
                      file: file, line: line)
        // Animated buttons (Next, Start) exist before they fade in; wait
        // until hittable so the tap isn't dropped.
        let deadline = Date().addingTimeInterval(timeout)
        while !el.isHittable && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertTrue(el.isHittable, "button \(label) not hittable",
                      file: file, line: line)
        el.tap()
    }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func toYoureSet() {
        tap("Get started")
        walkUnlock() // Walk demo → Apple Health (no Skip in v1)
        tap("Not now, I'll log manually")
        tap("Not now") // notifications
        XCTAssertTrue(app.buttons["Start this challenge"].waitForExistence(timeout: 8))
        sleep(2)
    }

    /// Hold to walk until the reward unlocks, then go Next.
    private func walkUnlock() {
        XCTAssertTrue(app.buttons["Hold to walk"].waitForExistence(timeout: 4))
        app.buttons["Hold to walk"].press(forDuration: 3.0)
        XCTAssertTrue(app.staticTexts["REWARD UNLOCKED"].waitForExistence(timeout: 6))
        sleep(2) // let Next fade in
        tap("Next")
    }

    func test_welcomeAndMakeMyOwn() {
        launch()
        XCTAssertTrue(app.staticTexts["Reward yourself for moving."].waitForExistence(timeout: 6))
        shot("onb-01-welcome")
        tap("Get started")
        XCTAssertTrue(app.staticTexts["Walk 10,000 steps"].waitForExistence(timeout: 4))
        shot("onb-02-walk")
        walkUnlock()
        XCTAssertTrue(app.staticTexts["Connect Apple Health"].waitForExistence(timeout: 4))
        shot("onb-03-health")
        tap("Not now, I'll log manually")
        XCTAssertTrue(app.staticTexts["A nudge, not spam."].waitForExistence(timeout: 4))
        shot("onb-04-notifications")
        tap("Not now")
        XCTAssertTrue(app.staticTexts["You're set."].waitForExistence(timeout: 6))
        sleep(2)
        shot("onb-05-set")
        tap("Make my own")
        XCTAssertTrue(app.buttons["what you'll do"].waitForExistence(timeout: 6))
        shot("onb-06-create-fresh")
    }

    func test_walkUnlockAndStartChallenge() {
        launch()
        tap("Get started")
        XCTAssertTrue(app.buttons["Hold to walk"].waitForExistence(timeout: 4))
        app.buttons["Hold to walk"].press(forDuration: 3.0)
        XCTAssertTrue(app.staticTexts["REWARD UNLOCKED"].waitForExistence(timeout: 6))
        shot("onb-07-unlocked")
        sleep(2) // let Next + rows fade in
        tap("Next")
        tap("Not now, I'll log manually")
        tap("Not now")
        XCTAssertTrue(app.buttons["Start this challenge"].waitForExistence(timeout: 8))
        sleep(2)
        tap("Start this challenge")
        sleep(1)
        shot("onb-08-after-start")
        // Pager with the new challenge (toast is transient; shot above
        // captures it for visual review).
        XCTAssertTrue(app.buttons["All challenges"].waitForExistence(timeout: 8))
        shot("onb-08-first-challenge")
        tap("All challenges")
        // Overview In progress lists the new first challenge.
        XCTAssertTrue(app.staticTexts["October 10K"].waitForExistence(timeout: 5))
    }
}
