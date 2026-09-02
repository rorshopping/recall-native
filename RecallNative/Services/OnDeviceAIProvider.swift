import Foundation

/// Describes the preferred on-device generation backend without coupling the UI to a specific model implementation.
enum OnDeviceAIProvider: Sendable {
    case apple
    case gemma
    case unavailable

    var displayName: String {
        switch self {
        case .apple: return "Apple on-device model"
        case .gemma: return "Gemma 4 E2B"
        case .unavailable: return "On-device AI unavailable"
        }
    }

    var detail: String {
        switch self {
        case .apple: return "Using Apple's on-device model. Gemma 4 is the automatic fallback."
        case .gemma: return "Using Gemma 4 E2B locally."
        case .unavailable: return "Download Gemma 4 to enable on-device generation."
        }
    }

    static func current(gemmaAvailable: Bool, appleAvailable: Bool? = nil) -> OnDeviceAIProvider {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if appleAvailable ?? SystemLanguageModel.default.isAvailable {
                return .apple
            }
        }
        #else
        _ = appleAvailable
        #endif
        return gemmaAvailable ? .gemma : .unavailable
    }
}
