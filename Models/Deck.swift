import Foundation
import SwiftData

@Model
final class Deck {
    var id: UUID
    var name: String
    var emoji: String
    var createdAt: Date
    var cards: [Flashcard]
    var newLimit: Int
    var newDay: String?
    var newStudiedToday: Int

    init(name: String, emoji: String = "📚", newLimit: Int = 20) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.createdAt = .now
        self.cards = []
        self.newLimit = max(0, newLimit)
        self.newDay = nil
        self.newStudiedToday = 0
    }

    var dueCount: Int { cards.filter { !$0.isNew && $0.dueAt <= .now }.count }
    var newCount: Int { cards.filter(\.isNew).count }
    var newRemainingToday: Int {
        let today = Date.now.formatted(.dateTime.year().month().day())
        let used = newDay == today ? newStudiedToday : 0
        return max(0, min(newLimit - used, newCount))
    }
    var masteredCount: Int { cards.filter { $0.repetitions >= 3 && $0.ease >= 2.5 }.count }
}
