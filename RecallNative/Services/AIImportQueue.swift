import Foundation

/// Serializes and persists on-device AI work so a user can submit several
/// documents without competing Foundation Models or LiteRT sessions. Jobs
/// survive navigation and an app relaunch.
actor AIImportQueue {
    static let shared = AIImportQueue()

    struct Job: Identifiable, Sendable, Hashable, Codable {
        enum State: Sendable, Hashable, Codable {
            case queued
            case processing
            case completed(GeneratedDeck)
            case failed(String)
        }

        let id: UUID
        let name: String
        let source: String
        var state: State

        init(id: UUID = UUID(), name: String, source: String) {
            self.id = id
            self.name = name
            self.source = source
            self.state = .queued
        }
    }

    private static let storageFileName = "ai-import-queue.json"
    private var jobs: [Job]
    private var isProcessing = false
    private let ai = LocalAIService()

    init() {
        jobs = Self.loadJobs()
    }

    func enqueue(name: String, source: String) -> UUID {
        let job = Job(name: name, source: source)
        jobs.append(job)
        persist()
        return job.id
    }

    func enqueue(contentsOf inputs: [(name: String, source: String)]) -> [UUID] {
        let ids = inputs.map { input in
            let job = Job(name: input.name, source: input.source)
            jobs.append(job)
            return job.id
        }
        persist()
        return ids
    }

    func snapshot() -> [Job] { jobs }

    func pendingCount() -> Int {
        jobs.reduce(into: 0) { count, job in
            if case .queued = job.state { count += 1 }
        }
    }

    func activeCount() -> Int {
        jobs.reduce(into: 0) { count, job in
            switch job.state {
            case .queued, .processing: count += 1
            case .completed, .failed: break
            }
        }
    }

    func startIfNeeded() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        while let index = jobs.firstIndex(where: {
            if case .queued = $0.state { return true }
            return false
        }) {
            let id = jobs[index].id
            jobs[index].state = .processing
            persist()
            let source = jobs[index].source

            do {
                let result = try await ai.generateFlashcards(from: source)
                guard let completedIndex = jobs.firstIndex(where: { $0.id == id }) else { continue }
                jobs[completedIndex].state = .completed(result)
                persist()
            } catch is CancellationError {
                guard let queuedIndex = jobs.firstIndex(where: { $0.id == id }) else { continue }
                jobs[queuedIndex].state = .queued
                persist()
                throw CancellationError()
            } catch {
                guard let failedIndex = jobs.firstIndex(where: { $0.id == id }) else { continue }
                jobs[failedIndex].state = .failed(error.localizedDescription)
                persist()
            }
        }
    }

    func remove(_ id: UUID) {
        jobs.removeAll { $0.id == id }
        persist()
    }

    func clearFinished() {
        jobs.removeAll {
            switch $0.state {
            case .completed, .failed: return true
            case .queued, .processing: return false
            }
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(jobs) else { return }
        let url = Self.storageURL
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: [.atomic])
        } catch {
            // Queue processing must not fail just because persistence is unavailable.
        }
    }

    private static func loadJobs() -> [Job] {
        guard let data = try? Data(contentsOf: storageURL),
              var decoded = try? JSONDecoder().decode([Job].self, from: data) else {
            return []
        }

        // A terminated app can leave a job marked processing. Requeue it so
        // the next launch never strands an item permanently.
        for index in decoded.indices {
            if case .processing = decoded[index].state {
                decoded[index].state = .queued
            }
        }
        return decoded
    }

    private static var storageURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(storageFileName)
    }
}
