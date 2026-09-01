import Foundation
import SwiftData
import Testing
@testable import RecallNative

struct RecallNativeTests {
    @Test func newCardGoodGraduatesToReview() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let result = SpacedRepetitionService.schedule(state: "new", step: 1, repetitions: 0, interval: 0, ease: 2.5, grade: 2, now: now)
        #expect(result.state == "review")
        #expect(result.repetitions == 1)
        #expect(result.interval == 1)
        #expect(result.dueAt == now.addingTimeInterval(86_400))
    }

    @Test func hardLearningAdvancesToNextLearningStep() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let result = SpacedRepetitionService.schedule(state: "learning", step: 0, repetitions: 0, interval: 0, ease: 2.5, grade: 1, now: now)
        #expect(result.state == "learning")
        #expect(result.step == 0)
        #expect(result.dueAt == now.addingTimeInterval(60))
    }

    @Test func againOnReviewStartsRelearning() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let result = SpacedRepetitionService.schedule(state: "review", step: 0, repetitions: 4, interval: 12, ease: 2.5, grade: 0, now: now)
        #expect(result.state == "relearning")
        #expect(result.repetitions == 0)
        #expect(result.interval == 0)
        #expect(result.ease == 2.3)
        #expect(result.dueAt == now.addingTimeInterval(60))
    }

    @Test func easyReviewIncreasesIntervalAndEase() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let result = SpacedRepetitionService.schedule(state: "review", step: 0, repetitions: 2, interval: 6, ease: 2.5, grade: 3, now: now)
        #expect(result.state == "review")
        #expect(result.repetitions == 3)
        #expect(result.interval == 20)
        #expect(result.ease == 2.65)
        #expect(result.dueAt == now.addingTimeInterval(20 * 86_400))
    }

    @Test func flashcardDefaultsToNewAndDueNow() {
        let card = Flashcard(question: "Q", answer: "A")
        #expect(card.isNew)
        #expect(card.isDue)
        #expect(card.type == "basic")
        #expect(card.typeInAnswer == false)
        #expect(card.interval == 0)
        #expect(card.ease == 2.5)
    }

    @Test func importedDeckPreservesCardMetadata() throws {
        let schema = Schema([Deck.self, Flashcard.self, ReviewLog.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let json = #"{"deck":"Biology","cards":[{"front":"Cell","back":"Basic unit of life","hint":"Think smallest living unit","tags":"biology,basics"}]}"#.data(using: .utf8)!

        let deck = try DeckImportService.add(json, to: context)
        #expect(deck.name == "Biology")
        #expect(deck.cards.count == 1)
        #expect(deck.cards.first?.hint == "Think smallest living unit")
        #expect(deck.cards.first?.tags == "biology,basics")
    }

    @Test func freeTierAllowsExactlyOneDeck() {
        #expect(EntitlementRules.canCreateDeck(isPremium: false, deckCount: 0))
        #expect(!EntitlementRules.canCreateDeck(isPremium: false, deckCount: 1))
        #expect(EntitlementRules.canCreateDeck(isPremium: true, deckCount: 100))
    }

    @Test func freeTierAllowsExactlyFiftyCardsPerDeck() {
        #expect(EntitlementRules.canCreateCard(isPremium: false, cardCount: 49))
        #expect(!EntitlementRules.canCreateCard(isPremium: false, cardCount: 50))
        #expect(EntitlementRules.canCreateCard(isPremium: true, cardCount: 500))
    }
}
