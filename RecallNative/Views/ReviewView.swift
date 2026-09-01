import SwiftUI
import SwiftData

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Flashcard.dueAt) private var cards: [Flashcard]
    @State private var index = 0
    @State private var revealed = false
    @State private var completed = false

    private var dueCards: [Flashcard] { cards.filter { $0.dueAt <= .now } }

    var body: some View {
        NavigationStack {
            Group {
                if completed || dueCards.isEmpty {
                    ContentUnavailableView("You’re all caught up", systemImage: "checkmark.circle", description: Text("Come back later for your next review."))
                } else {
                    let card = dueCards[min(index, dueCards.count - 1)]
                    VStack(spacing: 18) {
                        Text("\(index + 1) of \(dueCards.count)").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                        Spacer()
                        RecallCard {
                            Text(card.question).font(.title2.bold())
                            if revealed {
                                Divider().padding(.vertical, 8)
                                Text(card.answer).font(.body)
                            } else {
                                Text("Tap to reveal").font(.subheadline).foregroundStyle(.secondary).padding(.top, 18)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(.snappy) { revealed.toggle() } }
                        Spacer()
                        if revealed { RatingBar { rating in rate(card, rating: rating) } }
                    }
                    .padding()
                }
            }
            .navigationTitle("Review")
        }
    }

    private func rate(_ card: Flashcard, rating: Int) {
        card.repetitions += 1
        card.ease = max(1.3, card.ease + (rating >= 3 ? 0.1 : -0.2))
        card.interval = rating <= 1 ? 1 : max(1, Int(Double(max(card.interval, 1)) * card.ease))
        card.dueAt = Calendar.current.date(byAdding: .day, value: card.interval, to: .now) ?? .now
        modelContext.insert(ReviewLog(rating: rating, card: card))
        withAnimation(.snappy) {
            revealed = false
            if index + 1 >= dueCards.count { completed = true } else { index += 1 }
        }
    }
}

private struct RatingBar: View {
    let action: (Int) -> Void
    var body: some View {
        HStack(spacing: 8) {
            RatingButton(title: "Again", value: 1, action: action)
            RatingButton(title: "Hard", value: 2, action: action)
            RatingButton(title: "Good", value: 3, action: action)
            RatingButton(title: "Easy", value: 4, action: action)
        }
    }
}

private struct RatingButton: View {
    let title: String
    let value: Int
    let action: (Int) -> Void
    var body: some View {
        Button(title) { action(value) }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
    }
}
