import Foundation
import SwiftData

enum DeckImportService {
    struct ImportedCard {
        let front: String
        let back: String
        let hint: String?
        let tags: String?

        init(front: String, back: String, hint: String?, tags: String?) {
            self.front = front
            self.back = back
            self.hint = hint
            self.tags = tags
        }
    }

    struct Payload {
        let deck: String?
        let cards: [ImportedCard]
    }

    static func parse(_ data: Data) throws -> (name: String, cards: [ImportedCard]) {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw ImportError.invalidJSON
        }

        let cardsSource: [Any]
        var deckName: String?

        if let array = json as? [Any] {
            cardsSource = array
        } else if let object = json as? [String: Any], let cards = object["cards"] as? [Any] {
            cardsSource = cards
            if let deck = object["deck"] as? String, !deck.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                deckName = deck.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else {
            throw ImportError.invalidShape
        }

        // Mirror recall-app's JavaScript parser: malformed/non-object cards are
        // skipped rather than causing the entire import to fail. front/back
        // must be strings; optional hint/tags use JavaScript String(value).
        let cleaned = cardsSource.compactMap { value -> ImportedCard? in
            guard let card = value as? [String: Any] else { return nil }
            guard let front = card["front"] as? String,
                  let back = card["back"] as? String else { return nil }

            let trimmedFront = front.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBack = back.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedFront.isEmpty, !trimmedBack.isEmpty else { return nil }

            return ImportedCard(
                front: trimmedFront,
                back: trimmedBack,
                hint: javascriptString(card["hint"]),
                tags: javascriptString(card["tags"])
            )
        }

        guard !cleaned.isEmpty else { throw ImportError.noCards }
        return (deckName ?? "Imported deck", cleaned)
    }

    static func add(_ data: Data, to context: ModelContext) throws -> Deck {
        let parsed = try parse(data)
        let deck = Deck(name: parsed.name, emoji: "📚")
        context.insert(deck)
        for item in parsed.cards {
            let hint = item.hint?.trimmingCharacters(in: .whitespacesAndNewlines)
            let tags = item.tags?.trimmingCharacters(in: .whitespacesAndNewlines)
            context.insert(Flashcard(
                question: item.front,
                answer: item.back,
                hint: hint?.isEmpty == true ? nil : hint,
                tags: tags?.isEmpty == true ? nil : tags,
                deck: deck
            ))
        }
        try context.save()
        UsageMetricsStore.recordCreated(parsed.cards.count)
        return deck
    }

    // JavaScript's String(value), restricted to values representable by JSON.
    // Array elements use Array stringification semantics where null becomes an
    // empty element. Objects stringify to the standard JS object marker.
    private static func javascriptString(_ value: Any?) -> String? {
        guard let value else { return nil }
        let result: String
        switch value {
        case let string as String:
            result = string
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                result = number.boolValue ? "true" : "false"
            } else {
                result = javascriptNumberString(number)
            }
        case let array as [Any]:
            result = array.map { element in
                guard !(element is NSNull) else { return "" }
                return javascriptString(element) ?? ""
            }.joined(separator: ",")
        case is NSNull:
            result = "null"
        case is [String: Any]:
            result = "[object Object]"
        default:
            result = String(describing: value)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func javascriptNumberString(_ number: NSNumber) -> String {
        let value = number.doubleValue
        if value.isFinite, value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(value)
    }

    enum ImportError: LocalizedError {
        case invalidJSON, invalidShape, noCards

        var errorDescription: String? {
            switch self {
            case .invalidJSON: return "Not valid JSON"
            case .invalidShape: return "Unexpected shape: expected an array of cards, or { deck, cards }"
            case .noCards: return "No valid cards found"
            }
        }
    }
}
