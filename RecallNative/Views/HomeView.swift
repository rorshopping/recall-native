import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var decks: [Deck]
    @Query private var cards: [Flashcard]

    var dueCount: Int { cards.filter { $0.dueAt <= .now }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Good evening")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("Keep your memory sharp.")
                            .font(.largeTitle.bold())
                            .tracking(-0.5)
                    }

                    RecallCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Ready to review?")
                                    .font(.title3.bold())
                                Text("\(dueCount) cards are waiting")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.headline)
                                .frame(width: 44, height: 44)
                                .background(RecallTheme.accent, in: Circle())
                                .foregroundStyle(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your library")
                            .font(.title3.bold())
                        if decks.isEmpty {
                            EmptyLibraryCard()
                        } else {
                            ForEach(decks.prefix(3)) { deck in
                                DeckRow(deck: deck)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
            }
            .background(RecallTheme.canvas)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct EmptyLibraryCard: View {
    var body: some View {
        RecallCard {
            Label("Create your first deck", systemImage: "plus")
                .font(.headline)
            Text("Turn a topic, note, or PDF into cards in seconds.")
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }
}
