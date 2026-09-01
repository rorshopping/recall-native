import SwiftUI

struct RecallPalette: Sendable {
    let accent: Color
    let canvas: Color
    let cardBackground: Color
    let cardStroke: Color
}

enum RecallTheme {
    static let contentPadding: CGFloat = 20
    static let cardRadius: CGFloat = 22

    static var selectedID: String {
        UserDefaults.standard.string(forKey: "designTheme") ?? "recall"
    }

    static var palette: RecallPalette {
        switch selectedID {
        case "paper":
            return RecallPalette(accent: Color(red: 0.46, green: 0.29, blue: 0.15), canvas: Color(red: 0.96, green: 0.94, blue: 0.89), cardBackground: Color(red: 0.99, green: 0.98, blue: 0.94), cardStroke: Color(red: 0.80, green: 0.76, blue: 0.67))
        case "midnight":
            return RecallPalette(accent: Color(red: 0.45, green: 0.62, blue: 1.0), canvas: Color(red: 0.055, green: 0.065, blue: 0.10), cardBackground: Color(red: 0.10, green: 0.115, blue: 0.17), cardStroke: Color.white.opacity(0.12))
        case "minimal":
            return RecallPalette(accent: Color.primary, canvas: Color(.systemBackground), cardBackground: Color(.secondarySystemBackground), cardStroke: Color.primary.opacity(0.10))
        case "contrast":
            return RecallPalette(accent: Color(red: 0.93, green: 0.35, blue: 0.08), canvas: Color(.systemBackground), cardBackground: Color(.secondarySystemBackground), cardStroke: Color.primary.opacity(0.25))
        default:
            return RecallPalette(accent: Color.indigo, canvas: Color(.systemGroupedBackground), cardBackground: Color(.secondarySystemGroupedBackground), cardStroke: Color.primary.opacity(0.08))
        }
    }

    static var accent: Color { palette.accent }
    static var canvas: Color { palette.canvas }
    static var cardBackground: Color { palette.cardBackground }
    static var cardStroke: Color { palette.cardStroke }
}

struct RecallCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RecallTheme.cardBackground, in: RoundedRectangle(cornerRadius: RecallTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: RecallTheme.cardRadius, style: .continuous)
                    .strokeBorder(RecallTheme.cardStroke, lineWidth: 1)
            }
    }
}
