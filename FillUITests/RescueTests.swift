import XCTest

// Rescue dismissal: on the real pager, picking a rescue option must rebuild
// snapshots so the card disappears (it used to stay until restart).
final class RescueTests: XCTestCase {
    func test_rescueExtendDismissesCard() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-FillShot", "pager-oor"]
        app.launch()
        let band = app.buttons["October 10K, tap to fix"]
        XCTAssertTrue(band.waitForExistence(timeout: 10))
        band.tap()
        let extend = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Extend by'")).firstMatch
        XCTAssertTrue(extend.waitForExistence(timeout: 5))
        extend.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Extended by'")).firstMatch.waitForExistence(timeout: 5))
        let title = app.staticTexts["Out of reach"]
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: title)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "rescue card stayed after Extend")
    }
}
