import Foundation
import SwiftData

@Model
final class Deck {
    var id: UUID
    var name: String
    var emoji: String
    var createdAt: Date
    var cards: [Flashcard]

    init(name: String, emoji: String = "📚") {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.createdAt = .now
        self.cards = []
    }
}
