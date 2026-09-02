import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
struct AppleOnDeviceAIService: Sendable {
    enum ServiceError: LocalizedError {
        case unavailable
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Apple's on-device language model is not available on this device."
            case .emptyResponse:
                return "Apple's on-device language model returned no content."
            }
        }
    }

    func generateJSON(instruction: String, systemPrompt: String, source: String) async throws -> Data {
        guard SystemLanguageModel.default.isAvailable else {
            throw ServiceError.unavailable
        }

        let material = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !material.isEmpty else { throw AIServiceError.emptyInput }

        let session = LanguageModelSession(instructions: systemPrompt)
        let prompt = "SOURCE MATERIAL:\n\(material)\n\nTASK:\n\(instruction)\n\nReturn ONLY valid JSON. Do not include markdown, prose, or code fences."
        let response = try await session.respond(to: prompt)
        let raw = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { throw ServiceError.emptyResponse }
        return try AppleJSONOutputNormalizer.normalize(raw)
    }
}
#endif

private enum AppleJSONOutputNormalizer {
    static func normalize(_ raw: String) throws -> Data {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = cleaned.data(using: .utf8) {
            do {
                let object = try JSONSerialization.jsonObject(with: data)
                if JSONSerialization.isValidJSONObject(object) { return data }
            } catch { }
        }

        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}"),
              start < end else {
            throw AIServiceError.generationFailed("The on-device model returned no usable JSON. Please try again.")
        }

        let slice = String(cleaned[start...end])
        let fixed = slice
            .replacingOccurrences(of: #"\\(?![\"\\/bfnrtu])"#, with: #"\\\\"#, options: .regularExpression)
            .replacingOccurrences(of: #",\s*([}\]])"#, with: #"$1"#, options: .regularExpression)

        guard let data = fixed.data(using: .utf8) else {
            throw AIServiceError.generationFailed("The on-device model returned malformed JSON. Please try again.")
        }

        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard JSONSerialization.isValidJSONObject(object) else {
                throw AIServiceError.generationFailed("The on-device model returned malformed JSON. Please try again.")
            }
            return data
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.generationFailed("The on-device model returned malformed JSON. Please try again.")
        }
    }
}
