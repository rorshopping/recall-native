import Foundation

protocol OnDeviceAIService {
    func generateFlashcards(from text: String) async throws -> [GeneratedCard]
}

struct GeneratedCard: Identifiable, Sendable {
    let id = UUID()
    let question: String
    let answer: String
}

struct LocalAIService: OnDeviceAIService {
    func generateFlashcards(from text: String) async throws -> [GeneratedCard] {
        // Integration point for Apple's on-device model APIs.
        // Keeping the protocol isolated lets the UI remain unchanged when the
        // concrete local model implementation is added.
        let sentences = text.split(whereSeparator: { $0 == "." || $0 == "\n" })
        return sentences.prefix(5).compactMap { sentence in
            let value = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard value.count > 20 else { return nil }
            return GeneratedCard(question: "What is the key idea?", answer: value)
        }
    }
}
