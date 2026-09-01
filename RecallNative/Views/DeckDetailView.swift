import SwiftUI
import SwiftData

struct DeckDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var deck: Deck
    @State private var showingEditor = false
    @State private var editingCard: Flashcard?
    @State private var showingReview = false

    private var sortedCards: [Flashcard] { deck.cards.sorted { $0.createdAt > $1.createdAt } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                RecallCard {
                    HStack(spacing: 16) {
                        Text(deck.emoji).font(.system(size: 42))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(deck.name).font(.title2.bold())
                            Text("\(deck.cards.count) cards · \(deck.dueCount) ready to review")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                if deck.dueCount > 0 {
                    Button { showingReview = true } label: {
                        Label("Study \(deck.dueCount) cards", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                }

                HStack {
                    Text("Cards").font(.title3.bold())
                    Spacer()
                    Button { showingEditor = true } label: { Label("Add", systemImage: "plus") }
                }

                if sortedCards.isEmpty {
                    RecallCard {
                        ContentUnavailableView("No cards yet", systemImage: "rectangle.stack.badge.plus", description: Text("Add a card manually or create cards from notes."))
                    }
                } else {
                    ForEach(sortedCards) { card in
                        Button { editingCard = card } label: {
                            RecallCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(card.question).font(.headline).multilineTextAlignment(.leading)
                                        Spacer()
                                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                                    }
                                    Text(card.answer).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                                    HStack(spacing: 6) {
                                        Text(card.statusTitle).font(.caption.weight(.medium))
                                        if card.isDue { Text("· Due now").font(.caption).foregroundStyle(.secondary) }
                                    }.foregroundStyle(RecallTheme.accent)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        offsets.map { sortedCards[$0] }.forEach(modelContext.delete)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(RecallTheme.canvas)
        .navigationTitle(deck.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Add card", systemImage: "plus") { showingEditor = true }
                    if deck.dueCount > 0 { Button("Study deck", systemImage: "play.fill") { showingReview = true } }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showingEditor) { CardEditorSheet(deck: deck) }
        .sheet(item: $editingCard) { card in CardEditorSheet(deck: deck, card: card) }
        .fullScreenCover(isPresented: $showingReview) { ReviewView(deck: deck) }
    }
}

private struct CardEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let deck: Deck
    let card: Flashcard?
    @State private var question: String
    @State private var answer: String

    init(deck: Deck, card: Flashcard? = nil) {
        self.deck = deck; self.card = card
        _question = State(initialValue: card?.question ?? "")
        _answer = State(initialValue: card?.answer ?? "")
    }

    private var valid: Bool { !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Question") { TextEditor(text: $question).frame(minHeight: 130) }
                Section("Answer") { TextEditor(text: $answer).frame(minHeight: 160) }
                if card != nil {
                    Section { Button("Delete card", role: .destructive) { if let card { modelContext.delete(card) }; dismiss() } }
                }
            }
            .navigationTitle(card == nil ? "New card" : "Edit card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(card == nil ? "Add" : "Save") {
                        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
                        let a = answer.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let card { card.question = q; card.answer = a } else { modelContext.insert(Flashcard(question: q, answer: a, deck: deck)) }
                        dismiss()
                    }.disabled(!valid)
                }
            }
        }.presentationDetents([.large])
    }
}
