import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \ReviewLog.reviewedAt, order: .reverse) private var reviews: [ReviewLog]
    @Query private var cards: [Flashcard]
    @Query private var decks: [Deck]

    private var todayReviews: Int {
        let calendar = Calendar.current
        return reviews.filter { calendar.isDateInToday($0.reviewedAt) }.count
    }

    private var streak: Int {
        let calendar = Calendar.current
        let days = Set(reviews.map { calendar.startOfDay(for: $0.reviewedAt) })
        var cursor = calendar.startOfDay(for: Date())
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    private var mastery: Int {
        guard !cards.isEmpty else { return 0 }
        return Int((Double(cards.filter { $0.repetitions >= 3 }.count) / Double(cards.count) * 100).rounded())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Stats").font(.largeTitle.bold())
                        Text("See how your memory is building over time.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(title: "Today", value: "\(todayReviews)", subtitle: "reviews", icon: "checkmark.circle.fill")
                        StatCard(title: "Streak", value: "\(streak)", subtitle: streak == 1 ? "day" : "days", icon: "flame.fill")
                        StatCard(title: "Cards", value: "\(cards.count)", subtitle: "in library", icon: "rectangle.stack.fill")
                        StatCard(title: "Mastery", value: "\(mastery)%", subtitle: "learned", icon: "brain.head.profile.fill")
                    }

                    RecallCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Library").font(.headline)
                            HStack {
                                Label("Decks", systemImage: "rectangle.stack")
                                Spacer()
                                Text("\(decks.count)").font(.headline)
                            }
                            Divider()
                            HStack {
                                Label("Total reviews", systemImage: "arrow.clockwise")
                                Spacer()
                                Text("\(reviews.count)").font(.headline)
                            }
                        }
                    }

                    RecallCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Spaced repetition", systemImage: "brain.head.profile")
                                .font(.headline)
                            Text("Recall schedules cards based on how well you remember them. Keep reviewing regularly to build longer intervals.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(RecallTheme.canvas)
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String

    var body: some View {
        RecallCard {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: icon)
                    .foregroundStyle(RecallTheme.accent)
                Text(value).font(.title.bold())
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
