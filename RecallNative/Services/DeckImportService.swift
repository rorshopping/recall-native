import Foundation
import SwiftData

enum DeckImportService {
    struct ImportedCard: Decodable {
        let front: String
        let back: String
        let hint: String?
        let tags: String?
    }
    struct Payload: Decodable { let deck: String?; let cards: [ImportedCard] }

    static func parse(_ data: Data) throws -> (name: String, cards: [ImportedCard]) {
        let decoder = JSONDecoder()
        if let payload = try? decoder.decode(Payload.self, from: data) {
            return try validate(name: payload.deck, cards: payload.cards)
        }
        if let cards = try? decoder.decode([ImportedCard].self, from: data) {
            return try validate(name: nil, cards: cards)
        }
        throw ImportError.invalidShape
    }

    static func add(_ data: Data, to context: ModelContext) throws -> Deck {
        let parsed = try parse(data)
        let deck = Deck(name: parsed.name, emoji: "📚")
        context.insert(deck)
        for item in parsed.cards {
            let question = item.front.trimmingCharacters(in: .whitespacesAndNewlines)
            let answer = item.back.trimmingCharacters(in: .whitespacesAndNewlines)
            let hint = item.hint?.trimmingCharacters(in: .whitespacesAndNewlines)
            let tags = item.tags?.trimmingCharacters(in: .whitespacesAndNewlines)
            context.insert(Flashcard(
                question: question,
                answer: answer,
                hint: hint?.isEmpty == true ? nil : hint,
                tags: tags?.isEmpty == true ? nil : tags,
                deck: deck
            ))
        }
        try context.save()
        return deck
    }

    private static func validate(name: String?, cards: [ImportedCard]) throws -> (String, [ImportedCard]) {
        // Match recall-app's shared deckJson contract: trim front/back, drop
        // invalid cards, preserve optional hint/tags, and use the same default
        // deck name when no usable name is supplied. The JS contract does not
        // impose an artificial maximum on the deck name.
        let cleaned = cards.compactMap { card -> ImportedCard? in
            let front = card.front.trimmingCharacters(in: .whitespacesAndNewlines)
            let back = card.back.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !front.isEmpty, !back.isEmpty else { return nil }
            return ImportedCard(
                front: front,
                back: back,
                hint: card.hint?.trimmingCharacters(in: .whitespacesAndNewlines),
                tags: card.tags?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        guard !cleaned.isEmpty else { throw ImportError.noCards }
        let deckName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (deckName?.isEmpty == false ? deckName! : "Imported deck", cleaned)
    }

    enum ImportError: LocalizedError {
        case invalidShape, noCards
        var errorDescription: String? {
            switch self {
            case .invalidShape: return "Unexpected shape: expected an array of cards, or { deck, cards }"
            case .noCards: return "No valid cards found"
            }
        }
    }
}
