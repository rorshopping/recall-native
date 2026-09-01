import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var decks: [Deck]
    @Query private var cards: [Flashcard]
    let onStartReview: () -> Void

    init(onStartReview: @escaping () -> Void = {}) {
        self.onStartReview = onStartReview
    }

    private var dueCount: Int { cards.filter { $0.dueAt <= .now }.count }
    private var newCount: Int { cards.filter(\.isNew).count }
    private var masteredCount: Int { cards.filter { $0.repetitions >= 3 && $0.ease >= 2.5 }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(greeting)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("Keep your memory sharp.")
                            .font(.largeTitle.bold())
                            .tracking(-0.5)
                    }

                    Button(action: onStartReview) {
                        RecallCard {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(dueCount == 0 ? "All caught up" : "Ready to review")
                                        .font(.title3.bold())
                                    Text(dueCount == 0 ? "Nice work. Check back when cards are due." : "\(dueCount) cards are waiting")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: dueCount == 0 ? "checkmark" : "arrow.right")
                                    .font(.headline)
                                    .frame(width: 44, height: 44)
                                    .background(RecallTheme.accent, in: Circle())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(dueCount == 0)
                    .opacity(dueCount == 0 ? 0.75 : 1)

                    HStack(spacing: 10) {
                        StatCard(value: "\(newCount)", label: "New")
                        StatCard(value: "\(dueCount)", label: "Due")
                        StatCard(value: "\(masteredCount)", label: "Mastered")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Your library").font(.title3.bold())
                            Spacer()
                            Text("\(decks.count) decks").font(.subheadline).foregroundStyle(.secondary)
                        }
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

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }
}

private struct StatCard: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
