import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \ReviewLog.reviewedAt, order: .reverse) private var reviews: [ReviewLog]
    @Query private var cards: [Flashcard]
    @Query private var decks: [Deck]
    @AppStorage("dailyGoal") private var dailyGoal = 20
    @State private var showingHistory = false

    private var calendar: Calendar { Calendar.current }
    private var metrics: ReviewMetrics { ReviewMetrics(reviews: reviews, aggregateHistory: ReviewHistoryStore.load(), calendar: calendar) }
    private var todayReviews: Int { metrics.count(on: .now) }
    private var currentStreak: Int { metrics.activeStreak(endingOn: .now) }
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
                    HStack {
                        Text("REVIEW QUALITY").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)
                        Spacer()
                        if !reviews.isEmpty {
                            Button("History") { showingHistory = true }.font(.caption.weight(.semibold)).accessibilityLabel("Review history")
                        }
                    }
                    RecallCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Recall quality").font(.headline)
                                    Text("How your recent answers are distributed").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(metrics.positiveRate)% positive").font(.caption.weight(.semibold)).foregroundStyle(RecallTheme.accent)
                            }
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(metrics.averageRating, format: .number.precision(.fractionLength(1))).font(.title3.bold())
                                    Text("average rating / 4").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(metrics.total) responses").font(.subheadline.weight(.semibold))
                                    Text("last 7 days: \(metrics.count(from: calendar.date(byAdding: .day, value: -6, to: .now) ?? .now, through: .now))").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            QualityBar(label: "Again", count: metrics.ratingCounts[1, default: 0], total: metrics.total)
                            QualityBar(label: "Hard", count: metrics.ratingCounts[2, default: 0], total: metrics.total)
                            QualityBar(label: "Good", count: metrics.ratingCounts[3, default: 0], total: metrics.total)
                            QualityBar(label: "Easy", count: metrics.ratingCounts[4, default: 0], total: metrics.total)
                        }
                    }
                    Text("REVIEWS · LAST 7 DAYS").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)
                    RecallCard { WeeklyBars(values: week) }
                    RecallCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Library").font(.headline)
                            InfoRow(title: "Decks", value: "\(decks.count)", icon: "rectangle.stack")
                            Divider(); InfoRow(title: "New cards", value: "\(newCount)", icon: "sparkles")
                            Divider(); InfoRow(title: "Due cards", value: "\(dueCount)", icon: "clock")
                            Divider(); InfoRow(title: "Total reviews", value: "\(metrics.total)", icon: "arrow.clockwise")
                        }
                    }
                    RecallCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Spaced repetition", systemImage: "brain.head.profile").font(.headline)
                            Text("Recall schedules cards based on how well you remember them. Keep reviewing regularly to build longer intervals.").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Text("Recall stores everything on your device, free, with no account required.").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding()
            }
            .background(RecallTheme.canvas)
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingHistory) { ReviewHistoryView(reviews: reviews) }
        }
    }
}

private enum ReviewHistoryFilter: String, CaseIterable, Identifiable {
    case all, again, hard, good, easy
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var rating: Int? { switch self { case .all: nil; case .again: 1; case .hard: 2; case .good: 3; case .easy: 4 } }
}

