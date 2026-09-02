import Foundation
import RecallLiteRT

struct AdvancedAIService: Sendable {
    private let modelStore = LiteRTModelStore.shared

    func generateJSON(instruction: String, systemPrompt: String, source: String) async throws -> Data {
        let material = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !material.isEmpty else { throw AIServiceError.emptyInput }
        guard let modelURL = await modelStore.modelURL() else { throw AIServiceError.modelMissing }

        let topic = instruction + "\n\n" + material
        let prompt = systemPrompt + "\n\nSOURCE MATERIAL:\n" + material + "\n\nTASK:\n" + instruction
        let engine = RecallLiteRTEngine(modelPath: modelURL.path)

        var lastJSONError: Error?
        for attempt in 0..<2 {
            do {
                let raw = try await engine.generateDeckJSON(
                    topic: attempt == 0 ? topic : topic + "\n\nReturn ONLY valid JSON. Do not include markdown, prose, or code fences.",
                    systemPrompt: attempt == 0 ? prompt : prompt + "\n\nIMPORTANT: Your previous response was not valid JSON. Retry and output only valid JSON matching the requested schema."
                )
                do {
                    return try normalizedJSONData(raw)
                } catch {
                    lastJSONError = error
                    if attempt == 1 { throw error }
                }
            } catch let error as AIServiceError {
                throw error
            } catch {
                if attempt == 1 {
                    throw AIServiceError.generationFailed("Gemma 4 could not generate valid content: \(error.localizedDescription)")
                }
            }
        }
        throw AIServiceError.generationFailed("Gemma 4 returned malformed JSON: \(lastJSONError?.localizedDescription ?? "Please try again.")")
    }

    private func normalizedJSONData(_ raw: String) throws -> Data {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = cleaned.data(using: .utf8) {
            do {
                let object = try JSONSerialization.jsonObject(with: data)
                if JSONSerialization.isValidJSONObject(object) { return data }
            } catch {
                // Try extracting and repairing a JSON object below.
            }
        }
        guard let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}"), start < end else { throw AIServiceError.generationFailed("Gemma 4 returned no usable JSON. Please try again.") }
        let slice = String(cleaned[start...end])
        let fixed = slice.replacingOccurrences(of: #"\\(?![\"\\/bfnrtu])"#, with: #"\\\\"#, options: .regularExpression).replacingOccurrences(of: #",\s*([}\]])"#, with: #"$1"#, options: .regularExpression)
        guard let data = fixed.data(using: .utf8) else { throw AIServiceError.generationFailed("Gemma 4 returned malformed JSON. Please try again.") }
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard JSONSerialization.isValidJSONObject(object) else { throw AIServiceError.generationFailed("Gemma 4 returned malformed JSON. Please try again.") }
            return data
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.generationFailed("Gemma 4 returned malformed JSON. Please try again.")
        }
    }
}
