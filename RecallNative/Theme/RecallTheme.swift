import SwiftUI

enum RecallTheme {
    static let accent = Color.indigo
    static let canvas = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)

    static let contentPadding: CGFloat = 20
    static let cardRadius: CGFloat = 22
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
                    .strokeBorder(.quaternary, lineWidth: 1)
            }
    }
}
