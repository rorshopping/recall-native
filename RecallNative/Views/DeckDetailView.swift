import SwiftUI
import SwiftData

struct DeckDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var deck: Deck
    @State private var showingEditor = false
    @State private var editingCard: Flashcard?
    @State private var showingReview = false
    @State private var showingPaywall = false
    @State private var showingDeckEditor = false
    @State private var showingDeleteDeck = false
    @State private var showingStudyAllConfirmation = false
    @State private var showingNoCardsAlert = false
    @State private var studyAll = false
    @State private var cardSearch = ""
    @State private var cardSort: CardSort = .newest
    @StateObject private var subscriptions = SubscriptionService()

    private enum CardSort: String, CaseIterable, Identifiable {
        case newest, oldest, due, mastery
        var id: String { rawValue }
        var title: String {
            switch self {
            case .newest: "Newest"
            case .oldest: "Oldest"
            case .due: "Due first"
            case .mastery: "Mastery"
            }
        }
    }

    private var canAddCard: Bool {
        EntitlementRules.canCreateCard(isPremium: subscriptions.isPremium, cardCount: deck.cards.count)
    }

    private var isSampleDeck: Bool {
        (deck.name == "Spanish Basics" || deck.name == "Spanish Basics — Sample") && deck.cards.count == 6
    }

    private var visibleCards: [Flashcard] {
        let query = cardSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = query.isEmpty ? deck.cards : deck.cards.filter {
            $0.question.localizedCaseInsensitiveContains(query) ||
            $0.answer.localizedCaseInsensitiveContains(query) ||
            $0.tags.localizedCaseInsensitiveContains(query)
        }
        switch cardSort {
        case .newest:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            return filtered.sorted { $0.createdAt < $1.createdAt }
        case .due:
            return filtered.sorted { $0.dueAt < $1.dueAt }
        case .mastery:
            return filtered.sorted {
                if $0.repetitions != $1.repetitions { return $0.repetitions > $1.repetitions }
                return $0.ease > $1.ease
            }
        }
    }

    private func studyDeck() {
        if deck.cards.isEmpty {
            showingNoCardsAlert = true
        } else if deck.dueCount + deck.newRemainingToday > 0 {
            studyAll = false
            showingReview = true
        } else {
            showingStudyAllConfirmation = true
        }
    }

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

                if isSampleDeck {
                    RecallCard {
                        Label("Sample deck", systemImage: "sparkles")
                            .font(.subheadline.weight(.bold))
                        Text("Demo content to help you try Recall. You can delete this deck anytime after creating your own.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !deck.cards.isEmpty {
                    Button(action: studyDeck) {
                        Label("Study this deck", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                HStack {
                    Text("Cards").font(.title3.bold())
                    Spacer()
                    Menu {
                        Picker("Sort cards", selection: $cardSort) {
                            ForEach(CardSort.allCases) { sort in
                                Text(sort.title).tag(sort)
                            }
                        }
                    } label: {
                        Label(cardSort.title, systemImage: "arrow.up.arrow.down")
                            .font(.subheadline.weight(.medium))
                    }
                    Button {
                        if canAddCard { showingEditor = true } else { showingPaywall = true }
                    } label: {
                        Label(canAddCard ? "Add" : "Unlock", systemImage: canAddCard ? "plus" : "lock.fill")
                    }
                }

                if !deck.cards.isEmpty {
                    TextField("Search questions, answers, or tags", text: $cardSearch)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if !subscriptions.isPremium && deck.cards.count >= EntitlementRules.freeCardLimitPerDeck {
                    RecallCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Free card limit reached", systemImage: "lock.fill").font(.headline)
                            Text("Recall Full lets you keep adding cards to this deck.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button("Unlock Recall Full") { showingPaywall = true }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }

                if deck.cards.isEmpty {
                    RecallCard {
                        ContentUnavailableView("No cards yet", systemImage: "rectangle.stack.badge.plus", description: Text("Add a card manually or create cards from notes."))
                    }
                } else if visibleCards.isEmpty {
                    RecallCard {
                        ContentUnavailableView("No matching cards", systemImage: "magnifyingglass", description: Text("Try a different question, answer, or tag."))
                    }
                } else {
                    ForEach(visibleCards) { card in
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
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Edit card", systemImage: "pencil") { editingCard = card }
                            Button("Delete card", systemImage: "trash", role: .destructive) {
                                modelContext.delete(card)
                                try? modelContext.save()
                            }
                        }
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
                    Button("Edit deck", systemImage: "pencil") { showingDeckEditor = true }
                    Button("Add card", systemImage: canAddCard ? "plus" : "lock.fill") {
                        if canAddCard { showingEditor = true } else { showingPaywall = true }
                    }
                    if !deck.cards.isEmpty {
                        Button("Study deck", systemImage: "play.fill") { studyDeck() }
                    }
                    Divider()
                    Button("Delete deck", systemImage: "trash", role: .destructive) { showingDeleteDeck = true }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .task { await subscriptions.load() }
        .sheet(isPresented: $showingEditor) { CardEditorSheet(deck: deck) }
        .sheet(item: $editingCard) { card in CardEditorSheet(deck: deck, card: card) }
        .sheet(isPresented: $showingDeckEditor) { DeckEditorSheet(deck: deck) }
        .sheet(isPresented: $showingPaywall) { PaywallView(reason: "cards") }
        .fullScreenCover(isPresented: $showingReview) { ReviewView(deck: deck, studyAll: studyAll) }
        .alert("Nothing to study", isPresented: $showingStudyAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Study all") {
                studyAll = true
                showingReview = true
            }
        } message: {
            Text("All \(deck.cards.count) cards are scheduled for later. Study them all now anyway?")
        }
        .alert("No cards yet", isPresented: $showingNoCardsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Add cards to this deck first.")
        }
        .confirmationDialog("Delete this deck?", isPresented: $showingDeleteDeck, titleVisibility: .visible) {
            Button("Delete Deck", role: .destructive) {
                modelContext.delete(deck)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes \(deck.cards.count) cards and their study history from this device. This cannot be undone.")
        }
    }
}

private struct DeckEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var deck: Deck
    @State private var name: String
    @State private var emoji: String

    init(deck: Deck) {
        self.deck = deck
        _name = State(initialValue: deck.name)
        _emoji = State(initialValue: deck.emoji)
    }

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Deck") {
                    TextField("Name", text: $name)
                    TextField("Emoji", text: $emoji)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("New cards") {
                    Stepper("Daily new-card limit · \(deck.newLimit)", value: $deck.newLimit, in: 1...200)
                    Text("Controls how many new cards from this deck can enter a study session each day.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit deck")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        deck.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
                        deck.emoji = trimmedEmoji.isEmpty ? "📚" : String(trimmedEmoji.prefix(2))
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(!valid)
                }
            }
        }
        .presentationDetents([.medium])
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
