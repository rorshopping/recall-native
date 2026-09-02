import XCTest
@testable import RecallNative

final class EntitlementRulesTests: XCTestCase {
    func testFreeUserCanCreateFirstDeckOnly() {
        XCTAssertTrue(EntitlementRules.canCreateDeck(isPremium: false, deckCount: 0))
        XCTAssertFalse(EntitlementRules.canCreateDeck(isPremium: false, deckCount: 1))
    }

    func testPremiumUserCanCreateDeckAtAnyCount() {
        XCTAssertTrue(EntitlementRules.canCreateDeck(isPremium: true, deckCount: 1))
        XCTAssertTrue(EntitlementRules.canCreateDeck(isPremium: true, deckCount: 100))
    }

    func testFreeUserCanAddCardsBelowLimit() {
        XCTAssertTrue(EntitlementRules.canCreateCard(isPremium: false, cardCount: 49))
        XCTAssertFalse(EntitlementRules.canCreateCard(isPremium: false, cardCount: 50))
    }

    func testPremiumUserCanAddCardsAtAnyCount() {
        XCTAssertTrue(EntitlementRules.canCreateCard(isPremium: true, cardCount: 50))
        XCTAssertTrue(EntitlementRules.canCreateCard(isPremium: true, cardCount: 500))
    }
}
