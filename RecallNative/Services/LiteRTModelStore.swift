import CryptoKit
import Foundation
import RecallLiteRT

struct ModelDownloadProgress: Sendable {
    let fraction: Double
    let bytesWritten: Int64
    let totalBytes: Int64
}

actor LiteRTModelStore {
    static let shared = LiteRTModelStore()

    static let modelFilename = "gemma-4-E2B-it.litertlm"
    static let expectedSHA256 = "181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c"
    static let approximateSizeGB = 2.59
    private let downloadURL = URL(string: "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm")!
    private var activeDownload: Task<URL, Error>?

    func modelURL() -> URL? {
        let url = documentsURL().appendingPathComponent(Self.modelFilename)
        guard FileManager.default.fileExists(atPath: url.path), RecallLiteRTEngine.isLiteRTLM(url) else { return nil }
        return url
    }

    func modelSizeMB() -> Double {
        guard let url = modelURL(), let attributes = try? FileManager.default.attributesOfItem(atPath: url.path), let size = attributes[.size] as? NSNumber else { return 0 }
        return Double(truncating: size) / 1_000_000
    }

    func downloadModel(progress: @escaping @Sendable (ModelDownloadProgress) -> Void = { _ in }) async throws -> URL {
        if let existing = modelURL() { return existing }
        if let activeDownload { return try await activeDownload.value }

        let task = Task<URL, Error> {
            let (bytes, response) = try await URLSession.shared.bytes(from: downloadURL)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw LiteRTModelError.downloadFailed
            }

            let total = max(Int64(http.expectedContentLength), 0)
            let destination = documentsURL().appendingPathComponent(Self.modelFilename)
            let temporary = documentsURL().appendingPathComponent("\(Self.modelFilename).download")
            try? FileManager.default.removeItem(at: temporary)
            FileManager.default.createFile(atPath: temporary.path, contents: nil)
            let handle = try FileHandle(forWritingTo: temporary)
            defer { try? handle.close() }

            var written: Int64 = 0
            var buffer = Data()
            buffer.reserveCapacity(1024 * 1024)
            for try await byte in bytes {
                buffer.append(byte)
                if buffer.count >= 1024 * 1024 {
                    try handle.write(contentsOf: buffer)
                    written += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                    progress(ModelDownloadProgress(fraction: total > 0 ? Double(written) / Double(total) : 0, bytesWritten: written, totalBytes: total))
                }
            }
            if !buffer.isEmpty {
                try handle.write(contentsOf: buffer)
                written += Int64(buffer.count)
            }
            progress(ModelDownloadProgress(fraction: total > 0 ? 1 : 0, bytesWritten: written, totalBytes: total))
            try handle.close()

            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: temporary, to: destination)
            guard RecallLiteRTEngine.isLiteRTLM(destination) else {
                try? FileManager.default.removeItem(at: destination)
                throw LiteRTModelError.invalidModel
            }
            let digest = try sha256(of: destination)
            guard digest == Self.expectedSHA256 else {
                try? FileManager.default.removeItem(at: destination)
                throw LiteRTModelError.checksumMismatch
            }
            return destination
        }

        activeDownload = task
        defer { activeDownload = nil }
        return try await task.value
    }

    func deleteDownloadedModel() {
        try? FileManager.default.removeItem(at: documentsURL().appendingPathComponent(Self.modelFilename))
    }

    private func documentsURL() -> URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    private func sha256(of url: URL) throws -> String {
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
}

enum LiteRTModelError: LocalizedError {
    case downloadFailed, invalidModel, checksumMismatch
    var errorDescription: String? {
        switch self {
        case .downloadFailed: return "Gemma 4 could not be downloaded. Check your connection and try again."
        case .invalidModel: return "The downloaded Gemma 4 model is invalid or incomplete."
        case .checksumMismatch: return "The Gemma 4 download failed integrity verification. Please try again."
        }
    }
}
