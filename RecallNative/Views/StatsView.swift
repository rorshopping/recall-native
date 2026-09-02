import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \ReviewLog.reviewedAt, order: .reverse) private var reviews: [ReviewLog]
    @Query private var cards: [Flashcard]
    @Query private var decks: [Deck]
    @AppStorage("dailyGoal") private var dailyGoal = 20

    private var calendar: Calendar { Calendar.current }
    private var metrics: ReviewMetrics { ReviewMetrics(reviews: reviews, calendar: calendar) }
    private var todayReviews: Int { metrics.count(on: .now) }
    private var reviewDays: Set<Date> { Set(reviews.map { calendar.startOfDay(for: $0.reviewedAt) }) }
    private var currentStreak: Int {
        var cursor = calendar.startOfDay(for: .now)
        if !reviewDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor), reviewDays.contains(yesterday) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while reviewDays.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
    private var streakAtRisk: Bool { currentStreak > 0 && todayReviews == 0 }
    private var mastery: Int {
        guard !cards.isEmpty else { return 0 }
        let maturity = cards.reduce(0.0) { $0 + min(1.0, Double($1.interval) / 21.0) }
        return Int((maturity / Double(cards.count) * 100).rounded())
    }
    private var dueCount: Int { cards.filter { !$0.isNew && $0.isDue }.count }
    private var newCount: Int { cards.filter(\.isNew).count }
    private var week: [(label: String, count: Int, today: Bool)] {
        (0..<7).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: .now) ?? .now
            return (date.formatted(.dateTime.weekday(.abbreviated)), metrics.count(on: date), offset == 0)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Stats").font(.largeTitle.bold())
                    RecallCard {
                        HStack(spacing: 20) {
                            GoalRing(progress: min(1, Double(todayReviews) / Double(max(1, dailyGoal))), value: todayReviews, goal: dailyGoal)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    Text("🔥").font(.title2)
                                    VStack(alignment: .leading) {
                                        Text("\(currentStreak)").font(.title.bold())
                                        Text("day streak").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Text(streakAtRisk ? "Study today to keep it 🔥" : "\(newCount) new cards").font(.caption.weight(.semibold)).foregroundStyle(streakAtRisk ? .orange : .secondary)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    Text(todayReviews >= dailyGoal ? "Daily goal complete 🎉" : "\(Int((Double(todayReviews) / Double(max(1, dailyGoal)) * 100).rounded()))% of your daily goal")
                        .font(.caption.weight(.semibold)).foregroundStyle(todayReviews >= dailyGoal ? .green : .secondary).padding(.horizontal, 4)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(title: "Due today", value: "\(dueCount)", icon: "clock.fill")
                        StatCard(title: "Total cards", value: "\(cards.count)", icon: "rectangle.stack.fill")
                        StatCard(title: "Reviewed", value: "\(metrics.total)", icon: "checkmark.circle.fill")
                        StatCard(title: "Mastery", value: "\(mastery)%", icon: "brain.head.profile.fill")
                    }
                    Text("REVIEWS · LAST 7 DAYS").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)
                    RecallCard { WeeklyBars(values: week) }
                    RecallCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Library").font(.headline)
                            InfoRow(title: "Decks", value: "\(decks.count)", icon: "rectangle.stack")
                            Divider()
                            InfoRow(title: "New cards", value: "\(newCount)", icon: "sparkles")
                            Divider()
                            InfoRow(title: "Due cards", value: "\(dueCount)", icon: "clock")
                            Divider()
                            InfoRow(title: "Total reviews", value: "\(metrics.total)", icon: "arrow.clockwise")
                        }
                    }
                    RecallCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Spaced repetition", systemImage: "brain.head.profile").font(.headline)
                            Text("Recall schedules cards based on how well you remember them. Keep reviewing regularly to build longer intervals.").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Text("Recall stores everything on your device, free, with no account required.").font(.caption).foregroundStyle(.secondary)
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

private struct GoalRing: View {
    let progress: Double; let value: Int; let goal: Int
    var body: some View {
        ZStack {
            Circle().stroke(.secondary.opacity(0.15), lineWidth: 10)
            Circle().trim(from: 0, to: progress).stroke(RecallTheme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
            VStack(spacing: 0) { Text("\(value)").font(.title2.bold()); Text("of \(goal)").font(.caption2).foregroundStyle(.secondary) }
        }.frame(width: 108, height: 108).accessibilityLabel("Reviews today: \(value) of \(goal)")
    }
}
private struct WeeklyBars: View {
    let values: [(label: String, count: Int, today: Bool)]
    private var maxValue: Int { max(1, values.map(\.count).max() ?? 1) }
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 6) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 6).fill(item.today ? RecallTheme.accent : .secondary.opacity(item.count > 0 ? 0.5 : 0.12)).frame(height: max(5, CGFloat(item.count) / CGFloat(maxValue) * 90))
                    Text(item.label).font(.caption2).foregroundStyle(item.today ? RecallTheme.accent : .secondary)
                }.frame(maxWidth: .infinity)
            }
        }.frame(height: 120)
    }
}
private struct StatCard: View {
    let title: String; let value: String; let icon: String
    var body: some View { RecallCard { VStack(alignment: .leading, spacing: 8) { Image(systemName: icon).foregroundStyle(RecallTheme.accent); Text(value).font(.title.bold()); Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading) } }
}
private struct InfoRow: View {
    let title: String; let value: String; let icon: String
    var body: some View { HStack { Label(title, systemImage: icon); Spacer(); Text(value).font(.headline) } }
}
