import Foundation
import SwiftData

struct RecallBackup: Codable {
    struct DeckRecord: Codable {
        let id: UUID
        let name: String
        let emoji: String
        let createdAt: Date
        let newLimit: Int
        let newDay: String
        let newStudiedToday: Int

        private enum CodingKeys: String, CodingKey {
            case id, name, emoji, createdAt, newLimit, newDay, newStudiedToday
        }

        init(id: UUID, name: String, emoji: String, createdAt: Date, newLimit: Int = 20, newDay: String, newStudiedToday: Int) {
            self.id = id
            self.name = name
            self.emoji = emoji
            self.createdAt = createdAt
            self.newLimit = newLimit
            self.newDay = newDay
            self.newStudiedToday = newStudiedToday
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            emoji = try container.decode(String.self, forKey: .emoji)
            createdAt = try container.decode(Date.self, forKey: .createdAt)
            newLimit = try container.decodeIfPresent(Int.self, forKey: .newLimit) ?? 20
            newDay = try container.decode(String.self, forKey: .newDay)
            newStudiedToday = try container.decode(Int.self, forKey: .newStudiedToday)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(emoji, forKey: .emoji)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(newLimit, forKey: .newLimit)
            try container.encode(newDay, forKey: .newDay)
            try container.encode(newStudiedToday, forKey: .newStudiedToday)
        }
    }
    struct CardRecord: Codable {
        let id: UUID; let question: String; let answer: String; let hint: String; let tags: String; let type: String; let typeInAnswer: Bool
        let mediaType: String?; let mediaURI: String?; let createdAt: Date; let dueAt: Date; let interval: Int; let ease: Double; let repetitions: Int
        let state: String; let step: Int; let lapses: Int; let againCount: Int; let hardCount: Int; let goodCount: Int; let easyCount: Int; let lastReviewedAt: Date?; let deckID: UUID
    }
    struct ReviewRecord: Codable { let id: UUID; let reviewedAt: Date; let rating: Int; let cardID: UUID? }
    let version: Int; let exportedAt: Date; let decks: [DeckRecord]; let cards: [CardRecord]; let reviews: [ReviewRecord]
}

