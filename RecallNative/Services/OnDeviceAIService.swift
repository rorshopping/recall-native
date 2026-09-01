import Foundation

protocol OnDeviceAIService: Sendable {
    func generateFlashcards(from text: String) async throws -> [GeneratedCard]
}

struct GeneratedCard: Identifiable, Sendable, Hashable {
    let id = UUID()
    let question: String
    let answer: String
}

enum AIServiceError: LocalizedError {
    case emptyInput
    case insufficientContent

    var errorDescription: String? {
        switch self {
        case .emptyInput: return "Add some notes before generating cards."
        case .insufficientContent: return "There is not enough text to create useful cards."
        }
    }
}

struct LocalAIService: OnDeviceAIService {
    func generateFlashcards(from text: String) async throws -> [GeneratedCard] {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw AIServiceError.emptyInput }

        // Temporary deterministic fallback. The app-facing protocol is ready for
        // Apple's on-device language model implementation without changing the UI.
        let sentences = cleaned
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 25 }

        guard !sentences.isEmpty else { throw AIServiceError.insufficientContent }

        return Array(sentences.prefix(12)).map { sentence in
            let words = sentence.split(separator: " ")
            let topic = words.prefix(6).joined(separator: " ")
            return GeneratedCard(
                question: "What is the key idea behind \(topic)?",
                answer: sentence
            )
        }
    }
}
