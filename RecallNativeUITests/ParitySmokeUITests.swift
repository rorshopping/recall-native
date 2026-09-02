import XCTest

final class ParitySmokeUITests: XCTestCase {
    func testSettingsAndCreateSurfacesAreReachable() {
        let app = XCUIApplication()
        app.launch()

        let settings = app.buttons["tab.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Appearance"].exists)
        XCTAssertTrue(app.staticTexts["Study"].exists)
        XCTAssertTrue(app.staticTexts["Sync"].exists)
        XCTAssertTrue(app.staticTexts["Backup"].exists)
        XCTAssertTrue(app.staticTexts["On-device AI"].exists)
        XCTAssertTrue(app.staticTexts["About"].exists)

        let create = app.buttons["tab.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        create.tap()

        XCTAssertTrue(app.navigationBars["Create"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["What do you want to study?"].exists)
        XCTAssertTrue(app.staticTexts["On-device AI"].exists)
        XCTAssertTrue(app.buttons["Create flashcards"].exists)
    }
}
