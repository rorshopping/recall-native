import Foundation
import SwiftData

/// Imports the JSON backup format produced by the original React Native Recall app.
/// The native app keeps its own backup envelope, but accepts the original nested
/// deck/card shape so users can migrate their library without an intermediate app.
enum LegacyBackupService {
    enum Error: LocalizedError {
        case invalidFormat
        case invalidRecord
        var errorDescription: String? {
            switch self {
            case .invalidFormat: return "That file is not a valid Recall backup."
            case .invalidRecord: return "That Recall backup contains an invalid deck or card."
            }
        }
    }

    static func canImport(_ data: Data) -> Bool {
        do { _ = try parse(data); return true } catch { return false }
    }

    static func restore(_ data: Data, context: ModelContext, replaceExisting: Bool = false) throws {
        let payload = try parse(data)
        if !replaceExisting {
            let existingDeckIDs = Set(try context.fetch(FetchDescriptor<Deck>()).map(\.id))
            let existingCardIDs = Set(try context.fetch(FetchDescriptor<Flashcard>()).map(\.id))
            if !existingDeckIDs.isDisjoint(with: payload.deckIDs) || !existingCardIDs.isDisjoint(with: payload.cardIDs) {
                throw BackupError.idCollision
            }
        } else {
            try context.fetch(FetchDescriptor<ReviewLog>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<Flashcard>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<Deck>()).forEach(context.delete)
        }

        var deckMap: [UUID: Deck] = [:]
        for record in payload.decks {
            let deck = Deck(name: record.name, emoji: record.emoji)
            deck.id = record.id
            deck.createdAt = record.createdAt
            deck.newLimit = record.newLimit
            deck.newDay = record.newDay
            deck.newStudiedToday = record.newStudiedToday
            context.insert(deck)
            deckMap[record.id] = deck
        }

        for record in payload.cards {
            guard let deck = deckMap[record.deckID] else { throw Error.invalidRecord }
            let card = Flashcard(question: record.front, answer: record.back, hint: record.hint, tags: record.tags, deck: deck)
            card.id = record.id
            card.type = record.type
            card.typeInAnswer = record.typeIn
            card.mediaType = record.mediaType
            card.mediaURI = record.mediaURI
            card.createdAt = record.createdAt
            card.dueAt = record.dueAt
            card.interval = record.interval
            card.ease = record.ease
            card.repetitions = record.repetitions
            card.state = record.state
            card.step = record.step
            card.lapses = record.lapses
            card.againCount = record.againCount
            card.hardCount = record.hardCount
            card.goodCount = record.goodCount
            card.easyCount = record.easyCount
            card.lastReviewedAt = record.lastReviewedAt
            context.insert(card)
        }
        try context.save()
    }

    private struct DeckRecord {
        let id: UUID
        let name: String
        let emoji: String
        let createdAt: Date
        let newLimit: Int
        let newDay: String?
        let newStudiedToday: Int
    }

    private struct CardRecord {
        let id: UUID
        let deckID: UUID
        let front: String
        let back: String
        let hint: String
        let tags: String
        let type: String
        let typeIn: Bool
        let mediaType: String?
        let mediaURI: String?
        let createdAt: Date
        let dueAt: Date
        let interval: Int
        let ease: Double
        let repetitions: Int
        let state: String
        let step: Int
        let lapses: Int
        let againCount: Int
        let hardCount: Int
        let goodCount: Int
        let easyCount: Int
        let lastReviewedAt: Date?
    }

    private struct Payload {
        let decks: [DeckRecord]
        let cards: [CardRecord]
        var deckIDs: Set<UUID> { Set(decks.map(\.id)) }
        var cardIDs: Set<UUID> { Set(cards.map(\.id)) }
    }

