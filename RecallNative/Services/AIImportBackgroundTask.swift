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

    private override init() {
        super.init()
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

    /// Called after the user adds files. iOS may begin immediately and can
    /// continue the workload after the app is backgrounded.
    func submitIfNeeded() {
        register()
        Task {
            guard await queue.activeCount() > 0 else { return }

            let request = BGContinuedProcessingTaskRequest(
                identifier: Self.identifier,
                title: "Generating flashcards",
                subtitle: "Processing your AI inbox privately on device"
            )
            request.strategy = .queue

            if BGTaskScheduler.supportedResources.contains(.gpu) {
                request.requiredResources = .gpu
            }

            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                // The foreground queue remains active. Submission can fail
                // when the system is temporarily resource constrained.
            }
        }
    }

    private func handle(_ task: BGContinuedProcessingTask) {
        let progress = task.progress
        progress.totalUnitCount = 1

        let work = Task {
            await queue.startIfNeeded()
            progress.completedUnitCount = 1
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