enum BackupService {
    static func makeBackup(context: ModelContext) throws -> Data {
        let decks = try context.fetch(FetchDescriptor<Deck>()).map {
            RecallBackup.DeckRecord(id: $0.id, name: $0.name, emoji: $0.emoji, createdAt: $0.createdAt, newLimit: $0.newLimit, newDay: $0.newDay ?? "", newStudiedToday: $0.newStudiedToday)
        }
        let cards = try context.fetch(FetchDescriptor<Flashcard>()).compactMap { card -> RecallBackup.CardRecord? in
            guard let deckID = card.deck?.id else { return nil }
            return .init(id: card.id, question: card.question, answer: card.answer, hint: card.hint, tags: card.tags, type: card.type, typeInAnswer: card.typeInAnswer, mediaType: card.mediaType, mediaURI: card.mediaURI, createdAt: card.createdAt, dueAt: card.dueAt, interval: card.interval, ease: card.ease, repetitions: card.repetitions, state: card.state, step: card.step, lapses: card.lapses, againCount: card.againCount, hardCount: card.hardCount, goodCount: card.goodCount, easyCount: card.easyCount, lastReviewedAt: card.lastReviewedAt, deckID: deckID)
        }
        let reviews = try context.fetch(FetchDescriptor<ReviewLog>()).map { log in
            RecallBackup.ReviewRecord(id: log.id, reviewedAt: log.reviewedAt, rating: log.rating, cardID: log.card?.id)
        }
        let backup = RecallBackup(version: 1, exportedAt: .now, decks: decks, cards: cards, reviews: reviews)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    static func validate(_ data: Data) throws -> RecallBackup {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(RecallBackup.self, from: data)
        guard backup.version == 1 else { throw BackupError.unsupportedVersion }
        guard backup.decks.count <= 1000, backup.cards.count <= 100_000, backup.reviews.count <= 1_000_000 else { throw BackupError.invalidSize }
        guard backup.decks.allSatisfy({ $0.newLimit >= 0 && $0.newLimit <= 1000 }) else { throw BackupError.invalidDeckLimit }
        guard Set(backup.decks.map(\.id)).count == backup.decks.count, Set(backup.cards.map(\.id)).count == backup.cards.count else { throw BackupError.duplicateIDs }
        let deckIDs = Set(backup.decks.map(\.id))
        guard backup.cards.allSatisfy({ deckIDs.contains($0.deckID) }) else { throw BackupError.orphanedCards }
        let cardIDs = Set(backup.cards.map(\.id))
        guard backup.reviews.allSatisfy({ $0.cardID == nil || cardIDs.contains($0.cardID!) }) else { throw BackupError.orphanedReviews }
        return backup
    }

    static func restore(_ data: Data, context: ModelContext, replaceExisting: Bool = false) throws {
        let backup = try validate(data)
        if !replaceExisting {
            let existingDeckIDs = Set(try context.fetch(FetchDescriptor<Deck>()).map(\.id))
            let existingCardIDs = Set(try context.fetch(FetchDescriptor<Flashcard>()).map(\.id))
            if !existingDeckIDs.isDisjoint(with: backup.decks.map(\.id)) || !existingCardIDs.isDisjoint(with: backup.cards.map(\.id)) { throw BackupError.idCollision }
        } else {
            try context.fetch(FetchDescriptor<ReviewLog>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<Flashcard>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<Deck>()).forEach(context.delete)
        }
        var deckMap: [UUID: Deck] = [:]
        for record in backup.decks {
            let deck = Deck(name: record.name, emoji: record.emoji)
            deck.id = record.id; deck.createdAt = record.createdAt; deck.newLimit = record.newLimit; deck.newDay = record.newDay.isEmpty ? nil : record.newDay; deck.newStudiedToday = record.newStudiedToday
            context.insert(deck); deckMap[record.id] = deck
        }
        var cardMap: [UUID: Flashcard] = [:]
        for record in backup.cards {
            let card = Flashcard(question: record.question, answer: record.answer, hint: record.hint, tags: record.tags, deck: deckMap[record.deckID])
            card.id = record.id; card.type = record.type; card.typeInAnswer = record.typeInAnswer; card.mediaType = record.mediaType; card.mediaURI = record.mediaURI
            card.createdAt = record.createdAt; card.dueAt = record.dueAt; card.interval = record.interval; card.ease = record.ease; card.repetitions = record.repetitions
            card.state = record.state; card.step = record.step; card.lapses = record.lapses; card.againCount = record.againCount; card.hardCount = record.hardCount; card.goodCount = record.goodCount; card.easyCount = record.easyCount; card.lastReviewedAt = record.lastReviewedAt
            context.insert(card); cardMap[record.id] = card
        }
        for record in backup.reviews {
            let log = ReviewLog(rating: record.rating, card: record.cardID.flatMap { cardMap[$0] }); log.id = record.id; log.reviewedAt = record.reviewedAt; context.insert(log)
        }
        try context.save()
    }

enum BackupError: LocalizedError {
    case unsupportedVersion, invalidSize, invalidDeckLimit, duplicateIDs, orphanedCards, orphanedReviews, idCollision
    var errorDescription: String? { switch self {
    case .unsupportedVersion: return "This backup was created by an unsupported Recall version."
    case .invalidSize: return "This backup is too large to import safely."
    case .invalidDeckLimit: return "This backup contains an invalid daily new-card limit."
    case .duplicateIDs: return "This backup contains duplicate records."
    case .orphanedCards: return "This backup contains cards without a valid deck."
    case .orphanedReviews: return "This backup contains reviews without a valid card."
    case .idCollision: return "This backup contains records that already exist in your library. Choose replace-all restore instead."
    } }
    }
}
