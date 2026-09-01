import Foundation
import RecallLiteRT

struct AdvancedAIService: Sendable {
    private let modelStore = LiteRTModelStore.shared

    func generateJSON(instruction: String, systemPrompt: String, source: String) async throws -> Data {
        let material = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard material.count >= 20 else { throw AIServiceError.insufficientContent }
        guard let modelURL = await modelStore.modelURL() else { throw AIServiceError.modelMissing }
        do {
            let engine = RecallLiteRTEngine(modelPath: modelURL.path)
            let raw = try await engine.generateDeckJSON(topic: instruction + "\n\n" + material, systemPrompt: systemPrompt + "\n\nSOURCE MATERIAL:\n" + material + "\n\nTASK:\n" + instruction)
            return try normalizedJSONData(raw)
        } catch let error as AIServiceError { throw error }
        catch { throw AIServiceError.generationFailed("Gemma 4 could not generate content: \(error.localizedDescription)") }
    }

    private func normalizedJSONData(_ raw: String) throws -> Data {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = cleaned.data(using: .utf8), JSONSerialization.isValidJSONObject(try? JSONSerialization.jsonObject(with: data) ?? NSNull()) { return data }
        guard let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}"), start < end else { throw AIServiceError.generationFailed("Gemma 4 returned no usable JSON. Please try again.") }
        let slice = String(cleaned[start...end])
        let fixed = slice.replacingOccurrences(of: #"\\(?![\"\\/bfnrtu])"#, with: #"\\\\"#, options: .regularExpression).replacingOccurrences(of: #",\s*([}\]])"#, with: #"$1"#, options: .regularExpression)
        guard let data = fixed.data(using: .utf8), JSONSerialization.isValidJSONObject(try? JSONSerialization.jsonObject(with: data) ?? NSNull()) else { throw AIServiceError.generationFailed("Gemma 4 returned malformed JSON. Please try again.") }
        return data
    }
}
