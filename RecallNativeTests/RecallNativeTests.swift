import Testing
@testable import RecallNative

struct RecallNativeTests {
    @Test func generatedCardHasContent() async throws {
        let cards = try await LocalAIService().generateFlashcards(from: "Spaced repetition improves long term retention. Active recall strengthens memory retrieval.")
        #expect(cards.count == 2)
        #expect(cards.first?.answer.isEmpty == false)
    }
}
