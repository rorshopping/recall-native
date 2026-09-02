import Foundation
import SwiftData
import Testing
@testable import RecallNative

struct DeletionIntegrityTests {
    @Test func deletingCardDeletesItsReviewHistoryButPreservesOtherCards() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Deck.self,
            Flashcard.self,
            ReviewLog.self,
            configurations: configuration
        )
        let context = ModelContext(container)

        let deck = Deck(name: "Deletion test")
        let deletedCard = Flashcard(question: "Delete me", answer: "Gone", deck: deck)
        let keptCard = Flashcard(question: "Keep me", answer: "Still here", deck: deck)
        let deletedLog = ReviewLog(rating: 1, card: deletedCard)
        let keptLog = ReviewLog(rating: 4, card: keptCard)

        context.insert(deck)
        context.insert(deletedCard)
        context.insert(keptCard)
        context.insert(deletedLog)
        context.insert(keptLog)
        try context.save()

        context.delete(deletedCard)
        try context.save()

        let remainingCards = try context.fetch(FetchDescriptor<Flashcard>())
        let remainingLogs = try context.fetch(FetchDescriptor<ReviewLog>())

        #expect(remainingCards.count == 1)
        #expect(remainingCards.first?.id == keptCard.id)
        #expect(remainingLogs.count == 1)
        #expect(remainingLogs.first?.id == keptLog.id)
        #expect(remainingLogs.first?.card?.id == keptCard.id)
    }

    @Test func deletingDeckCascadesThroughCardsIntoReviewHistory() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Deck.self,
            Flashcard.self,
            ReviewLog.self,
            configurations: configuration
        )
        let context = ModelContext(container)

        let deck = Deck(name: "Cascade test")
        let card = Flashcard(question: "Question", answer: "Answer", deck: deck)
        let log = ReviewLog(rating: 3, card: card)

        context.insert(deck)
        context.insert(card)
        context.insert(log)
        try context.save()

        context.delete(deck)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Deck>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Flashcard>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ReviewLog>()).isEmpty)
    }
}
