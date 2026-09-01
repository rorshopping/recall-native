import SwiftUI
import SwiftData

struct DeckDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var deck: Deck
    @State private var showingAdd = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 18) {
                    Text(deck.emoji).font(.system(size: 44))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(deck.cards.count) cards")
                            .font(.title3.bold())
                        Text("\(deck.dueCount) ready to review")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            Section("Cards") {
                if deck.cards.isEmpty {
                    ContentUnavailableView("No cards yet", systemImage: "rectangle.stack.badge.plus", description: Text("Add one manually or create cards from notes."))
                } else {
                    ForEach(deck.cards.sorted { $0.createdAt > $1.createdAt }) { card in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(card.question)
                                .font(.headline)
                                .lineLimit(3)
                            Text(card.answer)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        .padding(.vertical, 5)
                    }
                    .onDelete { offsets in
                        let sorted = deck.cards.sorted { $0.createdAt > $1.createdAt }
                        offsets.map { sorted[$0] }.forEach(modelContext.delete)
                    }
                }
            }
        }
        .navigationTitle(deck.name)
        .toolbar {
            Button { showingAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showingAdd) { AddCardSheet(deck: deck) }
    }
}

private struct AddCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let deck: Deck
    @State private var question = ""
    @State private var answer = ""

    private var canAdd: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Question") {
                    TextEditor(text: $question)
                        .frame(minHeight: 110)
                }
                Section("Answer") {
                    TextEditor(text: $answer)
                        .frame(minHeight: 110)
                }
            }
            .navigationTitle("New card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let card = Flashcard(question: question.trimmingCharacters(in: .whitespacesAndNewlines), answer: answer.trimmingCharacters(in: .whitespacesAndNewlines), deck: deck)
                        modelContext.insert(card)
                        dismiss()
                    }
                    .disabled(!canAdd)
                }
            }
        }
        .presentationDetents([.large])
    }
}
