import XCTest

// Headless visual verification: drives the real app in the simulator and
// attaches screenshots to the xcresult (extract with xcresulttool).
final class CreateFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
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

    func test_createFlow() throws {
        shot("01-launch")
        // Fresh install starts onboarding; repeat runs land on Overview.
        if app.buttons["Get started"].waitForExistence(timeout: 3) {
            tap("Get started")
            tap("Next") // deal
            tap("Next") // trophy
            tap("Next") // privacy
            tap("Not now, I'll log by hand") // health → manual mode
            tap("Not now") // notifications
            tap("Explore the demo first") // you're set
        }
        shot("02-overview-empty")
        tap("New challenge") // bottom bar +
        shot("03-create-empty")
        // C02: locked blank first → hint, no panel
        tap("your reward")
        XCTAssertTrue(app.staticTexts["First set \"what you'll do\"."].waitForExistence(timeout: 3))
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
        tap("Challenges")
        shot("11-overview-band")
    }

    func test_debugWhatPanel() throws {
        if app.buttons["Get started"].waitForExistence(timeout: 3) {
            tap("Get started")
            tap("Next"); tap("Next"); tap("Next")
            tap("Not now, I'll log by hand")
            tap("Not now")
            tap("Explore the demo first")
        }
        tap("New challenge")
        tap("what you'll do")
        print("HITTABLE Steps=\(app.buttons["Steps"].isHittable) Increase=\(app.buttons["Increase"].isHittable) Done=\(app.buttons["Done"].isHittable)")
        // Airtight tap test: Increase must change TARGET text.
        tap("Increase")
        XCTAssertTrue(app.staticTexts["10,500 steps a day"].waitForExistence(timeout: 3))
        // Done must mark blank 0: HowOften opens, main button counts down, pill appears.
        tap("Done")
        sleep(2)
        print("AFTER-DONE flex=\(app.buttons["Flexible, X of Y days"].exists) twoBlanks=\(app.buttons["Fill in 2 blanks"].exists) pill=\(app.buttons["walk 10,000 steps"].exists) threeBlanks=\(app.buttons["Fill in 3 blanks"].exists)")
        print("TREE-AFTER-DONE-START")
        print(app.debugDescription)
        print("TREE-AFTER-DONE-END")
    }
}
