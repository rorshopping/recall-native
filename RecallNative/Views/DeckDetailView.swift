import SwiftUI
import SwiftData

struct DeckDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var deck: Deck
    @State private var showingAdd = false

    var body: some View {
        List {
            ForEach(deck.cards) { card in
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.question).font(.headline)
                    Text(card.answer).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .onDelete { offsets in
                offsets.map { deck.cards[$0] }.forEach(modelContext.delete)
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

    var body: some View {
        NavigationStack {
            Form {
                Section("Question") { TextEditor(text: $question).frame(minHeight: 100) }
                Section("Answer") { TextEditor(text: $answer).frame(minHeight: 100) }
            }
            .navigationTitle("New card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let card = Flashcard(question: question, answer: answer, deck: deck)
                        deck.cards.append(card)
                        modelContext.insert(card)
                        dismiss()
                    }
                }
            }
        }
    }
}
