import SwiftUI
import SwiftData

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let deck: Deck?
    @Query(sort: \Flashcard.dueAt) private var cards: [Flashcard]
    @State private var index = 0
    @State private var revealed = false
    @State private var completed = false

    init(deck: Deck? = nil) { self.deck = deck }
    private var dueCards: [Flashcard] { cards.filter { $0.isDue && (deck == nil || $0.deck?.id == deck?.id) } }

    var body: some View {
        NavigationStack {
            Group {
                if completed || dueCards.isEmpty {
                    VStack(spacing: 18) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(RecallTheme.accent)
                        Text("Session complete").font(.largeTitle.bold())
                        Text(completed ? "You reviewed \(index) cards. Nice work." : "There are no cards due right now.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }.padding(32)
                } else {
                    let card = dueCards[min(index, dueCards.count - 1)]
                    VStack(spacing: 18) {
                        HStack { Text(deck?.name ?? "Review").font(.headline); Spacer(); Text("\(index + 1) / \(dueCards.count)").font(.subheadline.weight(.medium)).foregroundStyle(.secondary) }
                        ProgressView(value: Double(index), total: Double(max(dueCards.count, 1))).tint(RecallTheme.accent)
                        Spacer(minLength: 10)
                        RecallCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("QUESTION").font(.caption.weight(.bold)).foregroundStyle(RecallTheme.accent).tracking(1)
                                Text(card.question).font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)
                                if revealed {
                                    Divider(); Text("ANSWER").font(.caption.weight(.bold)).foregroundStyle(.secondary).tracking(1); Text(card.answer).font(.body)
                                } else { Text("Tap to reveal the answer").font(.subheadline).foregroundStyle(.secondary).padding(.top, 8) }
                            }
                        }.contentShape(Rectangle()).onTapGesture { withAnimation(.snappy(duration: 0.25)) { revealed.toggle() } }
                        Spacer(minLength: 10)
                        if revealed { HStack(spacing: 8) { RatingButton(title: "Again", value: 0, action: rate); RatingButton(title: "Hard", value: 1, action: rate); RatingButton(title: "Good", value: 2, action: rate); RatingButton(title: "Easy", value: 3, action: rate) } }
                        else { Text("How well did you remember it?").font(.caption).foregroundStyle(.secondary) }
                    }.padding()
                }
            }.navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func rate(_ grade: Int) {
        let card = dueCards[index]
        let result = SpacedRepetitionService.schedule(state: card.state, step: card.step, repetitions: card.repetitions, interval: card.interval, ease: card.ease, grade: grade)
        card.state = result.state; card.step = result.step; card.repetitions = result.repetitions; card.interval = result.interval; card.ease = result.ease; card.dueAt = result.dueAt; card.lastReviewedAt = .now
        if grade == 0 { card.lapses += 1 }
        modelContext.insert(ReviewLog(rating: grade + 1, card: card))
        withAnimation(.snappy(duration: 0.2)) { revealed = false; if index + 1 >= dueCards.count { completed = true } else { index += 1 } }
    }
}

private struct RatingButton: View {
    let title: String; let value: Int; let action: (Int) -> Void
    var body: some View { Button(title) { action(value) }.buttonStyle(.borderedProminent).controlSize(.small).frame(maxWidth: .infinity) }
}
