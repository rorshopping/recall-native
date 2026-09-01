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
                            Text("\(deck.cards.count) cards · \(deck.dueCount) due · \(deck.newCount) new")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                if deck.dueCount + deck.newRemainingToday > 0 {
                    Button { showingReview = true } label: {
                        Label("Study \(deck.dueCount + deck.newRemainingToday) cards", systemImage: "play.fill")
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
                                        if card.type == "cloze" { Text("· Cloze").font(.caption) }
                                        if card.typeInAnswer { Text("· Type-in").font(.caption) }
                                        if card.mediaType != nil { Image(systemName: card.mediaType == "audio" ? "waveform" : "photo") }
                                    }.foregroundStyle(RecallTheme.accent)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                    .onDelete { offsets in offsets.map { sortedCards[$0] }.forEach(modelContext.delete) }
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
                    if deck.dueCount + deck.newRemainingToday > 0 { Button("Study deck", systemImage: "play.fill") { showingReview = true } }
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
    @State private var hint: String
    @State private var tags: String
    @State private var type: String
    @State private var typeIn: Bool
    @State private var mediaType: String
    @State private var mediaURI: String
    @State private var errorMessage: String?

    init(deck: Deck, card: Flashcard? = nil) {
        self.deck = deck
        self.card = card
        _question = State(initialValue: card?.question ?? "")
        _answer = State(initialValue: card?.answer ?? "")
        _hint = State(initialValue: card?.hint ?? "")
        _tags = State(initialValue: card?.tags ?? "")
        _type = State(initialValue: card?.type ?? "basic")
        _typeIn = State(initialValue: card?.typeInAnswer ?? false)
        _mediaType = State(initialValue: card?.mediaType ?? "none")
        _mediaURI = State(initialValue: card?.mediaURI ?? "")
    }

    private var valid: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if let card {
                    Section("This card") {
                        HStack {
                            stat("Lapses", card.lapses)
                            stat("Again", card.againCount)
                            stat("Hard", card.hardCount)
                            stat("Good", card.goodCount)
                            stat("Easy", card.easyCount)
                        }
                        Text("Ease \(card.ease, specifier: "%.2f") · interval \(card.interval)d · \(card.statusTitle)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Card type") {
                    Picker("Type", selection: $type) {
                        Text("Basic").tag("basic")
                        Text("Cloze").tag("cloze")
                    }
                    .pickerStyle(.segmented)
                }

                Section(type == "cloze" ? "Front with cloze markers" : "Front") {
                    TextEditor(text: $question).frame(minHeight: 130)
                    if type == "cloze" {
                        Text("Use {{c1::answer}} in the front. Multiple deletions can use c1, c2, and so on.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section(type == "cloze" ? "Back / explanation" : "Back") {
                    TextEditor(text: $answer).frame(minHeight: 140)
                }

                Section("Optional") {
                    TextField("Hint / example", text: $hint)
                    TextField("Tags, comma separated", text: $tags)
                    Toggle("Type-in answer", isOn: $typeIn)
                    Text("Type-in asks you to enter the answer before revealing it.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Media") {
                    Picker("Media", selection: $mediaType) {
                        Text("None").tag("none")
                        Text("Image").tag("image")
                        Text("Audio").tag("audio")
                    }
                    .pickerStyle(.segmented)
                    if mediaType != "none" {
                        TextField(mediaType == "image" ? "Image URL or local file path" : "Audio URL or local file path", text: $mediaURI)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Text("Media is optional. Use an https URL or a local file path available to the app.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
                }

                if card != nil {
                    Section { Button("Delete card", role: .destructive) { if let card { modelContext.delete(card) }; dismiss() } }
                }
            }
            .navigationTitle(card == nil ? "New card" : "Edit card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(card == nil ? "Add" : "Save") { save() }.disabled(!valid)
                }
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder private func stat(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.caption.bold())
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }

    private func save() {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !a.isEmpty else { return }
        if type == "cloze" && q.range(of: #"\{\{c\d+::[^}]+\}\}"#, options: .regularExpression) == nil {
            errorMessage = "Cloze cards need at least one {{c1::...}} marker in the front."
            return
        }
        if mediaType != "none" && mediaURI.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Enter a media URL or file path, or select None."
            return
        }
        if let card {
            card.question = q
            card.answer = a
            card.hint = hint.trimmingCharacters(in: .whitespacesAndNewlines)
            card.tags = tags.trimmingCharacters(in: .whitespacesAndNewlines)
            card.type = type
            card.typeInAnswer = typeIn
            card.mediaType = mediaType == "none" ? nil : mediaType
            card.mediaURI = mediaType == "none" ? nil : mediaURI.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let newCard = Flashcard(question: q, answer: a, deck: deck)
            newCard.hint = hint.trimmingCharacters(in: .whitespacesAndNewlines)
            newCard.tags = tags.trimmingCharacters(in: .whitespacesAndNewlines)
            newCard.type = type
            newCard.typeInAnswer = typeIn
            newCard.mediaType = mediaType == "none" ? nil : mediaType
            newCard.mediaURI = mediaType == "none" ? nil : mediaURI.trimmingCharacters(in: .whitespacesAndNewlines)
            modelContext.insert(newCard)
        }
        try? modelContext.save()
        dismiss()
    }
}
