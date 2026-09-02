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
        let deck=Deck(name:sampleDeckName)
        for (question,answer,hint,tags) in sampleCards { deck.cards.append(Flashcard(question:question,answer:answer,hint:hint,tags:tags,deck:deck)) }
        context.insert(deck); try context.save()
    }
    static func migrateLegacySampleDeckIfNeeded(context: ModelContext) throws {
        let decks=try context.fetch(FetchDescriptor<Deck>())
        guard let legacy=decks.first(where:{ $0.name.trimmingCharacters(in:.whitespacesAndNewlines)==legacySampleDeckName && matchesSampleCards($0.cards) }) else { return }
        legacy.name=sampleDeckName; try context.save()
    }
    static func resetToSample(context: ModelContext) throws {
        try context.fetch(FetchDescriptor<ReviewLog>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<Flashcard>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<Deck>()).forEach(context.delete)
        ReviewHistoryStore.clear()
        try insertSampleDeck(into:context)
    }
    private static func matchesSampleCards(_ cards:[Flashcard]) -> Bool {
        guard cards.count==sampleCards.count else { return false }
        func signature(_ q:String,_ a:String,_ h:String,_ t:String)->String { "\(q)\u{1F}\(a)\u{1F}\(h)\u{1F}\(t)" }
        return Set(cards.map{signature($0.question,$0.answer,$0.hint,$0.tags)}) == Set(sampleCards.map{signature($0.0,$0.1,$0.2,$0.3)})
    }
}
