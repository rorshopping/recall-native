import SwiftUI
import SwiftData

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let deck: Deck?
    let studyAll: Bool
    @Query(sort: \Flashcard.dueAt) private var cards: [Flashcard]
    @State private var queueIDs: [UUID] = []
    @State private var reviewed = 0
    @State private var revealed = false
    @State private var completed = false
    @State private var typed = ""
    @State private var typeChecked: Bool?

    init(deck: Deck? = nil, studyAll: Bool = false) { self.deck = deck; self.studyAll = studyAll }

    private var scopedCards: [Flashcard] { cards.filter { deck == nil || $0.deck?.id == deck?.id } }
    private var currentCard: Flashcard? { guard let id = queueIDs.first else { return nil }; return cards.first { $0.id == id } }
    private var initialCandidates: [Flashcard] {
        if studyAll { return scopedCards }
        let now = Date.now
        let candidates = scopedCards.filter { !$0.isNew && $0.dueAt <= now }
        let fresh = scopedCards.filter(\.isNew).prefix(deck?.newRemainingToday ?? scopedCards.count)
        return candidates + fresh
    }

    var body: some View {
        NavigationStack {
            Group {
                if completed { completionView }
                else if queueIDs.isEmpty { emptyView }
                else if let card = currentCard { studyCard(card) }
                else { emptyView }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .task {
                guard queueIDs.isEmpty && !completed else { return }
                queueIDs = initialCandidates.map(\.id)
            }
        }
    }

    private func studyCard(_ card: Flashcard) -> some View {
        VStack(spacing: 18) {
            HStack {
                Text(deck?.name ?? "Review").font(.headline)
                Spacer()
                Text("\(reviewed + 1) / \(max(reviewed + queueIDs.count, 1))").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(reviewed), total: Double(max(reviewed + queueIDs.count, 1))).tint(RecallTheme.accent)

            RecallCard {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(revealed ? "ANSWER" : "QUESTION")
                            .font(.caption.weight(.bold)).foregroundStyle(RecallTheme.accent).tracking(1)
                        if card.mediaType == "image", let url = card.mediaURL, let imageURL = URL(string: url) {
                            AsyncImage(url: imageURL) { phase in
                                if let image = phase.image { image.resizable().scaledToFit().frame(maxHeight: 240) }
                                else if phase.error != nil { Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary) }
                                else { ProgressView() }
                            }
                        }
                        Text(card.clozeText(revealed: revealed))
                            .font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)
                        if revealed && !card.hint.isEmpty {
                            Text("Hint: \(card.hint)").font(.subheadline).foregroundStyle(.secondary)
                        }
                        if !revealed { Text("Tap to reveal the answer").font(.subheadline).foregroundStyle(.secondary) }
                    }
                }
            }
            .frame(maxWidth: 760, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.snappy(duration: 0.25)) { revealed = true } }

            if revealed && card.typeInAnswer { typeIn(card) }
            else if revealed { ratings }
            else { Text("How well did you remember it?").font(.caption).foregroundStyle(.secondary) }
        }
        .padding()
    }

    private var ratings: some View {
        HStack(spacing: 8) {
            RatingButton(title: "Again", value: 0, action: rate)
            RatingButton(title: "Hard", value: 1, action: rate)
            RatingButton(title: "Good", value: 2, action: rate)
            RatingButton(title: "Easy", value: 3, action: rate)
        }
    }

    private func typeIn(_ card: Flashcard) -> some View {
        VStack(spacing: 10) {
            TextField("Type your answer", text: $typed)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if let typeChecked {
                Text(typeChecked ? "✓ Correct" : "✗ Answer: \(card.answer)")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(typeChecked ? .green : .red)
            }
            Button("Check") {
                typeChecked = typed.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(card.answer.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
            }.buttonStyle(.borderedProminent)
            if typeChecked != nil { ratings }
        }
        .frame(maxWidth: 760)
    }

    private var completionView: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(RecallTheme.accent)
            Text("Session complete").font(.largeTitle.bold())
            Text("You reviewed \(reviewed) card\(reviewed == 1 ? "" : "s"). Nice work.").foregroundStyle(.secondary)
            Button("Study again") {
                queueIDs = initialCandidates.map(\.id); reviewed = 0; completed = false; revealed = false; typed = ""; typeChecked = nil
            }.buttonStyle(.borderedProminent)
            Button("Done") { dismiss() }.buttonStyle(.bordered)
        }.padding(32)
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 60)).foregroundStyle(RecallTheme.accent)
            Text("Nothing due right now").font(.title.bold())
            Text("All caught up. Your next reviews will appear here when they are due.").foregroundStyle(.secondary).multilineTextAlignment(.center)
            if !studyAll && !scopedCards.isEmpty {
                Button("Study all \(scopedCards.count) cards") {
                    queueIDs = scopedCards.map(\.id); reviewed = 0; completed = false
                }.buttonStyle(.borderedProminent)
            }
            Button("Done") { dismiss() }.buttonStyle(.bordered)
        }.padding(32)
    }

    private func rate(_ grade: Int) {
        guard let card = currentCard else { return }
        let result = SpacedRepetitionService.schedule(state: card.state, step: card.step, repetitions: card.repetitions, interval: card.interval, ease: card.ease, grade: grade)
        card.state = result.state
        card.step = result.step
        card.repetitions = result.repetitions
        card.interval = result.interval
        card.ease = result.ease
        card.dueAt = result.dueAt
        card.lastReviewedAt = .now
        if grade == 0 { card.lapses += 1 }
        if let deck {
            let today = Date.now.formatted(.dateTime.year().month().day())
            if card.isNew || deck.newDay != today { deck.newDay = today; if card.isNew { deck.newStudiedToday += 1 } }
        }
        modelContext.insert(ReviewLog(rating: grade + 1, card: card))
        try? modelContext.save()

        let wasAgain = grade == 0
        queueIDs.removeFirst()
        if wasAgain { queueIDs.append(card.id) }
        reviewed += 1
        revealed = false
        typed = ""
        typeChecked = nil
        if queueIDs.isEmpty { completed = true }
    }
}

private struct RatingButton: View {
    let title: String; let value: Int; let action: (Int) -> Void
    var body: some View { Button(title) { action(value) }.buttonStyle(.borderedProminent).controlSize(.small).frame(maxWidth: .infinity) }
}
