import Foundation
import SwiftData
import Testing
@testable import RecallNative

struct LaunchOfferEligibilityTests {
    @Test @MainActor
    func sampleDeckAloneDoesNotEarnValue() throws {
        let deck = Deck(name: SeedDataService.sampleDeckName)
        let cards = (0..<6).map { _ in Flashcard(question: "Q", answer: "A", deck: deck) }
        deck.cards.append(contentsOf: cards)

        #expect(!LaunchOfferEligibility.hasEarnedValue(decks: [deck], cards: cards, reviews: []))
    }

    @Test @MainActor
    func customDeckEarnsValueImmediately() throws {
        let deck = Deck(name: "My Deck")
        let card = Flashcard(question: "Q", answer: "A", deck: deck)
        deck.cards.append(card)

        #expect(LaunchOfferEligibility.hasEarnedValue(decks: [deck], cards: [card], reviews: []))
    }

    @Test @MainActor
    func multipleDecksEarnValueEvenWithSampleSizedContent() throws {
        let sample = Deck(name: SeedDataService.sampleDeckName)
        let second = Deck(name: "Second Deck")

        #expect(LaunchOfferEligibility.hasEarnedValue(decks: [sample, second], cards: [], reviews: []))
    }

    @Test @MainActor
    func reviewTodayEarnsValue() throws {
        let deck = Deck(name: SeedDataService.sampleDeckName)
        let review = ReviewLog(reviewedAt: .now, rating: 3)

        #expect(LaunchOfferEligibility.hasEarnedValue(decks: [deck], cards: [], reviews: [review]))
    }

    @Test @MainActor
    func reviewHistoryEarnsValueEvenWhenCurrentLogsAreEmpty() throws {
        let previous = ReviewHistoryStore.exportValues()
        defer {
            ReviewHistoryStore.replace(with: previous.reduce(into: [Date: Int]()) { result, entry in
                if let date = ReviewHistoryStore.date(from: entry.key) {
                    result[date] = entry.value
                }
            })
        }

        ReviewHistoryStore.replace(with: [Date(timeIntervalSince1970: 1_756_000_000): 1])
        let deck = Deck(name: SeedDataService.sampleDeckName)

        #expect(LaunchOfferEligibility.hasEarnedValue(decks: [deck], cards: [], reviews: []))
    }

    @Test @MainActor
    func aggregateCreationHistoryEarnsValueAfterThreshold() throws {
        let previous = UsageMetricsStore.totalCreated
        defer { UsageMetricsStore.replaceTotalCreated(previous) }

        UsageMetricsStore.replaceTotalCreated(6)
        let deck = Deck(name: SeedDataService.sampleDeckName)
        #expect(!LaunchOfferEligibility.hasEarnedValue(decks: [deck], cards: [], reviews: []))

        UsageMetricsStore.replaceTotalCreated(7)
        #expect(LaunchOfferEligibility.hasEarnedValue(decks: [deck], cards: [], reviews: []))
    }
}
