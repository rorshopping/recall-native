import SwiftUI
import SwiftData
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ReviewAudioController: ObservableObject {
    @Published private(set) var isPlaying = false
    private var player: AVPlayer?
    nonisolated(unsafe) private var endObserver: NSObjectProtocol?

    func toggle(url: URL) {
        if isPlaying { stop(); return }
        stop()
        let newPlayer = AVPlayer(url: url)
        player = newPlayer
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isPlaying = false
                self?.player = nil
                self?.removeObserver()
            }
        }
        isPlaying = true
        newPlayer.play()
    }

    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        removeObserver()
    }

    private func removeObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    deinit {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }
}

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let deck: Deck?
    let studyAll: Bool
    @Query(sort: \Flashcard.dueAt) private var cards: [Flashcard]
    @State private var queue: [Flashcard] = []
    @State private var total = 0
    @State private var reviewed = 0
    @State private var completedCards: Set<UUID> = []
    @State private var revealed = false
    @State private var completed = false
    @State private var typed = ""
    @State private var typeChecked: Bool?
    @State private var didInitialize = false
    @StateObject private var audio = ReviewAudioController()

    init(deck: Deck? = nil, studyAll: Bool = false) { self.deck = deck; self.studyAll = studyAll }

    var body: some View {
        NavigationStack {
            Group {
                if completed { completionView }
                else if didInitialize && queue.isEmpty { emptyView }
                else if !queue.isEmpty { studyBody }
                else { ProgressView() }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { audio.stop(); dismiss() } } }
        }
        .task { initializeIfNeeded() }
        .onDisappear { audio.stop() }
    }

    private var progressCount: Int { min(completedCards.count + 1, max(total, 1)) }

    private var studyBody: some View {
        let card = queue[0]
        return VStack(spacing: 18) {
            HStack {
                Text(deck?.name ?? "Review").font(.headline)
                Spacer()
                Text("\(progressCount) / \(max(total, 1))")
                    .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(completedCards.count), total: Double(max(total, 1)))
                .tint(RecallTheme.accent)

            RecallCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(revealed ? "ANSWER" : "QUESTION")
                            .font(.caption.weight(.bold)).foregroundStyle(RecallTheme.accent).tracking(1)
                        Spacer()
                        Text(card.state.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            mediaView(for: card)
                            Text(displayText(for: card))
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                    if !revealed { Text("Tap to reveal the answer").font(.subheadline).foregroundStyle(.secondary) }
                }
            }
            .frame(maxWidth: 760, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.snappy(duration: 0.25)) { revealed = true } }

            if revealed && !card.hint.isEmpty {
                Text("Hint: \(card.hint)").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: 760, alignment: .leading)
            }
            if revealed && card.typeInAnswer { typeIn(card) }
            else if revealed { ratings }
            else { Text("How well did you remember it?").font(.caption).foregroundStyle(.secondary) }
        }
        .padding()
    }

    @ViewBuilder
    private func mediaView(for card: Flashcard) -> some View {
        if let mediaType = card.mediaType, let uri = card.mediaURI, let url = URL(string: uri) {
            if mediaType == "image" {
                #if canImport(UIKit)
                if url.isFileURL, let image = loadLocalImage(url) {
                    Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 14))
                    } placeholder: { ProgressView().frame(maxWidth: .infinity) }
                }
                #else
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 14))
                } placeholder: { ProgressView().frame(maxWidth: .infinity) }
                #endif
            } else if mediaType == "audio" {
                Button { audio.toggle(url: url) } label: {
                    Label(audio.isPlaying ? "Pause audio" : "Play audio", systemImage: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    #if canImport(UIKit)
    private func loadLocalImage(_ url: URL) -> UIImage? { UIImage(contentsOfFile: url.path) }
    #endif

    private var ratings: some View {
        HStack(spacing: 8) {
            RatingButton(title: "Again", value: 0, action: rate)
            RatingButton(title: "Hard", value: 1, action: rate)
            RatingButton(title: "Good", value: 2, action: rate)
            RatingButton(title: "Easy", value: 3, action: rate)
        }.frame(maxWidth: 760)
    }

    private func typeIn(_ card: Flashcard) -> some View {
        VStack(spacing: 10) {
            TextField("Type your answer", text: $typed)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit(checkTyped)
            if let typeChecked {
                Text(typeChecked ? "✓ Correct" : "✗ Answer: \(card.answer)")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(typeChecked ? .green : .red)
            }
            Button("Check", action: checkTyped).buttonStyle(.borderedProminent)
            if typeChecked != nil { ratings }
        }.frame(maxWidth: 760)
    }

    private var completionView: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(RecallTheme.accent)
            Text("Session complete").font(.largeTitle.bold())
            Text("\(reviewed) review\(reviewed == 1 ? "" : "s") · \(completedCards.count) card\(completedCards.count == 1 ? "" : "s") completed")
                .foregroundStyle(.secondary)
            Button("Study again", action: restart).buttonStyle(.borderedProminent)
            Button("Done") { dismiss() }.buttonStyle(.bordered)
        }.padding(32)
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 60)).foregroundStyle(RecallTheme.accent)
            Text("Nothing due right now").font(.title.bold())
            Text("All caught up. Your next reviews will appear here when they are due.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
        }.padding(32)
    }

    private func initializeIfNeeded() {
        guard !didInitialize else { return }
        let scoped = cards.filter { deck == nil || $0.deck?.id == deck?.id }
        let initial: [Flashcard]
        if studyAll { initial = scoped }
        else {
            let due = scoped.filter { !$0.isNew && $0.isDue }
            let fresh = Array(scoped.filter(\.isNew).prefix(deck?.newRemainingToday ?? scoped.count))
            initial = due + fresh
        }
        queue = initial
        total = initial.count
        didInitialize = true
    }

    private func restart() {
        audio.stop()
        didInitialize = false; completed = false; queue = []; total = 0; reviewed = 0; completedCards = []; revealed = false; typed = ""; typeChecked = nil
        initializeIfNeeded()
    }

    private func displayText(for card: Flashcard) -> String {
        let source = revealed ? card.answer : card.question
        guard card.type == "cloze", !revealed else { return source }
        return source.replacingOccurrences(of: #"\{\{c\d+::[^}]*\}\}"#, with: "… … …", options: .regularExpression)
    }

    private func checkTyped() {
        guard let card = queue.first else { return }
        typeChecked = typed.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(card.answer.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }

    private func rate(_ grade: Int) {
        guard let card = queue.first else { return }
        audio.stop()
        let wasNew = card.isNew
        let result = SpacedRepetitionService.schedule(state: card.state, step: card.step, repetitions: card.repetitions, interval: card.interval, ease: card.ease, grade: grade)
        card.state = result.state; card.step = result.step; card.repetitions = result.repetitions; card.interval = result.interval; card.ease = result.ease; card.dueAt = result.dueAt; card.lastReviewedAt = .now
        switch grade { case 0: card.againCount += 1; card.lapses += 1; case 1: card.hardCount += 1; case 2: card.goodCount += 1; case 3: card.easyCount += 1; default: break }
        HapticsService.grade(grade)
        if wasNew, let deck {
            let today = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: .now))
            if deck.newDay != today { deck.newDay = today; deck.newStudiedToday = 0 }
            deck.newStudiedToday += 1
        }
        modelContext.insert(ReviewLog(rating: grade + 1, card: card))
        try? modelContext.save()

        let current = queue.removeFirst()
        if grade == 0 {
            queue.append(current)
        } else {
            completedCards.insert(current.id)
        }
        reviewed += 1
        revealed = false
        typed = ""
        typeChecked = nil
        if queue.isEmpty { completed = true }
    }
}

private struct RatingButton: View {
    let title: String
    let value: Int
    let action: (Int) -> Void
    var body: some View { Button(title) { action(value) }.buttonStyle(.borderedProminent).controlSize(.small).frame(maxWidth: .infinity) }
}
