import Foundation
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
    func legacySampleDeckIsRenamedWithoutChangingUserDecks() throws {
        let schema = Schema([Deck.self, Flashcard.self, ReviewLog.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let legacyDeck = Deck(name: "Spanish Basics")
        let sampleCards: [(String, String, String, String)] = [
            ("How do you say 'apple'?", "manzana", "la fruta roja", "food"),
            ("How do you say 'house'?", "casa", "", "food"),
            ("How do you say 'thank you'?", "gracias", "", "phrases"),
            ("How do you say 'water'?", "agua", "la bebida", "food"),
            ("Conjugate: yo (to eat)", "como", "infinitive: comer", "verbs"),
            ("What is 'el perro'?", "the dog", "", "animals")
        ]
        for (question, answer, hint, tags) in sampleCards {
            legacyDeck.cards.append(Flashcard(question: question, answer: answer, hint: hint, tags: tags, deck: legacyDeck))
        }

        let userDeck = Deck(name: "Spanish Basics")
        userDeck.cards.append(Flashcard(question: "My question", answer: "My answer", deck: userDeck))
        context.insert(legacyDeck)
        context.insert(userDeck)
        try context.save()

        try SeedDataService.migrateLegacySampleDeckIfNeeded(context: context)

        let decks = try context.fetch(FetchDescriptor<Deck>())
        #expect(decks.contains(where: { $0.name == SeedDataService.sampleDeckName && $0.cards.count == 6 }))
        #expect(decks.contains(where: { $0.name == "Spanish Basics" && $0.cards.count == 1 }))
    }

    @Test @MainActor
    func resetRemovesProgressAndRestoresSample() throws {
        let schema = Schema([Deck.self, Flashcard.self, ReviewLog.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let previousHistory = ReviewHistoryStore.exportValues()
        defer { ReviewHistoryStore.replace(with: previousHistory.reduce(into: [Date: Int]()) { result, entry in if let date = ReviewHistoryStore.date(from: entry.key) { result[date] = entry.value } }) }
        ReviewHistoryStore.replace(with: [Date(timeIntervalSince1970: 1_756_000_000): 7])

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
        #expect(ReviewHistoryStore.load().isEmpty)
    }
}
