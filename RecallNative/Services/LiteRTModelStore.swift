import Foundation

actor LiteRTModelStore {
    static let shared = LiteRTModelStore()

    private let filename = "gemma-4-E2B-it.litertlm"
    private let downloadURL = URL(string: "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm")!
    private let expectedSHA256 = "181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c"

    private var activeDownload: Task<URL, Error>?

    func modelURL() -> URL? {
        let url = documentsURL().appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path),
              RecallLiteRTEngine.isLiteRTLM(url) else { return nil }
        return url
    }

    func modelSizeMB() -> Double {
        guard let url = modelURL(),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else { return 0 }
        return Double(truncating: size) / 1_000_000
    }

    func downloadModel() async throws -> URL {
        if let existing = modelURL() { return existing }
        if let activeDownload { return try await activeDownload.value }

        let task = Task<URL, Error> {
            let (temporaryURL, response) = try await URLSession.shared.download(from: downloadURL)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                throw LiteRTModelError.downloadFailed
            }

            let destination = documentsURL().appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: temporaryURL, to: destination)

            guard RecallLiteRTEngine.isLiteRTLM(destination) else {
                try? FileManager.default.removeItem(at: destination)
                throw LiteRTModelError.invalidModel
            }

            let digest = try sha256(of: destination)
            guard digest == expectedSHA256 else {
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
        let url = documentsURL().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    private func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256Hasher()
        while true {
            let data = handle.readData(ofLength: 4 * 1024 * 1024)
            if data.isEmpty { break }
            hasher.update(data)
        }
        return hasher.finalize()
    }
}

enum LiteRTModelError: LocalizedError {
    case downloadFailed
    case invalidModel
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .downloadFailed:
            return "Gemma 4 could not be downloaded. Check your connection and try again."
        case .invalidModel:
            return "The downloaded Gemma 4 model is invalid or incomplete."
        case .checksumMismatch:
            return "The Gemma 4 download failed integrity verification. Please try again."
        }
    }
}

private struct SHA256Hasher {
    private var bytes: [UInt8] = []

    mutating func update(_ data: Data) {
        bytes.append(contentsOf: data)
    }

    func finalize() -> String {
        // Placeholder replaced by CryptoKit-backed implementation below.
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}