    private static func parse(_ data: Data) throws -> Payload {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let decksJSON = root["decks"] as? [[String: Any]],
              root["meta"] is [String: Any]
        else { throw Error.invalidFormat }

        guard decksJSON.count <= 1000 else { throw BackupError.invalidSize }
        var decks: [DeckRecord] = []
        var cards: [CardRecord] = []
        var deckIDs = Set<UUID>()
        var cardIDs = Set<UUID>()

        for deckJSON in decksJSON {
            guard let id = uuid(deckJSON["id"]),
                  let name = deckJSON["name"] as? String,
                  let createdAt = date(deckJSON["createdAt"])
            else { throw Error.invalidRecord }
            guard deckIDs.insert(id).inserted else { throw BackupError.duplicateIDs }

            let deck = DeckRecord(
                id: id,
                name: name,
                emoji: deckJSON["emoji"] as? String ?? "📚",
                createdAt: createdAt,
                newLimit: max(0, min(1000, int(deckJSON["newLimit"]) ?? 20)),
                newDay: deckJSON["newDay"] as? String,
                newStudiedToday: max(0, int(deckJSON["newStudiedToday"]) ?? 0)
            )
            decks.append(deck)

            let cardsJSON = deckJSON["cards"] as? [[String: Any]] ?? []
            guard cardsJSON.count <= 100_000 else { throw BackupError.invalidSize }
            for cardJSON in cardsJSON {
                guard let cardID = uuid(cardJSON["id"]),
                      let front = cardJSON["front"] as? String,
                      let back = cardJSON["back"] as? String
                else { throw Error.invalidRecord }
                guard cardIDs.insert(cardID).inserted else { throw BackupError.duplicateIDs }

                let media = cardJSON["media"] as? [String: Any]
                let mediaType = media?["type"] as? String
                let normalizedMediaType = mediaType == "image" || mediaType == "audio" ? mediaType : nil
                let mediaURI = normalizedMediaType == nil ? nil : media?["uri"] as? String
                let stats = cardJSON["stats"] as? [String: Any]

                cards.append(CardRecord(
                    id: cardID,
                    deckID: id,
                    front: front,
                    back: back,
                    hint: cardJSON["hint"] as? String ?? "",
                    tags: cardJSON["tags"] as? String ?? "",
                    type: cardJSON["type"] as? String == "cloze" ? "cloze" : "basic",
                    typeIn: bool(cardJSON["typeIn"]),
                    mediaType: normalizedMediaType,
                    mediaURI: mediaURI,
                    createdAt: date(cardJSON["createdAt"]) ?? .now,
                    dueAt: date(cardJSON["due"]) ?? .now,
                    interval: max(0, int(cardJSON["interval"]) ?? 0),
                    ease: max(1.3, double(cardJSON["ease"]) ?? 2.5),
                    repetitions: max(0, int(cardJSON["reps"]) ?? 0),
                    state: normalizedState(cardJSON["state"]),
                    step: max(0, int(cardJSON["step"]) ?? 0),
                    lapses: max(0, int(cardJSON["lapses"]) ?? 0),
                    againCount: max(0, int(stats?["again"]) ?? 0),
                    hardCount: max(0, int(stats?["hard"]) ?? 0),
                    goodCount: max(0, int(stats?["good"]) ?? 0),
                    easyCount: max(0, int(stats?["easy"]) ?? 0),
                    lastReviewedAt: date(cardJSON["lastReviewed"])
                ))
            }
        }
        return Payload(decks: decks, cards: cards)
    }

    private static func uuid(_ value: Any?) -> UUID? {
        guard let string = value as? String else { return nil }
        return UUID(uuidString: string)
    }

    private static func date(_ value: Any?) -> Date? {
        if let number = value as? NSNumber { return Date(timeIntervalSince1970: number.doubleValue / 1000) }
        if let string = value as? String, let parsed = ISO8601DateFormatter().date(from: string) { return parsed }
        return nil
    }

    private static func int(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }

    private static func double(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }

    private static func bool(_ value: Any?) -> Bool {
        (value as? NSNumber)?.boolValue ?? false
    }

    private static func normalizedState(_ value: Any?) -> String {
        guard let state = value as? String else { return "new" }
        return ["new", "learning", "review", "relearning"].contains(state) ? state : "new"
    }
}

extension BackupService {
    static func validateAny(_ data: Data) throws {
        do { _ = try validate(data) }
        catch {
            guard LegacyBackupService.canImport(data) else { throw error }
        }
    }

    static func restoreAny(_ data: Data, context: ModelContext, replaceExisting: Bool = false) throws {
        do {
            _ = try validate(data)
            try restore(data, context: context, replaceExisting: replaceExisting)
        } catch {
            guard LegacyBackupService.canImport(data) else { throw error }
            try LegacyBackupService.restore(data, context: context, replaceExisting: replaceExisting)
        }
    }
}
