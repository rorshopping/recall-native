import Foundation
import SwiftData

@Model
final class ReviewLog {
    var id: UUID
    var reviewedAt: Date
    var rating: Int
    var card: Flashcard?

    init(rating: Int, card: Flashcard? = nil) {
        self.id = UUID()
        self.reviewedAt = .now
        self.rating = rating
        self.card = card
    }
}
