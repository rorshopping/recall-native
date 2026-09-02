import SwiftData
import Testing
@testable import RecallNative

struct SeedDataServiceTests {
    @Test @MainActor
    func sampleDeckContainsOriginalCards() throws {
        let schema = Schema([Deck.self, Flashcard.self, ReviewLog.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        try SeedDataService.insertSampleDeck(into: context)

        let decks = try context.fetch(FetchDescriptor<Deck>())
        #expect(decks.count == 1)
        #expect(decks.first?.name == SeedDataService.sampleDeckName)
        #expect(decks.first?.cards.count == 6)
        #expect(decks.first?.cards.map(\.question) == [
            "How do you say 'apple'?",
            "How do you say 'house'?",
            "How do you say 'thank you'?",
            "How do you say 'water'?",
            "Conjugate: yo (to eat)",
            "What is 'el perro'?"
        ])
    }

    @Test @MainActor
    func resetRemovesProgressAndRestoresSample() throws {
        let schema = Schema([Deck.self, Flashcard.self, ReviewLog.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let customDeck = Deck(name: "My Deck")
        let customCard = Flashcard(question: "Custom", answer: "Answer", deck: customDeck)
        customDeck.cards.append(customCard)
        context.insert(customDeck)
        context.insert(ReviewLog(rating: 3, card: customCard))
        try context.save()

        try SeedDataService.resetToSample(context: context)

        let decks = try context.fetch(FetchDescriptor<Deck>())
        let cards = try context.fetch(FetchDescriptor<Flashcard>())
        let reviews = try context.fetch(FetchDescriptor<ReviewLog>())
        #expect(decks.count == 1)
        #expect(decks.first?.name == SeedDataService.sampleDeckName)
        #expect(cards.count == 6)
        #expect(!cards.contains(where: { $0.question == "Custom" }))
        #expect(reviews.isEmpty)
    }
}
