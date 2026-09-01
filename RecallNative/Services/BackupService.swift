import Foundation
import SwiftData

struct RecallBackup: Codable {
    struct DeckRecord: Codable { let id: UUID; let name: String; let emoji: String; let createdAt: Date }
    struct CardRecord: Codable { let id: UUID; let question: String; let answer: String; let createdAt: Date; let dueAt: Date; let interval: Int; let ease: Double; let repetitions: Int; let state: String; let step: Int; let lapses: Int; let lastReviewedAt: Date?; let deckID: UUID }
    struct ReviewRecord: Codable { let id: UUID; let reviewedAt: Date; let rating: Int; let cardID: UUID? }
    let version: Int
    let exportedAt: Date
    let decks: [DeckRecord]
    let cards: [CardRecord]
    let reviews: [ReviewRecord]
}

enum BackupService {
    static func makeBackup(context: ModelContext) throws -> Data {
        let decks = try context.fetch(FetchDescriptor<Deck>()).map { RecallBackup.DeckRecord(id: $0.id, name: $0.name, emoji: $0.emoji, createdAt: $0.createdAt) }
        let cards = try context.fetch(FetchDescriptor<Flashcard>()).compactMap { card -> RecallBackup.CardRecord? in
            guard let deckID = card.deck?.id else { return nil }
            return .init(id: card.id, question: card.question, answer: card.answer, createdAt: card.createdAt, dueAt: card.dueAt, interval: card.interval, ease: card.ease, repetitions: card.repetitions, state: card.state, step: card.step, lapses: card.lapses, lastReviewedAt: card.lastReviewedAt, deckID: deckID)
        }
        let reviews = try context.fetch(FetchDescriptor<ReviewLog>()).map { RecallBackup.ReviewRecord(id: $0.id, reviewedAt: $0.reviewedAt, rating: $0.rating, cardID: $0.card?.id) }
        let backup = RecallBackup(version: 1, exportedAt: .now, decks: decks, cards: cards, reviews: reviews)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    static func restore(_ data: Data, context: ModelContext, replaceExisting: Bool = false) throws {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(RecallBackup.self, from: data)
        guard backup.version == 1 else { throw BackupError.unsupportedVersion }
        if replaceExisting {
            try context.fetch(FetchDescriptor<ReviewLog>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<Flashcard>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<Deck>()).forEach(context.delete)
        }
        var deckMap: [UUID: Deck] = [:]
        for record in backup.decks {
            let deck = Deck(name: record.name, emoji: record.emoji); deck.id = record.id; deck.createdAt = record.createdAt
            context.insert(deck); deckMap[record.id] = deck
        }
        var cardMap: [UUID: Flashcard] = [:]
        for record in backup.cards where deckMap[record.deckID] != nil {
            let card = Flashcard(question: record.question, answer: record.answer, deck: deckMap[record.deckID]); card.id = record.id
            card.createdAt = record.createdAt; card.dueAt = record.dueAt; card.interval = record.interval; card.ease = record.ease; card.repetitions = record.repetitions
            card.state = record.state; card.step = record.step; card.lapses = record.lapses; card.lastReviewedAt = record.lastReviewedAt
            context.insert(card); cardMap[record.id] = card
        }
        for record in backup.reviews { let log = ReviewLog(rating: record.rating, card: record.cardID.flatMap { cardMap[$0] }); log.id = record.id; log.reviewedAt = record.reviewedAt; context.insert(log) }
        try context.save()
    }

    enum BackupError: LocalizedError { case unsupportedVersion; var errorDescription: String? { "This backup was created by an unsupported Recall version." } }
}
