import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var decks: [Deck]
    @Query private var cards: [Flashcard]
    @Query(sort: \\ReviewLog.reviewedAt, order: .reverse) private var reviews: [ReviewLog]
    @AppStorage("dailyGoal") private var dailyGoal = 20
    let onStartReview: () -> Void
    let onCreate: () -> Void

    init(onStartReview: @escaping () -> Void = {}, onCreate: @escaping () -> Void = {}) {
        self.onStartReview = onStartReview
        self.onCreate = onCreate
    }

    private var calendar: Calendar { Calendar.current }
    private var metrics: ReviewMetrics { ReviewMetrics(reviews: reviews, calendar: calendar) }
    private var dueCount: Int { cards.filter { !$0.isNew && $0.isDue }.count }
    private var newCount: Int { cards.filter(\\.isNew).count }
    private var studyableCount: Int { dueCount + min(newCount, decks.reduce(0) { $0 + $1.newRemainingToday }) }
    private var masteredCount: Int { cards.filter { $0.repetitions >= 3 && $0.ease >= 2.5 }.count }
    private var todayReviews: Int { metrics.count(on: .now) }
    private var currentStreak: Int { metrics.activeStreak(endingOn: .now) }
    private var goalProgress: Double { min(1, Double(todayReviews) / Double(max(1, dailyGoal))) }
    private var recentReviews: [ReviewLog] { Array(reviews.prefix(3)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    Text("Keep your memory sharp.").font(.largeTitle.bold()).tracking(-0.5)
                }

                Button(action: onStartReview) {
                    RecallCard {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(studyableCount == 0 ? "All caught up" : "Ready to review").font(.title3.bold())
                                Text(studyableCount == 0 ? "Nice work. Check back when cards are due." : "\\(studyableCount) cards are ready")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: studyableCount == 0 ? "checkmark" : "arrow.right")
                                .font(.headline).frame(width: 44, height: 44)
                                .background(RecallTheme.accent, in: Circle()).foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain).disabled(studyableCount == 0).opacity(studyableCount == 0 ? 0.75 : 1)

                RecallCard {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().stroke(.secondary.opacity(0.15), lineWidth: 8)
                            Circle().trim(from: 0, to: goalProgress)
                                .stroke(RecallTheme.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\\(todayReviews)").font(.headline.bold())
                        }.frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(todayReviews >= dailyGoal ? "Daily goal complete 🎉" : "Daily goal").font(.headline)
                            Text("\\(todayReviews) of \\(dailyGoal) reviews today").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("🔥 \\(currentStreak)").font(.headline)
                            Text("day streak").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Daily goal: \\(todayReviews) of \\(dailyGoal) reviews. \\(currentStreak) day streak.")
                }

                HStack(spacing: 10) {
                    StatCard(value: "\\(newCount)", label: "New")
                    StatCard(value: "\\(dueCount)", label: "Due")
                    StatCard(value: "\\(masteredCount)", label: "Mastered")
                }

                if !recentReviews.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent activity").font(.title3.bold())
                            Spacer()
                            Text("Last \\(recentReviews.count)").font(.subheadline).foregroundStyle(.secondary)
                        }
                        RecallCard {
                            VStack(spacing: 0) {
                                ForEach(Array(recentReviews.enumerated()), id: \\.element.id) { index, review in
                                    RecentReviewRow(review: review)
                                    if index < recentReviews.count - 1 { Divider().padding(.leading, 38) }
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Your library").font(.title3.bold())
                        Spacer()
                        Text("\\(decks.count) decks").font(.subheadline).foregroundStyle(.secondary)
                    }
                    if decks.isEmpty {
                        EmptyLibraryCard(action: onCreate)
                    } else {
                        ForEach(decks.prefix(3)) { deck in DeckRow(deck: deck) }
                    }
                }
            }
            .padding(.horizontal).padding(.top, 12)
        }
        .background(RecallTheme.canvas.ignoresSafeArea())
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

private struct RecentReviewRow: View {
    let review: ReviewLog

    private var ratingTitle: String {
        switch review.rating {
        case 1: return "Again"
        case 2: return "Hard"
        case 3: return "Good"
        case 4: return "Easy"
        default: return "Reviewed"
        }
    }

    private var ratingIcon: String {
        switch review.rating {
        case 1: return "arrow.counterclockwise"
        case 2: return "tortoise"
        case 3: return "checkmark"
        case 4: return "bolt.fill"
        default: return "checkmark"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: ratingIcon).font(.caption.weight(.bold)).frame(width: 28, height: 28)
                .background(.secondary.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(review.card?.question ?? "Card reviewed").font(.subheadline.weight(.medium)).lineLimit(1)
                Text("\\(ratingTitle) · \\(review.reviewedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
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
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct EmptyLibraryCard: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            RecallCard {
                HStack(spacing: 14) {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(RecallTheme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Create your first deck").font(.headline).foregroundStyle(.primary)
                        Text("Turn a topic, note, or PDF into cards in seconds.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain).accessibilityHint("Opens Create")
    }
}
