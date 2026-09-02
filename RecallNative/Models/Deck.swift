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
    var newStudiedToday: Int
    var newDay: String?

    init(name: String, emoji: String = "📚") {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.createdAt = .now
        self.cards = []
        self.newLimit = 20
        self.newStudiedToday = 0
        self.newDay = nil
    }

    var dueCount: Int { cards.filter { $0.dueAt <= .now && !$0.isNew }.count }
    var newCount: Int { cards.filter(\.isNew).count }
    var masteredCount: Int { cards.filter { $0.repetitions >= 3 && $0.ease >= 2.5 }.count }

    var newRemainingToday: Int {
        let today = Calendar.current.startOfDay(for: .now)
        let storedDay = newDay.flatMap { Self.dayFormatter.date(from: $0) }
        let used = storedDay.map { Calendar.current.isDate($0, inSameDayAs: today) } == true ? newStudiedToday : 0
        return min(max(0, newLimit - used), newCount)
    }

    nonisolated(unsafe) private static let dayFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return formatter
    }()
}
