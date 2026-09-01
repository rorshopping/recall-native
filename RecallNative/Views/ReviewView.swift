import SwiftUI
import SwiftData

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Flashcard.dueAt) private var cards: [Flashcard]
    @State private var index = 0
    @State private var revealed = false
    @State private var completed = false

    private var dueCards: [Flashcard] { cards.filter(\.isDue) }

    var body: some View {
        NavigationStack {
            Group {
                if completed || dueCards.isEmpty {
                    CompletionView(reviewed: completed ? index + 1 : 0)
                } else {
                    let card = dueCards[min(index, dueCards.count - 1)]
                    VStack(spacing: 18) {
                        HStack {
                            Text("Review")
                                .font(.headline)
                            Spacer()
                            Text("\(index + 1) / \(dueCards.count)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        ProgressView(value: Double(index), total: Double(max(dueCards.count, 1)))
                            .tint(RecallTheme.accent)

                        Spacer(minLength: 10)

                        RecallCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("QUESTION")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(RecallTheme.accent)
                                    .tracking(1)
                                Text(card.question)
                                    .font(.title2.bold())
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if revealed {
                                    Divider()
                                    Text("ANSWER")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                        .tracking(1)
                                    Text(card.answer)
                                        .font(.body)
                                } else {
                                    Text("Tap the card to reveal the answer")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.snappy(duration: 0.25)) { revealed.toggle() }
                        }

                        Spacer(minLength: 10)

                        if revealed {
                            RatingBar(action: { rating in rate(card, rating: rating) })
                        } else {
                            Text("How well did you remember it?")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func rate(_ card: Flashcard, rating: Int) {
        card.repetitions += 1
        card.ease = max(1.3, card.ease + (rating >= 3 ? 0.1 : -0.2))
        card.interval = interval(for: card, rating: rating)
        card.dueAt = Calendar.current.date(byAdding: .day, value: card.interval, to: .now) ?? .now
        modelContext.insert(ReviewLog(rating: rating, card: card))

        withAnimation(.snappy(duration: 0.2)) {
            revealed = false
            if index + 1 >= dueCards.count {
                completed = true
            } else {
                index += 1
            }
        }
    }

    private func interval(for card: Flashcard, rating: Int) -> Int {
        switch rating {
        case 1: return 1
        case 2: return max(1, Int(Double(max(card.interval, 1)) * 1.2))
        case 3: return max(1, Int(Double(max(card.interval, 1)) * card.ease))
        default: return max(2, Int(Double(max(card.interval, 1)) * card.ease * 1.5))
        }
    }
}

private struct CompletionView: View {
    let reviewed: Int
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(RecallTheme.accent)
            Text("Session complete")
                .font(.largeTitle.bold())
            Text(reviewed > 0 ? "You reviewed \(reviewed) cards. Nice work." : "There are no cards due right now.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

private struct RatingBar: View {
    let action: (Int) -> Void
    var body: some View {
        VStack(spacing: 8) {
            Text("Rate your recall")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                RatingButton(title: "Again", value: 1, action: action)
                RatingButton(title: "Hard", value: 2, action: action)
                RatingButton(title: "Good", value: 3, action: action)
                RatingButton(title: "Easy", value: 4, action: action)
            }
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
            .frame(maxWidth: .infinity)
    }
}
