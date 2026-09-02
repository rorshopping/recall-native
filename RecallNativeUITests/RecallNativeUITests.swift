import XCTest

final class RecallNativeUITests: XCTestCase {
    func testPrimaryNavigationIsAccessible() {
        let app = XCUIApplication()
        app.launch()

        let home = app.buttons["tab.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 10))

        for identifier in ["tab.decks", "tab.create", "tab.stats", "tab.settings"] {
            XCTAssertTrue(app.buttons[identifier].waitForExistence(timeout: 5), "Missing accessibility identifier: \(identifier)")
        }
    }

    func testPrimaryTabsCanBeSelected() {
        let app = XCUIApplication()
        app.launch()

        let tabs = ["tab.decks", "tab.create", "tab.stats", "tab.settings", "tab.home"]
        for identifier in tabs {
            let tab = app.buttons[identifier]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "Tab not available: \(identifier)")
            tab.tap()
        }
    }
}
