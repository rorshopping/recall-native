import SwiftUI
import SwiftData

struct DecksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.createdAt, order: .reverse) private var decks: [Deck]
    @State private var showingNewDeck = false
    @State private var showingPaywall = false
    @State private var showingStudyAll = false
    @State private var searchText = ""
    @StateObject private var subscriptions = SubscriptionService()

    private var canCreateDeck: Bool {
        EntitlementRules.canCreateDeck(isPremium: subscriptions.isPremium, deckCount: decks.count)
    }

    private var filteredDecks: [Deck] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return decks }
        return decks.filter { deck in
            deck.name.localizedCaseInsensitiveContains(query) ||
            deck.cards.contains { card in
                card.question.localizedCaseInsensitiveContains(query) ||
                card.answer.localizedCaseInsensitiveContains(query) ||
                card.tags.localizedCaseInsensitiveContains(query)
            }
        }
    }

    private var totalDue: Int { decks.reduce(0) { $0 + $1.dueCount } }

    var body: some View {
        NavigationStack {
            List {
                if !decks.isEmpty {
                    Section {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Today").font(.headline)
                                Text(totalDue == 0 ? "You're all caught up" : "\(totalDue) card\(totalDue == 1 ? "" : "s") due")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if totalDue > 0 {
                                Button("Study") { showingStudyAll = true }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
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
                } else {
                    ForEach(filteredDecks) { deck in
                        NavigationLink {
                            DeckDetailView(deck: deck)
                        } label: {
                            DeckRow(deck: deck)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { filteredDecks[$0] }.forEach(modelContext.delete)
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
            .sheet(isPresented: $showingNewDeck) { NewDeckSheet() }
            .sheet(isPresented: $showingPaywall) { PaywallView(reason: "decks") }
            .fullScreenCover(isPresented: $showingStudyAll) { ReviewView(studyAll: false) }
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
                if deck.dueCount > 0 {
                    Text("\(deck.dueCount) due").font(.caption.weight(.medium)).foregroundStyle(RecallTheme.accent)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 5)
    }
}

private struct NewDeckSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var emoji = "📚"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Deck name", text: $name)
                TextField("Emoji", text: $emoji)
            }
            .navigationTitle("New deck")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        modelContext.insert(Deck(name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : name.trimmingCharacters(in: .whitespacesAndNewlines), emoji: emoji.isEmpty ? "📚" : emoji))
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
