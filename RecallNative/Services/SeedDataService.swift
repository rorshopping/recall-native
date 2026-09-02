import Foundation
import SwiftData

@MainActor
enum SeedDataService {
    static let sampleDeckName = "Spanish Basics — Sample"

    static func insertSampleDeck(into context: ModelContext) throws {
        let deck = Deck(name: sampleDeckName)
        let cards: [(String, String, String, String)] = [
            ("How do you say 'apple'?", "manzana", "la fruta roja", "food"),
            ("How do you say 'house'?", "casa", "", "food"),
            ("How do you say 'thank you'?", "gracias", "", "phrases"),
            ("How do you say 'water'?", "agua", "la bebida", "food"),
            ("Conjugate: yo (to eat)", "como", "infinitive: comer", "verbs"),
            ("What is 'el perro'?", "the dog", "", "animals")
        ]

        for (question, answer, hint, tags) in cards {
            deck.cards.append(
                Flashcard(question: question, answer: answer, hint: hint, tags: tags, deck: deck)
            )
        }

        context.insert(deck)
        try context.save()
    }

    static func resetToSample(context: ModelContext) throws {
        try context.fetch(FetchDescriptor<ReviewLog>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<Flashcard>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<Deck>()).forEach(context.delete)
        try insertSampleDeck(into: context)
    }
}
