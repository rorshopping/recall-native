import CryptoKit
import Foundation

/// Serializes and persists on-device AI work so a user can submit several
documents without competing Foundation Models or LiteRT sessions. Jobs
survive navigation and an app relaunch.
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
        let fingerprint: String
        var state: State

        init(id: UUID = UUID(), name: String, source: String, fingerprint: String? = nil) {
            self.id = id
            self.name = name
            self.source = source
            self.fingerprint = fingerprint ?? Self.makeFingerprint(source)
            self.state = .queued
        }

        private static func makeFingerprint(_ source: String) -> String {
            SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
        }
    }

    struct ProgressSnapshot: Sendable {
        let completed: Int
        let total: Int
        let currentName: String?
    }

    private static let storageFileName = "ai-import-queue.json"
    private var jobs: [Job]
    private var isProcessing = false
    private let ai = LocalAIService()

    init() {
        jobs = Self.loadJobs()
    }

    func enqueue(name: String, source: String) -> UUID? {
        let fingerprint = Self.fingerprint(source)
        guard !jobs.contains(where: {
            $0.fingerprint == fingerprint && Self.isActiveOrCompleted($0.state)
        }) else {
            return nil
        }
        let job = Job(name: name, source: source, fingerprint: fingerprint)
        jobs.append(job)
        persist()
        return job.id
    }

    func enqueue(contentsOf inputs: [(name: String, source: String)]) -> [UUID] {
        var ids: [UUID] = []
        var fingerprints = Set<String>()

        for input in inputs {
            let fingerprint = Self.fingerprint(input.source)
            guard fingerprints.insert(fingerprint).inserted else { continue }
            guard !jobs.contains(where: {
                $0.fingerprint == fingerprint && Self.isActiveOrCompleted($0.state)
            }) else { continue }

            let job = Job(name: input.name, source: input.source, fingerprint: fingerprint)
            jobs.append(job)
            ids.append(job.id)
        }

        if !ids.isEmpty { persist() }
        return ids
    }

    func snapshot() -> [Job] { jobs }

    func progressSnapshot() -> ProgressSnapshot {
        let active = jobs.filter {
            switch $0.state {
            case .queued, .processing: return true
            case .completed, .failed: return false
            }
        }
        let completed = jobs.filter {
            switch $0.state {
            case .completed, .failed: return true
            case .queued, .processing: return false
            }
        }.count
        return ProgressSnapshot(
            completed: completed,
            total: completed + active.count,
            currentName: jobs.first(where: {
                if case .processing = $0.state { return true }
                return false
            })?.name
        )
    }

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

    func failedCount() -> Int {
        jobs.reduce(into: 0) { count, job in
            if case .failed = job.state { count += 1 }
        }
    }

    @discardableResult
    func retry(_ id: UUID) -> Bool {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return false }
        guard case .failed = jobs[index].state else { return false }
        jobs[index].state = .queued
        persist()
        return true
    }

    @discardableResult
    func retryAllFailed() -> Int {
        var count = 0
        for index in jobs.indices {
            if case .failed = jobs[index].state {
                jobs[index].state = .queued
                count += 1
            }
        }
        if count > 0 { persist() }
        return count
    }

    /// Removes an item that has not started. The active model request is never
    /// forcibly torn down, which keeps provider behavior predictable.
    func cancelQueued(_ id: UUID) {
        guard let job = jobs.first(where: { $0.id == id }) else { return }
        guard case .queued = job.state else { return }
        jobs.removeAll { $0.id == id }
        persist()
    }

    @discardableResult
    func cancelAllQueued() -> Int {
        let originalCount = jobs.count
        jobs.removeAll {
            if case .queued = $0.state { return true }
            return false
        }
        let removed = originalCount - jobs.count
        if removed > 0 { persist() }
        return removed
    }

    /// Processes jobs serially. Cancellation requeues the interrupted job so
    /// a later foreground or background run can resume it safely.
    func startIfNeeded() async throws {
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
                guard let queuedIndex = jobs.firstIndex(where: { $0.id == id }) else {
                    throw CancellationError()
                }
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

    private static func isActiveOrCompleted(_ state: Job.State) -> Bool {
        switch state {
        case .queued, .processing, .completed: return true
        case .failed: return false
        }
    }

    private static func fingerprint(_ source: String) -> String {
        SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
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
        var didRecoverInterruptedJob = false
        for index in decoded.indices {
            if case .processing = decoded[index].state {
                decoded[index].state = .queued
                didRecoverInterruptedJob = true
            }
        }
        if didRecoverInterruptedJob {
            // Best-effort recovery persistence happens after initialization via
            // the queue's actor-isolated methods. The recovered jobs are still
            // immediately available in memory even if storage is unavailable.
        }
        return decoded
    }

    private static var storageURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(storageFileName)
    }
}
