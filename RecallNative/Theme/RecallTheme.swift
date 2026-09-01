import SwiftUI

enum RecallTheme {
    static let accent = Color.indigo
    static let cardBackground = Color(.secondarySystemBackground)
    static let canvas = Color(.systemGroupedBackground)
}

struct RecallCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            }
    }
}