private struct ReviewHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let reviews: [ReviewLog]
    @State private var searchText = ""
    @State private var filter: ReviewHistoryFilter = .all
    private var filteredReviews: [ReviewLog] {
        reviews.filter { review in
            let matchesRating = filter.rating.map { review.rating == $0 } ?? true
            guard matchesRating, !searchText.isEmpty else { return matchesRating }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
            return (review.card?.question.localizedLowercase.contains(query) ?? false) || (review.card?.answer.localizedLowercase.contains(query) ?? false)
        }
    }
    var body: some View {
        NavigationStack {
            Group {
                if reviews.isEmpty { ContentUnavailableView("No reviews yet", systemImage: "clock.arrow.circlepath", description: Text("Your completed reviews will appear here.")) }
                else if filteredReviews.isEmpty { ContentUnavailableView("No matching reviews", systemImage: "magnifyingglass", description: Text("Try another search or rating filter.")) }
                else { List(filteredReviews) { ReviewHistoryRow(review: $0) }.listStyle(.plain) }
            }
            .searchable(text: $searchText, prompt: "Search cards")
            .navigationTitle("Review history").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu { Picker("Rating", selection: $filter) { ForEach(ReviewHistoryFilter.allCases) { Text($0.title).tag($0) } } } label: { Label(filter.title, systemImage: filter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill") }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

private struct ReviewHistoryRow: View {
    let review: ReviewLog
    private var ratingTitle: String { ["Review", "Again", "Hard", "Good", "Easy"].indices.contains(review.rating) ? ["Review", "Again", "Hard", "Good", "Easy"][review.rating] : "Review" }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: ratingIcon).font(.headline).foregroundStyle(ratingColor).frame(width: 30, height: 30).background(ratingColor.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(review.card?.question ?? "Card no longer available").font(.subheadline.weight(.semibold)).lineLimit(2)
                HStack(spacing: 6) { Text(ratingTitle).font(.caption.weight(.medium)).foregroundStyle(ratingColor); Text("·").foregroundStyle(.tertiary); Text(review.reviewedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
        }.padding(.vertical, 5).accessibilityElement(children: .combine)
    }
    private var ratingIcon: String { ["checkmark.circle", "arrow.uturn.backward", "minus", "checkmark", "bolt.fill"].indices.contains(review.rating) ? ["checkmark.circle", "arrow.uturn.backward", "minus", "checkmark", "bolt.fill"][review.rating] : "checkmark.circle" }
    private var ratingColor: Color { switch review.rating { case 1: .red; case 2: .orange; case 3: RecallTheme.accent; case 4: .green; default: .secondary } }
}

private struct GoalRing: View {
    let progress: Double; let value: Int; let goal: Int
    var body: some View {
        ZStack { Circle().stroke(.secondary.opacity(0.15), lineWidth: 10); Circle().trim(from: 0, to: progress).stroke(RecallTheme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90)); VStack(spacing: 0) { Text("\(value)").font(.title2.bold()); Text("of \(goal)").font(.caption2).foregroundStyle(.secondary) } }.frame(width: 108, height: 108).accessibilityLabel("Reviews today: \(value) of \(goal)")
    }
}
private struct WeeklyBars: View {
    let values: [(label: String, count: Int, today: Bool)]
    private var maxValue: Int { max(1, values.map(\.count).max() ?? 1) }
    var body: some View { HStack(alignment: .bottom, spacing: 8) { ForEach(Array(values.enumerated()), id: \.offset) { _, item in VStack(spacing: 6) { Spacer(minLength: 0); RoundedRectangle(cornerRadius: 6).fill(item.today ? RecallTheme.accent : .secondary.opacity(item.count > 0 ? 0.5 : 0.12)).frame(height: max(5, CGFloat(item.count) / CGFloat(maxValue) * 90)); Text(item.label).font(.caption2).foregroundStyle(item.today ? RecallTheme.accent : .secondary) }.frame(maxWidth: .infinity) } }.frame(height: 120) }
}
private struct StatCard: View {
    let title: String; let value: String; let icon: String
    var body: some View { RecallCard { VStack(alignment: .leading, spacing: 8) { Image(systemName: icon).foregroundStyle(RecallTheme.accent); Text(value).font(.title.bold()); Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading) } }
}
private struct QualityBar: View {
    let label: String; let count: Int; let total: Int
    private var fraction: Double { total > 0 ? Double(count) / Double(total) : 0 }
    var body: some View { HStack(spacing: 10) { Text(label).font(.caption.weight(.semibold)).frame(width: 42, alignment: .leading); GeometryReader { proxy in Capsule().fill(.secondary.opacity(0.12)).overlay(alignment: .leading) { Capsule().fill(RecallTheme.accent).frame(width: proxy.size.width * fraction) } }.frame(height: 8); Text("\(count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(minWidth: 24, alignment: .trailing) }.frame(height: 18) }
}
private struct InfoRow: View {
    let title: String; let value: String; let icon: String
    var body: some View { HStack { Label(title, systemImage: icon); Spacer(); Text(value).font(.headline) } }
}
