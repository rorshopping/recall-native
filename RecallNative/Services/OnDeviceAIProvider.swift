import Foundation

/// Describes the preferred on-device generation backend without coupling the UI to a specific model implementation.
enum OnDeviceAIProvider: Sendable, Equatable {
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

    var isAvailable: Bool {
        self != .unavailable
    }

    var systemImage: String {
        switch self {
        case .apple: return "apple.logo"
        case .gemma: return "cpu"
        case .unavailable: return "exclamationmark.triangle"
        }
    }

    static func current(gemmaAvailable: Bool, appleAvailable: Bool? = nil) -> OnDeviceAIProvider {
        #if canImport(FoundationModels)
        if let appleAvailable {
            return appleAvailable ? .apple : (gemmaAvailable ? .gemma : .unavailable)
        }
        if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable {
            return .apple
        }
        #else
        if let appleAvailable {
            return appleAvailable ? .apple : (gemmaAvailable ? .gemma : .unavailable)
        }
        #endif
        return gemmaAvailable ? .gemma : .unavailable
    }
}
