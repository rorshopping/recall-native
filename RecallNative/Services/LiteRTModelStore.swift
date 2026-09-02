import CryptoKit
import Foundation
import RecallLiteRT

struct ModelDownloadProgress: Sendable {
    let fraction: Double
    let bytesWritten: Int64
    let totalBytes: Int64
}

/// Owns the URLSession background transfer. Unlike URLSession.bytes(from:), a
/// background download is continued by iOS while the app is suspended and can
/// be completed after the app has been terminated and relaunched.
final class BackgroundModelDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    static let shared = BackgroundModelDownloader()
    static let sessionIdentifier = "com.recalllabs.recall-native.gemma-model"

    private let lock = NSLock()
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.waitsForConnectivity = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    private var continuation: CheckedContinuation<URL, Error>?
    private var progressHandler: (@Sendable (ModelDownloadProgress) -> Void)?
    private var activeTaskIdentifier: Int?
    private var backgroundEventsCompletion: (() -> Void)?

    func download(
        from sourceURL: URL,
        destination: URL,
        progress: @escaping @Sendable (ModelDownloadProgress) -> Void
    ) async throws -> URL {
        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }

        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            self.progressHandler = progress
            lock.unlock()

            session.getAllTasks { [weak self] tasks in
                guard let self else { return }
                if let existing = tasks.first(where: { $0.taskDescription == Self.sessionIdentifier }) as? URLSessionDownloadTask {
                    self.lock.lock()
                    self.activeTaskIdentifier = existing.taskIdentifier
                    self.lock.unlock()
                    existing.resume()
                    return
                }

                let task = self.session.downloadTask(with: sourceURL)
                task.taskDescription = Self.sessionIdentifier
                self.lock.lock()
                self.activeTaskIdentifier = task.taskIdentifier
                self.lock.unlock()
                task.resume()
            }
        }
    }

    func cancel() {
        lock.lock()
        let identifier = activeTaskIdentifier
        lock.unlock()
        guard let identifier else { return }
        session.getAllTasks { tasks in
            (tasks.first { $0.taskIdentifier == identifier } as? URLSessionDownloadTask)?.cancel()
        }
    }

    func handleBackgroundEvents(completionHandler: @escaping () -> Void) {
        lock.lock()
        backgroundEventsCompletion = completionHandler
        lock.unlock()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        let handler: (@Sendable (ModelDownloadProgress) -> Void)?
        lock.lock()
        handler = progressHandler
        lock.unlock()
        handler?(ModelDownloadProgress(
            fraction: totalBytesExpectedToWrite > 0
                ? min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
                : 0,
            bytesWritten: totalBytesWritten,
            totalBytes: totalBytesExpectedToWrite
        ))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let destination = LiteRTModelStore.modelFileURL()
        do {
            guard let response = downloadTask.response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode) else {
                throw LiteRTModelError.downloadFailed
            }

            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            guard RecallLiteRTEngine.isLiteRTLM(destination) else {
                try? FileManager.default.removeItem(at: destination)
                throw LiteRTModelError.invalidModel
            }
            let digest = try LiteRTModelStore.sha256(of: destination)
            guard digest == LiteRTModelStore.expectedSHA256 else {
                try? FileManager.default.removeItem(at: destination)
                throw LiteRTModelError.checksumMismatch
            }

            lock.lock()
            let continuation = self.continuation
            self.continuation = nil
            self.progressHandler = nil
            self.activeTaskIdentifier = nil
            lock.unlock()
            continuation?.resume(returning: destination)
        } catch {
            lock.lock()
            let continuation = self.continuation
            self.continuation = nil
            self.progressHandler = nil
            self.activeTaskIdentifier = nil
            lock.unlock()
            continuation?.resume(throwing: error)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard let error else { return }
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        self.progressHandler = nil
        self.activeTaskIdentifier = nil
        lock.unlock()
        let nsError = error as NSError
        continuation?.resume(throwing: nsError.code == NSURLErrorCancelled ? LiteRTModelError.cancelled : error)
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        lock.lock()
        let completion = backgroundEventsCompletion
        backgroundEventsCompletion = nil
        lock.unlock()
        completion?()
    }
}

actor LiteRTModelStore {
    static let shared = LiteRTModelStore()

    static let modelFilename = "gemma-4-E2B-it.litertlm"
    static let expectedSHA256 = "181938105e0eefd105961417e8da75903deac102c4fce9ce90f50b97139a63c"
    static let approximateSizeGB = 2.59
    private static let minimumFreeBytes: Int64 = 3_000_000_000
    private let downloadURL = URL(string: "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm")!
    private var activeDownload: Task<URL, Error>?

    nonisolated static func modelFileURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Self.modelFilename)
    }

    nonisolated static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let data = handle.readData(ofLength: 4 * 1024 * 1024)
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    func modelURL() -> URL? {
        let url = Self.modelFileURL()
        guard FileManager.default.fileExists(atPath: url.path), RecallLiteRTEngine.isLiteRTLM(url) else { return nil }
        return url
    }

    func modelSizeMB() -> Double {
        guard let url = modelURL(), let attributes = try? FileManager.default.attributesOfItem(atPath: url.path), let size = attributes[.size] as? NSNumber else { return 0 }
        return Double(truncating: size) / 1_000_000
    }

    func availableStorageBytes() -> Int64 {
        let url = Self.modelFileURL()
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]) else { return 0 }
        return Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
    }

    func downloadModel(progress: @escaping @Sendable (ModelDownloadProgress) -> Void = { _ in }) async throws -> URL {
        if let existing = modelURL() { return existing }
        if let activeDownload { return try await activeDownload.value }
        guard availableStorageBytes() >= Self.minimumFreeBytes else { throw LiteRTModelError.insufficientStorage }

        let task = Task<URL, Error> {
            try await BackgroundModelDownloader.shared.download(
                from: self.downloadURL,
                destination: Self.modelFileURL(),
                progress: progress
            )
        }
        activeDownload = task
        defer { activeDownload = nil }
        return try await task.value
    }

    func cancelDownload() {
        BackgroundModelDownloader.shared.cancel()
    }

    func deleteDownloadedModel() {
        BackgroundModelDownloader.shared.cancel()
        try? FileManager.default.removeItem(at: Self.modelFileURL())
    }
}

enum LiteRTModelError: LocalizedError {
    case downloadFailed, invalidModel, checksumMismatch, insufficientStorage, cancelled
    var errorDescription: String? {
        switch self {
        case .downloadFailed: return "Gemma 4 could not be downloaded. Check your connection and try again."
        case .invalidModel: return "The downloaded Gemma 4 model is invalid or incomplete."
        case .checksumMismatch: return "The Gemma 4 download failed integrity verification. Please try again."
        case .insufficientStorage: return "There is not enough free storage to download Gemma 4. Free at least 3 GB and try again."
        case .cancelled: return "The Gemma 4 download was cancelled."
        }
    }
}
