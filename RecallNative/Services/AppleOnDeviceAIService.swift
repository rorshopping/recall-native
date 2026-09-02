import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
struct AppleOnDeviceAIService: Sendable {
    enum ServiceError: LocalizedError {
        case unavailable
        case unsupportedLocale
        case emptyResponse
        case contextTooLarge

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Apple's on-device language model is not available on this device."
            case .unsupportedLocale:
                return "Apple's on-device language model doesn't support the current language."
            case .emptyResponse:
                return "Apple's on-device language model returned no content."
            case .contextTooLarge:
                return "This source is too large for Apple's on-device model."
            }
        }
    }

    @Generable(description: "A flashcard deck generated only from supplied study material.")
    struct FlashcardDeck: Sendable {
        @Guide(description: "A short title for the deck.")
        var deck: String
        @Guide(description: "High-value flashcards covering the supplied material.")
        var cards: [Flashcard]
    }

    @Generable(description: "One concise study flashcard.")
    struct Flashcard: Sendable {
        @Guide(description: "A concise question or term to recall.")
        var front: String
        @Guide(description: "A concise answer based only on the supplied material.")
        var back: String
        @Guide(description: "An optional short clue.")
        var hint: String
        @Guide(description: "Optional comma-separated topic tags.")
        var tags: String
    }

    func generateJSON(instruction: String, systemPrompt: String, source: String) async throws -> Data {
        let model = try validatedModel()
        let material = try validatedSource(source)
        let session = LanguageModelSession(instructions: systemPrompt)
        let prompt = "SOURCE MATERIAL:\n\(material)\n\nTASK:\n\(instruction)\n\nReturn ONLY valid JSON. Do not include markdown, prose, or code fences."

        // Apple documents a 4,096-token context window and counts both input and output.
        // Leave a meaningful response budget so a long source does not fail at runtime.
        let inputTokens = model.tokenCount(for: systemPrompt) + model.tokenCount(for: prompt)
        let responseBudget = 1_200
        guard inputTokens + responseBudget <= model.contextSize else {
            throw ServiceError.contextTooLarge
        }

        let response = try await session.respond(to: prompt)
        let raw = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { throw ServiceError.emptyResponse }
        return try AppleJSONOutputNormalizer.normalize(raw)
    }

    /// Uses Foundation Models guided generation so flashcards are returned as a typed
    /// structure instead of relying on free-form JSON parsing. Apple performs constrained
    /// sampling against this schema, which makes malformed output much less likely.
    func generateFlashcardJSON(systemPrompt: String, source: String) async throws -> Data {
        let model = try validatedModel()
        let material = try validatedSource(source)
        let session = LanguageModelSession(instructions: systemPrompt)
        let prompt = """
        Generate a flashcard deck from the supplied study material.
        Create between 10 and 25 high-value cards when the material supports it.
        Keep every field concise enough to fit on one screen.
        Use the same language as the input when it is clearly non-English.
        Base every card only on the supplied material. Never invent facts, numbers, or claims.

        SOURCE MATERIAL:
        \(material)
        """

        let inputTokens = model.tokenCount(for: systemPrompt) + model.tokenCount(for: prompt)
        // Guided generation includes the schema in the context by default. Reserve enough
        // room for the generated deck and let the framework enforce the actual schema.
        let responseBudget = 1_200
        guard inputTokens + responseBudget <= model.contextSize else {
            throw ServiceError.contextTooLarge
        }

        let response = try await session.respond(to: prompt, generating: FlashcardDeck.self)
        let deck = response.content
        guard !deck.cards.isEmpty else { throw AIServiceError.insufficientContent }

        let object: [String: Any] = [
            "deck": deck.deck,
            "cards": deck.cards.map { card in
                [
                    "front": card.front,
                    "back": card.back,
                    "hint": card.hint,
                    "tags": card.tags
                ]
            }
        ]
        guard JSONSerialization.isValidJSONObject(object) else {
            throw AIServiceError.generationFailed("Apple's on-device model returned an invalid flashcard deck. Please try again.")
        }
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func validatedModel() throws -> SystemLanguageModel {
        let model = SystemLanguageModel.default
        guard model.isAvailable else { throw ServiceError.unavailable }
        guard model.supportsLocale(Locale.current) else { throw ServiceError.unsupportedLocale }
        return model
    }

    private func validatedSource(_ source: String) throws -> String {
        let material = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !material.isEmpty else { throw AIServiceError.emptyInput }
        return material
    }
}
#endif

private enum AppleJSONOutputNormalizer {
    static func normalize(_ raw: String) throws -> Data {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = cleaned.data(using: .utf8) {
            do {
                let object = try JSONSerialization.jsonObject(with: data)
                if JSONSerialization.isValidJSONObject(object) { return data }
            } catch { }
        }

        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}"),
              start < end else {
            throw AIServiceError.generationFailed("The on-device model returned no usable JSON. Please try again.")
        }

        let slice = String(cleaned[start...end])
        let fixed = slice
            .replacingOccurrences(of: #"\\(?![\"\\/bfnrtu])"#, with: #"\\\\"#, options: .regularExpression)
            .replacingOccurrences(of: #",\s*([}\]])"#, with: #"$1"#, options: .regularExpression)

        guard let data = fixed.data(using: .utf8) else {
            throw AIServiceError.generationFailed("The on-device model returned malformed JSON. Please try again.")
        }

        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard JSONSerialization.isValidJSONObject(object) else {
                throw AIServiceError.generationFailed("The on-device model returned malformed JSON. Please try again.")
            }
            return data
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.generationFailed("The on-device model returned malformed JSON. Please try again.")
        }
    }
}
