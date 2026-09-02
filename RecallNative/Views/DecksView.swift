import SwiftUI
import SwiftData

enum DeckSort: String, CaseIterable, Identifiable {
    case recent = "Recently added"
    case alphabetical = "A to Z"
    case due = "Most due"
    case cards = "Most cards"

    var id: String { rawValue }
}

struct DecksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.createdAt, order: .reverse) private var decks: [Deck]
    @State private var showingNewDeck = false
    @State private var showingPaywall = false
    @State private var showingStudyAll = false
    @State private var showingCreate = false
    @State private var showingAIImport = false
    @State private var createdDeck: Deck?
    @State private var searchText = ""
    @State private var deckSort: DeckSort = .recent
    @StateObject private var subscriptions = SubscriptionService()

    private var canCreateDeck: Bool {
        EntitlementRules.canCreateDeck(isPremium: subscriptions.isPremium, deckCount: decks.count)
    }

    private var filteredDecks: [Deck] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = query.isEmpty ? decks : decks.filter { deck in
            deck.name.localizedCaseInsensitiveContains(query) ||
            deck.cards.contains { card in
                card.question.localizedCaseInsensitiveContains(query) ||
                card.answer.localizedCaseInsensitiveContains(query) ||
                card.tags.localizedCaseInsensitiveContains(query)
            }
        }

        switch deckSort {
        case .recent:
            return matching.sorted { $0.createdAt > $1.createdAt }
        case .alphabetical:
            return matching.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .due:
            return matching.sorted { lhs, rhs in
                if lhs.dueCount != rhs.dueCount { return lhs.dueCount > rhs.dueCount }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .cards:
            return matching.sorted { lhs, rhs in
                if lhs.cards.count != rhs.cards.count { return lhs.cards.count > rhs.cards.count }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    private var totalDue: Int { decks.reduce(0) { $0 + $1.dueCount } }
    private var totalNewAvailable: Int { decks.reduce(0) { $0 + $1.newRemainingToday } }
    private var totalStudyable: Int { totalDue + totalNewAvailable }

    var body: some View {
        NavigationStack {
            List {
                if !decks.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Today").font(.headline)
                                    Text(totalStudyable == 0 ? "You're all caught up" : "\(totalStudyable) card\(totalStudyable == 1 ? "" : "s") ready")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if totalStudyable > 0 {
                                    Button("Study") { showingStudyAll = true }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                }
                            }
                            HStack(spacing: 8) {
                                StudyCountPill(title: "Due", count: totalDue)
                                StudyCountPill(title: "New", count: totalNewAvailable)
                                Spacer(minLength: 0)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if filteredDecks.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No decks yet" : "No matches",
                        systemImage: searchText.isEmpty ? "rectangle.stack.badge.plus" : "magnifyingglass",
                        description: Text(searchText.isEmpty ? "Create a deck to start learning." : "Try a different deck name, question, answer, or tag.")
                    )
                    if searchText.isEmpty {
                        Section {
                            Button { showingNewDeck = true } label: {
                                Label("Create a deck", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            Button { showingCreate = true } label: {
                                Label("Generate privately on device", systemImage: "lock.shield.fill")
                            }
                            Button { showingAIImport = true } label: {
                                Label("Generate with your own AI", systemImage: "sparkles")
                            }
                        }
                    }
                } else {
                    Section {
                        ForEach(filteredDecks) { deck in
                            NavigationLink {
                                DeckDetailView(deck: deck)
                            } label: {
                                DeckRow(deck: deck)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { filteredDecks[$0] }.forEach(modelContext.delete)
                            try? modelContext.save()
                        }
                    } header: {
                        HStack {
                            Text("Decks")
                            Spacer()
                            Menu {
                                Picker("Sort", selection: $deckSort) {
                                    ForEach(DeckSort.allCases) { sort in
                                        Text(sort.rawValue).tag(sort)
                                    }
                                }
                            } label: {
                                Label(deckSort.rawValue, systemImage: "arrow.up.arrow.down")
                                    .labelStyle(.iconOnly)
                            }
                            .accessibilityLabel("Sort decks")
                            .accessibilityValue(deckSort.rawValue)
                        }
                    }
                }

                if !decks.isEmpty {
                    Section("Create") {
                        Button { showingCreate = true } label: {
                            Label("Generate privately on device", systemImage: "lock.shield.fill")
                        }
                        Button { showingAIImport = true } label: {
                            Label("Generate with your own AI", systemImage: "sparkles")
                        }
                    }
                }

                if !decks.isEmpty && !subscriptions.isPremium {
                    Section {
                        Button { showingPaywall = true } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Unlock unlimited decks & cards")
                                    .font(.headline)
                                Text("Recall Full · \(subscriptions.products.first?.displayPrice ?? "yearly subscription") / year")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search decks and cards")
            .toolbar {
                Button {
                    if canCreateDeck { showingNewDeck = true } else { showingPaywall = true }
                } label: { Image(systemName: "plus") }
                .accessibilityLabel(canCreateDeck ? "New deck" : "Unlock more decks")
            }
            .task { await subscriptions.load() }
            .sheet(isPresented: $showingNewDeck) {
                NewDeckSheet { deck in
                    createdDeck = deck
                }
            }
            .sheet(isPresented: $showingPaywall) { PaywallView(reason: "decks") }
            .sheet(isPresented: $showingCreate) { CreateView() }
            .sheet(isPresented: $showingAIImport) { AIImportView() }
            .fullScreenCover(isPresented: $showingStudyAll) { ReviewView(studyAll: false) }
            .navigationDestination(item: $createdDeck) { deck in
                DeckDetailView(deck: deck)
            }
        }
    }
}

struct DeckRow: View {
    let deck: Deck
    var body: some View {
        HStack(spacing: 14) {
            Text(deck.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 3) {
                Text(deck.name).font(.headline)
                Text("\(deck.cards.count) cards").font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    if deck.dueCount > 0 {
                        Text("\(deck.dueCount) due").font(.caption.weight(.medium))
                    }
                    if deck.newRemainingToday > 0 {
                        Text("\(deck.newRemainingToday) new").font(.caption.weight(.medium))
                    }
                }
                .foregroundStyle(RecallTheme.accent)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 5)
    }
}

private struct StudyCountPill: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 5) {
            Text("\(count)").font(.caption.weight(.bold).monospacedDigit())
            Text(title).font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.secondary.opacity(0.10), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(count) cards")
    }
}

private struct NewDeckSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var emoji = "📚"
    let onCreated: (Deck) -> Void

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedEmoji: String { emoji.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canCreate: Bool { !trimmedName.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Deck name", text: $name)
                        .textInputAutocapitalization(.sentences)
                } footer: {
                    Text("Give your deck a clear name so you can find it quickly later.")
                }

                Section("Icon") {
                    TextField("Emoji", text: $emoji)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("New deck")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard canCreate else { return }
                        let deck = Deck(name: trimmedName, emoji: trimmedEmoji.isEmpty ? "📚" : String(trimmedEmoji.prefix(2)))
                        modelContext.insert(deck)
                        try? modelContext.save()
                        onCreated(deck)
                        dismiss()
                    }
                    .disabled(!canCreate)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
