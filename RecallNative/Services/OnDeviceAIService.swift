import Foundation
import RecallLiteRT

protocol OnDeviceAIService: Sendable {
    func generateFlashcards(from text: String) async throws -> GeneratedDeck
}

struct GeneratedCard: Identifiable, Sendable, Hashable {
    let id = UUID()
    let question: String
    let answer: String
    let hint: String
    let tags: String
}

struct GeneratedDeck: Sendable, Hashable {
    let name: String
    let cards: [GeneratedCard]
}

enum AIServiceError: LocalizedError {
    case emptyInput
    case insufficientContent
    case modelMissing
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput: return "Add some notes before generating cards."
        case .insufficientContent: return "There is not enough text to create useful cards."
        case .modelMissing: return "Gemma 4 is not installed yet. Download the on-device model first."
        case .generationFailed(let message): return message
        }
    }
}

struct LocalAIService: OnDeviceAIService {
    private static let systemPrompt = """
    You are Recall, a spaced-repetition flashcard generator running entirely on the user's device. You turn study material into a deck of flashcards.

    Output rules (STRICT):
    - Respond with ONLY one JSON object, no markdown fences, no commentary before or after.
    - Shape: {\"deck\":\"title\",\"cards\":[{\"front\":\"Question\",\"back\":\"Answer\",\"hint\":\"optional clue\",\"tags\":\"optional, comma separated\"}]}
    - front is a question or term to recall; back is the concise answer.
    - Keep every field short enough to fit on one screen.
    - Base every card ONLY on the supplied material. Never invent facts, numbers, or claims.
    - Produce between 10 and 25 high-value cards covering core terms, relationships, examples, and distinctions.
    - Use the same language as the input when it is clearly non-English.
    - If the input is empty or too thin, return {\"deck\":\"\",\"cards\":[]}.
    """

    private let modelStore = LiteRTModelStore.shared

    func generateFlashcards(from text: String) async throws -> GeneratedDeck {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw AIServiceError.emptyInput }
        guard let modelURL = await modelStore.modelURL() else { throw AIServiceError.modelMissing }
        do {
            let engine = RecallLiteRTEngine(modelPath: modelURL.path)
            let raw = try await engine.generateDeckJSON(topic: cleaned, systemPrompt: Self.systemPrompt)
            return try Self.parseDeck(raw)
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.generationFailed("Gemma 4 could not generate cards: \(error.localizedDescription)")
        }
    }

    private static func parseDeck(_ raw: String) throws -> GeneratedDeck {
        let normalized = raw.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = normalized.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let cards = object["cards"] as? [[String: Any]] else {
            throw AIServiceError.generationFailed("Gemma 4 returned an invalid flashcard deck. Please try again.")
        }
        let parsed = cards.compactMap { card -> GeneratedCard? in
            guard let front = card["front"] as? String, let back = card["back"] as? String else { return nil }
            let question = front.trimmingCharacters(in: .whitespacesAndNewlines)
            let answer = back.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !question.isEmpty, !answer.isEmpty else { return nil }
            return GeneratedCard(question: question, answer: answer, hint: (card["hint"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines), tags: (card["tags"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard !parsed.isEmpty else { throw AIServiceError.insufficientContent }
        let generatedName = (object["deck"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return GeneratedDeck(name: generatedName, cards: Array(parsed.prefix(25)))
    }
}
