import Foundation

/// Keeps the launch-offer value signals in one place so the root presentation
/// gate and the offer sheet cannot drift apart as parity work evolves.
enum LaunchOfferEligibility {
    static func hasEarnedValue(
        decks: [Deck],
        cards: [Flashcard],
        reviews: [ReviewLog]
    ) -> Bool {
        let hasNonSampleDeck = decks.contains { deck in
            deck.name != "Spanish Basics" && deck.name != "Spanish Basics — Sample"
        }
        let hasMultipleDecks = decks.count > 1
        let hasEnoughCards = cards.count > 6
        let hasEnoughReviews = reviews.count >= 3
        let hasStudiedToday = reviews.contains { review in
            Calendar.current.isDateInToday(review.reviewedAt)
        }
        let hasStudyHistory = !reviews.isEmpty || !ReviewHistoryStore.load().isEmpty
        let hasCreationHistory = UsageMetricsStore.totalCreated > 6

        return hasNonSampleDeck
            || hasMultipleDecks
            || hasEnoughCards
            || hasEnoughReviews
            || hasStudiedToday
            || hasStudyHistory
            || hasCreationHistory
    }
}
