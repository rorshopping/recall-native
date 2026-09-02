import Foundation

/// Serializes on-device AI work so a user can submit several documents without
/// competing Foundation Models or LiteRT sessions. Jobs are processed in order.
actor AIImportQueue {
    static let shared = AIImportQueue()

    struct Job: Identifiable, Sendable, Hashable {
        enum State: Sendable, Hashable {
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

    private var jobs: [Job] = []
    private var isProcessing = false
    private let ai = LocalAIService()

    func enqueue(name: String, source: String) -> UUID {
        let job = Job(name: name, source: source)
        jobs.append(job)
        return job.id
    }

    func enqueue(contentsOf inputs: [(name: String, source: String)]) -> [UUID] {
        inputs.map { enqueue(name: $0.name, source: $0.source) }
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
            let source = jobs[index].source

            do {
                let result = try await ai.generateFlashcards(from: source)
                guard let completedIndex = jobs.firstIndex(where: { $0.id == id }) else { continue }
                jobs[completedIndex].state = .completed(result)
            } catch is CancellationError {
                guard let queuedIndex = jobs.firstIndex(where: { $0.id == id }) else { continue }
                jobs[queuedIndex].state = .queued
                throw CancellationError()
            } catch {
                guard let failedIndex = jobs.firstIndex(where: { $0.id == id }) else { continue }
                jobs[failedIndex].state = .failed(error.localizedDescription)
            }
        }
    }

    func remove(_ id: UUID) { jobs.removeAll { $0.id == id } }

    func clearFinished() {
        jobs.removeAll {
            switch $0.state {
            case .completed, .failed: return true
            case .queued, .processing: return false
            }
        }
    }
}
