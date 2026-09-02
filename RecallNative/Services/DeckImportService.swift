import Foundation
import SwiftData

enum DeckImportService {
    struct ImportedCard: Decodable {
        let front: String
        let back: String
        let hint: String?
        let tags: String?

        private enum CodingKeys: String, CodingKey {
            case front, back, hint, tags
        }

        init(front: String, back: String, hint: String?, tags: String?) {
            self.front = front
            self.back = back
            self.hint = hint
            self.tags = tags
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // Match the JS contract: front/back must be strings. Invalid
            // values are rejected by the card validation path rather than
            // silently coercing them.
            front = try container.decode(String.self, forKey: .front)
            back = try container.decode(String.self, forKey: .back)
            // JS uses String(value).trim() for optional hint/tags. Decode any
            // JSON scalar/object/array and stringify it so native imports have
            // the same coercion semantics as recall-app.
            hint = try Self.decodeStringified(container, forKey: .hint)
            tags = try Self.decodeStringified(container, forKey: .tags)
        }

        private static func decodeStringified<T: CodingKey>(
            _ container: KeyedDecodingContainer<T>,
            forKey key: T
        ) throws -> String? {
            guard container.contains(key), try !container.decodeNil(forKey: key) else {
                return nil
            }
            let value = try container.superDecoder(forKey: key)
            let json = try JSONValue(from: value)
            return json.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private enum JSONValue: Decodable {
        case string(String)
        case number(String)
        case bool(Bool)
        case object([String: JSONValue])
        case array([JSONValue])
        case null

        init(from decoder: Decoder) throws {
            if let value = try? decoder.singleValueContainer().decode(String.self) {
                self = .string(value)
            } else if let value = try? decoder.singleValueContainer().decode(Bool.self) {
                self = .bool(value)
            } else if let value = try? decoder.singleValueContainer().decode(Double.self) {
                self = .number(String(value))
            } else if let value = try? decoder.singleValueContainer().decode([String: JSONValue].self) {
                self = .object(value)
            } else if let value = try? decoder.singleValueContainer().decode([JSONValue].self) {
                self = .array(value)
            } else {
                self = .null
            }
        }

        var stringValue: String {
            switch self {
            case .string(let value): return value
            case .number(let value): return value
            case .bool(let value): return value ? "true" : "false"
            case .object(let value):
                return value.map { "\($0):\($1.stringValue)" }.joined(separator: ",")
            case .array(let value):
                return value.map(\.stringValue).joined(separator: ",")
            case .null: return "null"
            }
        }
    }

    struct Payload: Decodable {
        let deck: String?
        let cards: [ImportedCard]
    }

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
