import XCTest

final class RecallNativeUITests: XCTestCase {
    private let tabIdentifiers = [
        "tab.decks",
        "tab.create",
        "tab.stats",
        "tab.settings",
    ]

    func testPrimaryNavigationIsAccessible() {
        let app = XCUIApplication()
        app.launch()

        for identifier in tabIdentifiers {
            XCTAssertTrue(
                app.buttons[identifier].waitForExistence(timeout: 10),
                "Missing accessibility identifier: \(identifier)"
            )
        }
    }

    func testPrimaryTabsCanBeSelected() {
        let app = XCUIApplication()
        app.launch()

        for identifier in tabIdentifiers {
            let tab = app.buttons[identifier]
            XCTAssertTrue(tab.waitForExistence(timeout: 10), "Tab not available: \(identifier)")
            tab.tap()
        }
    }
}
