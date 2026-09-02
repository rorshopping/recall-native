import Foundation
import RecallLiteRT

protocol OnDeviceAIService: Sendable {
    func generateFlashcards(from text: String) async throws -> GeneratedDeck
}

struct GeneratedCard: Identifiable, Sendable, Hashable, Codable {
    let id: UUID
    let question: String
    let answer: String
    let hint: String
    let tags: String

    init(id: UUID = UUID(), question: String, answer: String, hint: String, tags: String) {
        self.id = id
        self.question = question
        self.answer = answer
        self.hint = hint
        self.tags = tags
    }
}

struct GeneratedDeck: Sendable, Hashable, Codable {
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
        case .modelMissing: return "No on-device AI backend is available. Enable Apple's on-device model or download Gemma 4."
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

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                let data = try await AppleOnDeviceAIService().generateFlashcardJSON(
                    systemPrompt: Self.systemPrompt,
                    source: cleaned
                )
                return try Self.parseDeckData(data, errorPrefix: "Apple's on-device model")
            } catch AppleOnDeviceAIService.ServiceError.unavailable {
            } catch AppleOnDeviceAIService.ServiceError.unsupportedLocale {
            } catch AppleOnDeviceAIService.ServiceError.contextTooLarge {
            } catch {
            }
        }
        #endif

        return try await generateWithGemma(from: cleaned)
    }

    private func generateWithGemma(from text: String) async throws -> GeneratedDeck {
        guard let modelURL = await modelStore.modelURL() else { throw AIServiceError.modelMissing }
        do {
            let engine = RecallLiteRTEngine(modelPath: modelURL.path)
            var lastError: Error?
            for attempt in 0..<2 {
                do {
                    let topic = attempt == 0 ? text : text + "\n\nReturn ONLY valid JSON. Do not include markdown, prose, or code fences."
                    let prompt = attempt == 0 ? Self.systemPrompt : Self.systemPrompt + "\n\nIMPORTANT: Your previous response was invalid. Retry with only valid JSON matching the requested schema."
                    let raw = try await engine.generateDeckJSON(topic: topic, systemPrompt: prompt)
                    do {
                        let normalized = try Self.normalizeJSON(raw)
                        return try Self.parseDeckData(normalized, errorPrefix: "Gemma 4")
                    } catch {
                        lastError = error
                        if attempt == 1 { throw error }
                    }
                } catch {
                    lastError = error
                    if attempt == 1 { throw error }
                }
            }
            throw lastError ?? AIServiceError.generationFailed("Gemma 4 could not generate cards.")
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.generationFailed("Gemma 4 could not generate cards: \(error.localizedDescription)")
        }
    }

    private static func parseDeckData(_ data: Data, errorPrefix: String) throws -> GeneratedDeck {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let cards = object["cards"] as? [[String: Any]] else {
            throw AIServiceError.generationFailed("\(errorPrefix) returned an invalid flashcard deck. Please try again.")
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

    private static func normalizeJSON(_ raw: String) throws -> Data {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = cleaned.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data), JSONSerialization.isValidJSONObject(object) {
            return data
        }

        guard let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}"), start < end else {
            throw AIServiceError.generationFailed("Gemma 4 returned no usable JSON. Please try again.")
        }
        let slice = String(cleaned[start...end])
        let fixed = slice
            .replacingOccurrences(of: #"\\(?![\"\\/bfnrtu])"#, with: #"\\\\"#, options: .regularExpression)
            .replacingOccurrences(of: #",\s*([}\]])"#, with: #"$1"#, options: .regularExpression)
        guard let data = fixed.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data), JSONSerialization.isValidJSONObject(object) else {
            throw AIServiceError.generationFailed("Gemma 4 returned malformed JSON. Please try again.")
        }
        return data
    }
}
