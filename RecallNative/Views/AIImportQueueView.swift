import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AIImportQueueView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var decks: [Deck]
    @StateObject private var subscriptions = SubscriptionService()
    @State private var jobs: [AIImportQueue.Job] = []
    @State private var showingImporter = false
    @State private var errorMessage: String?
    @State private var extractionMessage: String?
    @State private var refreshTask: Task<Void, Never>?
    @State private var blockedJobID: UUID?

    private let queue = AIImportQueue.shared
    private let importer = DocumentImportService()

    private var activeJobs: [AIImportQueue.Job] {
        jobs.filter {
            switch $0.state {
            case .queued, .processing: return true
            case .completed, .failed: return false
            }
        }
    }

    private var failedJobs: [AIImportQueue.Job] {
        jobs.filter {
            if case .failed = $0.state { return true }
            return false
        }
    }

    private var queuedJobs: [AIImportQueue.Job] {
        jobs.filter {
            if case .queued = $0.state { return true }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Add PDFs or images", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Text("Select several files at once. Recall extracts their text and queues them for Apple on-device AI, with Gemma 4 as the automatic fallback.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !activeJobs.isEmpty {
                    Section {
                        HStack {
                            Label("Processing", systemImage: "sparkles")
                            Spacer()
                            Text("\(activeJobs.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        ForEach(activeJobs) { job in
                            jobRow(job)
                        }

                        if queuedJobs.count > 1 {
                            Button("Remove remaining queued", systemImage: "xmark.circle") {
                                Task {
                                    await queue.cancelAllQueued()
                                    await refresh()
                                }
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                let finished = jobs.filter {
                    switch $0.state {
                    case .completed, .failed: return true
                    case .queued, .processing: return false
                    }
                }
                if !finished.isEmpty {
                    Section("Recent") {
                        ForEach(finished) { job in
                            jobRow(job)
                        }

                        if !failedJobs.isEmpty {
                            Button("Retry all failed", systemImage: "arrow.clockwise") {
                                Task {
                                    let count = await queue.retryAllFailed()
                                    if count > 0 {
                                        await queue.startIfNeeded()
                                        if #available(iOS 26.0, *) {
                                            AIImportBackgroundTask.shared.submitIfNeeded()
                                        }
                                    }
                                    await refresh()
                                }
                            }
                            .foregroundStyle(RecallTheme.accent)
                        }

                        Button("Clear finished", systemImage: "checkmark.circle") {
                            Task {
                                await queue.clearFinished()
                                await refresh()
                            }
                        }
                    }
                }

                if jobs.isEmpty {
                    ContentUnavailableView("Your AI inbox is empty", systemImage: "tray.and.arrow.down", description: Text("Add several study documents and keep using Recall while they are processed."))
                }
            }
            .navigationTitle("AI Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if !activeJobs.isEmpty {
                    ToolbarItem(placement: .principal) {
                        Text("\(activeJobs.count) queued")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RecallTheme.accent)
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: true,
                onCompletion: handleFiles
            )
            .task {
                await subscriptions.load()
                await refresh()
                refreshTask?.cancel()
                refreshTask = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .milliseconds(500))
                        await refresh()
                    }
                }
            }
            .onDisappear {
                refreshTask?.cancel()
            }
            .alert("Couldn’t add files", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .overlay(alignment: .bottom) {
                if let extractionMessage {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(extractionMessage).font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 12)
                }
            }
        }
    }

    @ViewBuilder
    private func jobRow(_ job: AIImportQueue.Job) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(for: job.state))
                .foregroundStyle(colorStyle(for: job.state))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(job.name).font(.headline).lineLimit(1)
                switch job.state {
                case .queued:
                    Text("Waiting for the on-device AI queue").font(.caption).foregroundStyle(.secondary)
                case .processing:
                    Text("Generating privately on device…").font(.caption).foregroundStyle(.secondary)
                case .completed(let deck):
                    Text("Created \(deck.cards.count) cards").font(.caption).foregroundStyle(.secondary)
                case .failed(let message):
                    Text(message).font(.caption).foregroundStyle(.red).lineLimit(2)
                }
            }
            Spacer()
            switch job.state {
            case .queued:
                Button {
                    Task {
                        await queue.cancelQueued(job.id)
                        await refresh()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Remove \(job.name) from queue")
            case .processing:
                ProgressView()
            case .completed:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .failed:
                Button {
                    Task {
                        await queue.retry(job.id)
                        await queue.startIfNeeded()
                        if #available(iOS 26.0, *) {
                            AIImportBackgroundTask.shared.submitIfNeeded()
                        }
                        await refresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(RecallTheme.accent)
                .accessibilityLabel("Retry \(job.name)")
            }
        }
        .padding(.vertical, 4)
    }

    private func icon(for state: AIImportQueue.Job.State) -> String {
        switch state {
        case .queued: return "clock"
        case .processing: return "sparkles"
        case .completed: return "checkmark.circle"
        case .failed: return "exclamationmark.triangle"
        }
    }

    private func colorStyle(for state: AIImportQueue.Job.State) -> Color {
        switch state {
        case .failed: return .red
        default: return RecallTheme.accent
        }
    }

    private func handleFiles(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, !urls.isEmpty else { return }
        extractionMessage = "Reading \(urls.count) file\(urls.count == 1 ? "" : "s")…"
        Task {
            let inputs = await Task.detached(priority: .userInitiated) { [importer] in
                var extracted: [(name: String, source: String)] = []
                for url in urls {
                    do {
                        let text = try importer.extractText(from: url)
                        extracted.append((url.deletingPathExtension().lastPathComponent, text))
                    } catch {
                        continue
                    }
                }
                return extracted
            }.value

            await MainActor.run {
                extractionMessage = nil
                if inputs.isEmpty {
                    errorMessage = "None of the selected files contained readable text."
                    return
                }
                Task {
                    _ = await queue.enqueue(contentsOf: inputs)
                    await queue.startIfNeeded()
                    if #available(iOS 26.0, *) {
                        AIImportBackgroundTask.shared.submitIfNeeded()
                    }
                    await refresh()
                }
            }
        }
    }

    private func refresh() async {
        let snapshot = await queue.snapshot()
        await MainActor.run { jobs = snapshot }
        await saveCompletedIfPossible(snapshot)
    }

    @MainActor
    private func saveCompletedIfPossible(_ snapshot: [AIImportQueue.Job]) async {
        for job in snapshot {
            guard case .completed(let generated) = job.state else { continue }
            guard blockedJobID != job.id else { continue }
            guard EntitlementRules.canCreateDeck(isPremium: subscriptions.isPremium, deckCount: decks.count) else {
                blockedJobID = job.id
                continue
            }
            if !subscriptions.isPremium && generated.cards.count > EntitlementRules.freeCardLimitPerDeck {
                blockedJobID = job.id
                continue
            }

            let name = generated.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? job.name : generated.name
            let deck = Deck(name: name, emoji: "📚")
            modelContext.insert(deck)
            for card in generated.cards {
                modelContext.insert(Flashcard(question: card.question, answer: card.answer, hint: card.hint, tags: card.tags, deck: deck))
            }
            do {
                try modelContext.save()
                await queue.remove(job.id)
                blockedJobID = nil
            } catch {
                errorMessage = "The generated deck could not be saved."
                return
            }
        }
        jobs = await queue.snapshot()
    }
}
