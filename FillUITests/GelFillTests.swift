import XCTest

// Gel proof: presses the welcome fill off-center and captures the ripple
// mid-life via simctl (XCTAttachments stay in the xcresult; this file lands
// where it can be eyeballed directly).
@MainActor
final class GelFillTests: XCTestCase {
    var app: XCUIApplication!

    func test_gelRippleAtPress() throws {
        app = XCUIApplication()
        app.terminate()
        app.launchArguments += ["-FillShot", "welcome"]
        app.launch()
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.5) // gel risen, before the 2.3s roll
        // Just under the surface, clear of controls: full-strength dent.
        app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.30, dy: 0.46))
            .tap()
        Thread.sleep(forTimeInterval: 0.15) // dent near max depth
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "ripple"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func test_manualPillOpensLogSheet() throws {
        let manual = XCUIApplication()
        manual.launchArguments += ["-FillShot", "challenge-manual"]
        manual.launch()
        let pill = manual.buttons.containing(
            NSPredicate(format: "label BEGINSWITH 'Log today'")).firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 10))
        pill.tap()
        XCTAssertTrue(manual.staticTexts["Log today"].waitForExistence(timeout: 5))
    }
}
