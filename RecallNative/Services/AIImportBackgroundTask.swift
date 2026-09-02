import Foundation
import BackgroundTasks

/// Bridges the user-initiated AI inbox into iOS 26's continuous background
/// processing. The queue remains the source of truth, so work also resumes
/// normally when the app returns to the foreground.
@available(iOS 26.0, *)
final class AIImportBackgroundTask: NSObject, @unchecked Sendable {
    static let shared = AIImportBackgroundTask()
    static let identifier = "com.recalllabs.recallnative.ai-import"

    private let queue = AIImportQueue.shared
    private let lock = NSLock()
    private var registered = false
    private var submitted = false

    private override init() {
        super.init()
    }

    private final class CompletionGate: @unchecked Sendable {
        private let lock = NSLock()
        private var didComplete = false

        func finish(_ task: BGContinuedProcessingTask, success: Bool, onFirstCompletion: () -> Void) {
            lock.lock()
            guard !didComplete else {
                lock.unlock()
                return
            }
            didComplete = true
            lock.unlock()
            onFirstCompletion()
            task.setTaskCompleted(success: success)
        }
    }

    func register() {
        lock.lock()
        defer { lock.unlock() }
        guard !registered else { return }

        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.identifier, using: nil) { task in
            guard let task = task as? BGContinuedProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Self.shared.handle(task)
        }
        registered = true
    }

    /// Called directly from a user action after files have been added or a
    /// failed item has been retried. Submission is intentionally synchronous so
    /// the request reaches iOS before foreground work starts or the app can be
    /// backgrounded.
    func submitIfNeeded() {
        register()

        lock.lock()
        guard !submitted else {
            lock.unlock()
            return
        }
        submitted = true
        lock.unlock()

        let request = BGContinuedProcessingTaskRequest(
            identifier: Self.identifier,
            title: "Generating flashcards",
            subtitle: "Processing your AI inbox privately on device"
        )
        request.strategy = .queue

        // Do not request GPU unless the app has the matching entitlement.
        // The Gemma/LiteRT path can still run using its permitted resources.
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            lock.lock()
            submitted = false
            lock.unlock()
        }
    }

    private func markSubmissionFinished() {
        lock.lock()
        submitted = false
        lock.unlock()
    }

    private func finish(_ task: BGContinuedProcessingTask, gate: CompletionGate, success: Bool) {
        gate.finish(task, success: success) {
            Self.shared.markSubmissionFinished()
        }
    }

    private func handle(_ task: BGContinuedProcessingTask) {
        let gate = CompletionGate()
        let work = Task {
            let initial = await queue.progressSnapshot()
            let total = max(initial.total, 1)
            task.progress.totalUnitCount = Int64(total)
            task.progress.completedUnitCount = Int64(initial.completed)

            let reporter = Task {
                while !Task.isCancelled {
                    let progress = await queue.progressSnapshot()
                    task.progress.totalUnitCount = Int64(max(progress.total, total))
                    task.progress.completedUnitCount = Int64(min(progress.completed, Int(task.progress.totalUnitCount)))

                    let subtitle: String
                    if let currentName = progress.currentName {
                        subtitle = "\(progress.completed + 1) of \(progress.total): \(currentName)"
                    } else if progress.total > 0 {
                        subtitle = "Finishing your AI inbox"
                    } else {
                        subtitle = "AI inbox complete"
                    }
                    task.updateTitle("Generating flashcards", subtitle: subtitle)

                    if progress.total > 0 && progress.completed >= progress.total {
                        break
                    }

                    try? await Task.sleep(for: .milliseconds(300))
                }
            }

            do {
                try await queue.startIfNeeded()
                reporter.cancel()

                let final = await queue.progressSnapshot()
                task.progress.totalUnitCount = Int64(max(final.total, 1))
                task.progress.completedUnitCount = task.progress.totalUnitCount
                task.updateTitle("Generating flashcards", subtitle: "AI inbox complete")
                finish(task, gate: gate, success: true)
            } catch is CancellationError {
                reporter.cancel()
                finish(task, gate: gate, success: false)
            } catch {
                reporter.cancel()
                finish(task, gate: gate, success: false)
            }
        }

        task.expirationHandler = {
            work.cancel()
            self.finish(task, gate: gate, success: false)
        }
    }
}
