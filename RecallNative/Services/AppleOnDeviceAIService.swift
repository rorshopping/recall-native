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

    @Generable(description: "A focused set of flashcards generated from one source section.")
    struct ChunkFlashcardDeck: Sendable {
        @Guide(description: "A short title for the overall deck.")
        var deck: String
        @Guide(description: "The most important flashcards from this section.", .minimumCount(4), .maximumCount(8))
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

    /// Uses guided generation so flashcards are returned as a typed structure instead of
    /// relying on free-form JSON parsing. Large sources are split into independent sessions,
    /// following Apple's recommended context-window strategy, then their cards are combined.
    func generateFlashcardJSON(systemPrompt: String, source: String) async throws -> Data {
        let model = try validatedModel()
        let material = try validatedSource(source)
        let chunks = try chunkSource(material, model: model, systemPrompt: systemPrompt)

        if chunks.count == 1 {
            return try await generateDeck(from: chunks[0], systemPrompt: systemPrompt, model: model)
        }

        var mergedCards: [Flashcard] = []
        var generatedName = ""
        for chunk in chunks {
            let response = try await generateChunkDeck(from: chunk, systemPrompt: systemPrompt, model: model)
            if generatedName.isEmpty {
                generatedName = response.deck.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            mergedCards.append(contentsOf: response.cards)
            if mergedCards.count >= 25 { break }
        }

        let cards = Array(mergedCards.prefix(25))
        guard !cards.isEmpty else { throw AIServiceError.insufficientContent }

        let object: [String: Any] = [
            "deck": generatedName,
            "cards": cards.map { card in
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

    private func generateDeck(from material: String, systemPrompt: String, model: SystemLanguageModel) async throws -> Data {
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

        try validateContext(prompt: prompt, systemPrompt: systemPrompt, model: model)
        let response = try await session.respond(to: prompt, generating: FlashcardDeck.self)
        return try encode(deck: response.content.deck, cards: response.content.cards)
    }

    private func generateChunkDeck(from material: String, systemPrompt: String, model: SystemLanguageModel) async throws -> ChunkFlashcardDeck {
        let session = LanguageModelSession(instructions: systemPrompt)
        let prompt = """
        Generate 4 to 8 high-value flashcards from this section of a larger study source.
        Cover distinct concepts and avoid repeating generic questions.
        Keep every field concise enough to fit on one screen.
        Use the same language as the input when it is clearly non-English.
        Base every card only on this section. Never invent facts, numbers, or claims.

        SOURCE SECTION:
        \(material)
        """

        try validateContext(prompt: prompt, systemPrompt: systemPrompt, model: model)
        let response = try await session.respond(to: prompt, generating: ChunkFlashcardDeck.self)
        return response.content
    }

    private func encode(deck: String, cards: [Flashcard]) throws -> Data {
        guard !cards.isEmpty else { throw AIServiceError.insufficientContent }
        let object: [String: Any] = [
            "deck": deck,
            "cards": cards.map { card in
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

    private func validateContext(prompt: String, systemPrompt: String, model: SystemLanguageModel) throws {
        let inputTokens = model.tokenCount(for: systemPrompt) + model.tokenCount(for: prompt)
        let responseBudget = 1_200
        guard inputTokens + responseBudget <= model.contextSize else {
            throw ServiceError.contextTooLarge
        }
    }

    private func chunkSource(_ source: String, model: SystemLanguageModel, systemPrompt: String) throws -> [String] {
        let paragraphs = source.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !paragraphs.isEmpty else { return [source] }

        let sourceBudget = max(900, model.contextSize - 1_650)
        var chunks: [String] = []
        var current = ""

        for paragraph in paragraphs {
            let candidate = current.isEmpty ? paragraph : current + "\n\n" + paragraph
            let prompt = "SOURCE SECTION:\n\(candidate)"
            let tokens = model.tokenCount(for: systemPrompt) + model.tokenCount(for: prompt)
            if tokens <= sourceBudget {
                current = candidate
                continue
            }

            if !current.isEmpty {
                chunks.append(current)
                current = ""
            }

            let paragraphTokens = model.tokenCount(for: "SOURCE SECTION:\n\(paragraph)")
            if paragraphTokens <= sourceBudget {
                current = paragraph
            } else {
                chunks.append(contentsOf: splitOversizedParagraph(paragraph, model: model, systemPrompt: systemPrompt, sourceBudget: sourceBudget))
            }
        }

        if !current.isEmpty { chunks.append(current) }
        return chunks.isEmpty ? [source] : chunks
    }

    private func splitOversizedParagraph(_ paragraph: String, model: SystemLanguageModel, systemPrompt: String, sourceBudget: Int) -> [String] {
        let sentences = paragraph.components(separatedBy: ". ").filter { !$0.isEmpty }
        guard sentences.count > 1 else {
            return splitByCharacterBudget(paragraph, model: model, systemPrompt: systemPrompt, sourceBudget: sourceBudget)
        }

        var chunks: [String] = []
        var current = ""
        for sentence in sentences {
            let candidate = current.isEmpty ? sentence : current + ". " + sentence
            let tokens = model.tokenCount(for: "SOURCE SECTION:\n\(candidate)") + model.tokenCount(for: systemPrompt)
            if tokens <= sourceBudget {
                current = candidate
            } else {
                if !current.isEmpty { chunks.append(current) }
                current = sentence
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    private func splitByCharacterBudget(_ text: String, model: SystemLanguageModel, systemPrompt: String, sourceBudget: Int) -> [String] {
        let estimatedCharactersPerToken = 3
        let maxCharacters = max(1_500, sourceBudget * estimatedCharactersPerToken)
        var chunks: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: min(maxCharacters, text.distance(from: start, to: text.endIndex)), limitedBy: text.endIndex) ?? text.endIndex
            var chunk = String(text[start..<end])
            while model.tokenCount(for: "SOURCE SECTION:\n\(chunk)") + model.tokenCount(for: systemPrompt) > sourceBudget && chunk.count > 1_000 {
                chunk = String(chunk.dropLast(500))
            }
            chunks.append(chunk)
            // Advance by the actual emitted chunk, not the original estimated
            // character window. This prevents data from being silently skipped
            // when token validation forces the chunk to shrink.
            start = text.index(start, offsetBy: chunk.count)
        }
        return chunks
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
