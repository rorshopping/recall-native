import SwiftUI
import SwiftData

struct DecksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.createdAt, order: .reverse) private var decks: [Deck]
    @State private var showingNewDeck = false
    @State private var showingPaywall = false
    @StateObject private var subscriptions = SubscriptionService()

    private var canCreateDeck: Bool {
        EntitlementRules.canCreateDeck(isPremium: subscriptions.isPremium, deckCount: decks.count)
    }

    var body: some View {
        NavigationStack {
            List {
                if decks.isEmpty {
                    ContentUnavailableView("No decks yet", systemImage: "rectangle.stack.badge.plus", description: Text("Create a deck to start learning."))
                }
                ForEach(decks) { deck in
                    NavigationLink {
                        DeckDetailView(deck: deck)
                    } label: {
                        DeckRow(deck: deck)
                    }
                }
                .onDelete { offsets in offsets.map { decks[$0] }.forEach(modelContext.delete) }
            }
            .navigationTitle("Library")
            .toolbar {
                Button {
                    if canCreateDeck { showingNewDeck = true } else { showingPaywall = true }
                } label: { Image(systemName: "plus") }
                .accessibilityLabel(canCreateDeck ? "New deck" : "Unlock more decks")
            }
            .task { await subscriptions.load() }
            .sheet(isPresented: $showingNewDeck) { NewDeckSheet() }
            .sheet(isPresented: $showingPaywall) { PaywallView(reason: "decks") }
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
