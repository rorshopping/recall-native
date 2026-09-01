import Foundation

/// Product limits mirrored from Recall's production entitlement rules.
enum EntitlementRules {
    static let freeDeckLimit = 1
    static let freeCardLimitPerDeck = 50
    static let yearlyProductID = "recall_yearly"
    static let yearlyPriceLabel = "39,99 €"

    static func canCreateDeck(isPremium: Bool, deckCount: Int) -> Bool {
        isPremium || deckCount < freeDeckLimit
    }

    static func canCreateCard(isPremium: Bool, cardCount: Int) -> Bool {
        isPremium || cardCount < freeCardLimitPerDeck
    }
}
