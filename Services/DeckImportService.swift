import Foundation
import SwiftData

enum DeckImportService {
    struct ImportedCard: Decodable {
        let front: String
        let back: String
        let hint: String?
        let tags: String?
        let type: String?
        let typeIn: Bool?
        let mediaType: String?
        let mediaURL: String?
    }
    struct Payload: Decodable { let deck: String?; let cards: [ImportedCard] }

    static func parse(_ data: Data) throws -> (name: String, cards: [ImportedCard]) {
        let decoder = JSONDecoder()
        if let payload = try? decoder.decode(Payload.self, from: data) { return try validate(name: payload.deck, cards: payload.cards) }
        if let cards = try? decoder.decode([ImportedCard].self, from: data) { return try validate(name: nil, cards: cards) }
        throw ImportError.invalidShape
    }

    static func add(_ data: Data, to context: ModelContext) throws -> Deck {
        let parsed = try parse(data)
        let deck = Deck(name: parsed.name, emoji: "📚")
        context.insert(deck)
        for item in parsed.cards {
            context.insert(Flashcard(
                question: item.front.trimmingCharacters(in: .whitespacesAndNewlines),
                answer: item.back.trimmingCharacters(in: .whitespacesAndNewlines),
                deck: deck,
                hint: item.hint ?? "",
                tags: item.tags ?? "",
                cardType: item.type ?? "basic",
                typeInAnswer: item.typeIn ?? false,
                mediaType: item.mediaType,
                mediaURL: item.mediaURL
            ))
        }
        try context.save()
        return deck
    }

    private static func validate(name: String?, cards: [ImportedCard]) throws -> (String, [ImportedCard]) {
        let cleaned = cards.filter { !$0.front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !cleaned.isEmpty else { throw ImportError.noCards }
        let deckName = name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? name!.trimmingCharacters(in: .whitespacesAndNewlines) : "Imported deck"
        guard deckName.count <= 120 else { throw ImportError.invalidShape }
        return (deckName, cleaned)
    }

    enum ImportError: LocalizedError {
        case invalidShape, noCards
        var errorDescription: String? {
            switch self { case .invalidShape: return "Expected { deck, cards } or an array of cards."; case .noCards: return "No valid cards found." }
        }
    }
}
