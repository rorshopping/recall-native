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
                            Text("\(deck.cards.count) cards · \(deck.dueCount) due · \(deck.newRemainingToday) new today")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                if deck.dueCount > 0 || deck.newRemainingToday > 0 {
                    Button { showingReview = true } label: {
                        Label("Study \(deck.dueCount + min(deck.newRemainingToday, deck.newCount)) cards", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).controlSize(.large)
                }
                HStack { Text("Cards").font(.title3.bold()); Spacer(); Button { showingEditor = true } label: { Label("Add", systemImage: "plus") } }
                if sortedCards.isEmpty {
                    RecallCard { ContentUnavailableView("No cards yet", systemImage: "rectangle.stack.badge.plus", description: Text("Add a card manually or create cards from notes.")) }
                } else {
                    ForEach(sortedCards) { card in
                        Button { editingCard = card } label: {
                            RecallCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(card.question).font(.headline).multilineTextAlignment(.leading)
                                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                                    }
                                    Text(card.answer).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                                    HStack(spacing: 6) {
                                        if card.cardType == "cloze" { Text("Cloze") }
                                        if card.typeInAnswer { Text("Type-in") }
                                        Text(card.statusTitle)
                                    }.font(.caption.weight(.medium)).foregroundStyle(RecallTheme.accent)
                                }
                            }
                        }.buttonStyle(.plain)
                    }.onDelete { offsets in offsets.map { sortedCards[$0] }.forEach(modelContext.delete) }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding()
        }
        .background(RecallTheme.canvas)
        .navigationTitle(deck.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Add card", systemImage: "plus") { showingEditor = true }
                    if deck.dueCount > 0 || deck.newRemainingToday > 0 { Button("Study deck", systemImage: "play.fill") { showingReview = true } }
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
    @State private var cardType: String
    @State private var typeIn: Bool
    @State private var mediaType: String
    @State private var mediaURL: String

    init(deck: Deck, card: Flashcard? = nil) {
        self.deck = deck; self.card = card
        _question = State(initialValue: card?.question ?? "")
        _answer = State(initialValue: card?.answer ?? "")
        _hint = State(initialValue: card?.hint ?? "")
        _tags = State(initialValue: card?.tags ?? "")
        _cardType = State(initialValue: card?.cardType ?? "basic")
        _typeIn = State(initialValue: card?.typeInAnswer ?? false)
        _mediaType = State(initialValue: card?.mediaType ?? "none")
        _mediaURL = State(initialValue: card?.mediaURL ?? "")
    }

    private var valid: Bool { !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (cardType != "cloze" || question.range(of: "\\{\\{c\\d+::", options: .regularExpression) != nil) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Card type") {
                    Picker("Type", selection: $cardType) { Text("Basic").tag("basic"); Text("Cloze").tag("cloze") }.pickerStyle(.segmented)
                }
                Section(cardType == "cloze" ? "Front with {{c1::...}} markers" : "Question") {
                    TextEditor(text: $question).frame(minHeight: 130)
                    if cardType == "cloze" { Text("Example: {{c1::The capital}} of France is Paris.").font(.caption).foregroundStyle(.secondary) }
                }
                Section(cardType == "cloze" ? "Back / explanation" : "Answer") { TextEditor(text: $answer).frame(minHeight: 130) }
                Section("Optional") {
                    TextField("Hint / example", text: $hint)
                    TextField("Tags, comma separated", text: $tags)
                    Toggle("Type-in answer", isOn: $typeIn)
                    Picker("Media", selection: $mediaType) { Text("None").tag("none"); Text("Image").tag("image"); Text("Audio").tag("audio") }
                    if mediaType != "none" { TextField("Media URL or URI", text: $mediaURL).textInputAutocapitalization(.never).autocorrectionDisabled() }
                }
                if card != nil { Section { Button("Delete card", role: .destructive) { if let card { modelContext.delete(card) }; try? modelContext.save(); dismiss() } } }
            }
            .navigationTitle(card == nil ? "New card" : "Edit card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(card == nil ? "Add" : "Save") {
                        let q = question.trimmingCharacters(in: .whitespacesAndNewlines); let a = answer.trimmingCharacters(in: .whitespacesAndNewlines)
                        let m = mediaType == "none" ? nil : mediaType
                        let u = mediaType == "none" ? nil : mediaURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let card { card.question = q; card.answer = a; card.hint = hint.trimmingCharacters(in: .whitespacesAndNewlines); card.tags = tags.trimmingCharacters(in: .whitespacesAndNewlines); card.cardType = cardType; card.typeInAnswer = typeIn; card.mediaType = m; card.mediaURL = u }
                        else { modelContext.insert(Flashcard(question: q, answer: a, deck: deck, hint: hint.trimmingCharacters(in: .whitespacesAndNewlines), tags: tags.trimmingCharacters(in: .whitespacesAndNewlines), cardType: cardType, typeInAnswer: typeIn, mediaType: m, mediaURL: u)) }
                        try? modelContext.save(); dismiss()
                    }.disabled(!valid)
                }
            }
        }.presentationDetents([.large])
    }
}
