import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \ReviewLog.reviewedAt, order: .reverse) private var reviews: [ReviewLog]
    @Query private var cards: [Flashcard]
    @Query private var decks: [Deck]
    @AppStorage("dailyGoal") private var dailyGoal = 20

    private var calendar: Calendar { .current }
    private var todayReviews: Int { reviews.filter { calendar.isDateInToday($0.reviewedAt) }.count }
    private var streak: Int {
        let days = Set(reviews.map { calendar.startOfDay(for: $0.reviewedAt) })
        var cursor = calendar.startOfDay(for: .now), count = 0
        while days.contains(cursor) { count += 1; guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }; cursor = previous }
        return count
    }
    private var mastery: Int {
        guard !cards.isEmpty else { return 0 }
        let maturity = cards.reduce(0.0) { $0 + min(1, Double($1.interval) / 21.0) }
        return Int((maturity / Double(cards.count) * 100).rounded())
    }
    private var week: [(String, Int)] {
        stride(from: 6, through: 0, by: -1).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: .now) else { return nil }
            return (date.formatted(.dateTime.weekday(.abbreviated)), reviews.filter { calendar.isDate($0.reviewedAt, inSameDayAs: date) }.count)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Stats").font(.largeTitle.bold())
                    RecallCard {
                        HStack(spacing: 18) {
                            ZStack {
                                Circle().stroke(.secondary.opacity(0.18), lineWidth: 10)
                                Circle().trim(from: 0, to: min(1, Double(todayReviews) / Double(max(dailyGoal, 1)))).stroke(RecallTheme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
                                VStack(spacing: 0) { Text("\(todayReviews)").font(.title.bold()); Text("of \(dailyGoal)").font(.caption).foregroundStyle(.secondary) }
                            }.frame(width: 104, height: 104)
                            VStack(alignment: .leading, spacing: 7) {
                                Label("\(streak) day streak", systemImage: "flame.fill").font(.headline)
                                Text(todayReviews >= dailyGoal ? "Daily goal complete 🎉" : "\(Int((Double(todayReviews) / Double(max(dailyGoal, 1))) * 100))% of today's goal")
                                    .font(.subheadline).foregroundStyle(todayReviews >= dailyGoal ? .green : .secondary)
                            }
                        }
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(title: "Due today", value: "\(cards.filter { !$0.isNew && $0.isDue }.count)", subtitle: "ready to review", icon: "clock.fill")
                        StatCard(title: "Total cards", value: "\(cards.count)", subtitle: "in library", icon: "rectangle.stack.fill")
                        StatCard(title: "Reviewed", value: "\(reviews.count)", subtitle: "all time", icon: "checkmark.circle.fill")
                        StatCard(title: "Mastery", value: "\(mastery)%", subtitle: "maturity", icon: "brain.head.profile.fill")
                    }
                    RecallCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Reviews · last 7 days").font(.headline)
                            let maxCount = max(1, week.map(\.1).max() ?? 1)
                            HStack(alignment: .bottom, spacing: 8) {
                                ForEach(Array(week.enumerated()), id: \.offset) { _, item in
                                    VStack(spacing: 5) {
                                        RoundedRectangle(cornerRadius: 5).fill(RecallTheme.accent.opacity(item.1 == 0 ? 0.12 : 0.9)).frame(maxWidth: .infinity).frame(height: max(5, CGFloat(item.1) / CGFloat(maxCount) * 86))
                                        Text(item.0).font(.caption2).foregroundStyle(.secondary)
                                    }.frame(maxWidth: .infinity, maxHeight: 110, alignment: .bottom)
                                }
                            }.frame(height: 110, alignment: .bottom)
                        }
                    }
                    RecallCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Library", systemImage: "rectangle.stack").font(.headline)
                            LabeledContent("Decks", value: "\(decks.count)")
                            LabeledContent("Total reviews", value: "\(reviews.count)")
                            Divider()
                            Label("Spaced repetition", systemImage: "brain.head.profile").font(.headline)
                            Text("Cards become less frequent as you remember them. Again, Hard, Good and Easy ratings control the next interval.").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }.frame(maxWidth: 820).frame(maxWidth: .infinity).padding()
            }.background(RecallTheme.canvas).navigationTitle("Stats").navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct StatCard: View {
    let title: String; let value: String; let subtitle: String; let icon: String
    var body: some View { RecallCard { VStack(alignment: .leading, spacing: 8) { Image(systemName: icon).foregroundStyle(RecallTheme.accent); Text(value).font(.title.bold()); Text(title).font(.subheadline.weight(.semibold)); Text(subtitle).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading) } }
}
