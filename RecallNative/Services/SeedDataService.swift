import Foundation
import SwiftData

@MainActor
enum SeedDataService {
    static let sampleDeckName = "Spanish Basics — Sample"
    private static let legacySampleDeckName = "Spanish Basics"

    private static let sampleCards: [(String, String, String, String)] = [
        ("How do you say 'apple'?", "manzana", "la fruta roja", "food"),
        ("How do you say 'house'?", "casa", "", "food"),
        ("How do you say 'thank you'?", "gracias", "", "phrases"),
        ("How do you say 'water'?", "agua", "la bebida", "food"),
        ("Conjugate: yo (to eat)", "como", "infinitive: comer", "verbs"),
        ("What is 'el perro'?", "the dog", "", "animals")
    ]

    static func insertSampleDeck(into context: ModelContext) throws {
        let deck = Deck(name: sampleDeckName)

        for (question, answer, hint, tags) in sampleCards {
            deck.cards.append(
                Flashcard(question: question, answer: answer, hint: hint, tags: tags, deck: deck)
            )
        }

        context.insert(deck)
        try context.save()
    }

    /// Migrates the original six-card sample deck name without touching a user's
    /// own deck that happens to share the old name.
    static func migrateLegacySampleDeckIfNeeded(context: ModelContext) throws {
        let decks = try context.fetch(FetchDescriptor<Deck>())
        guard let legacyDeck = decks.first(where: { deck in
            deck.name.trimmingCharacters(in: .whitespacesAndNewlines) == legacySampleDeckName
                && matchesSampleCards(deck.cards)
        }) else {
            return
        }

        legacyDeck.name = sampleDeckName
        try context.save()
    }

    static func resetToSample(context: ModelContext) throws {
        try context.fetch(FetchDescriptor<ReviewLog>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<Flashcard>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<Deck>()).forEach(context.delete)
        try insertSampleDeck(into: context)
    }

    private static func matchesSampleCards(_ cards: [Flashcard]) -> Bool {
        guard cards.count == sampleCards.count else { return false }

        let actual = Set(cards.map { card in
            (card.question, card.answer, card.hint, card.tags)
        })
        let expected = Set(sampleCards.map { ($0.0, $0.1, $0.2, $0.3) })
        return actual == expected
    }
}
