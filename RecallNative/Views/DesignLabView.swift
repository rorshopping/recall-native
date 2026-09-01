import SwiftUI

struct DesignLabView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("designTheme") private var designTheme = "recall"
    private let themes: [(id: String, name: String, tagline: String, icon: String)] = [
        ("recall", "Recall", "Clean and focused", "sparkles"),
        ("paper", "Paper", "Quiet study desk", "doc.text"),
        ("midnight", "Midnight", "Deep focus", "moon.stars.fill"),
        ("minimal", "Minimal", "Pure and restrained", "circle"),
        ("contrast", "Contrast", "High-energy study", "bolt.fill")
    ]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DESIGN LAB").font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(.secondary)
                        Text("Visual themes").font(.largeTitle.bold())
                        Text("Developer-only visual exploration. Study data and behavior never change.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    RecallCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Active theme").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(themes.first(where: { $0.id == designTheme })?.name ?? "Recall").font(.title2.bold())
                            Text(themes.first(where: { $0.id == designTheme })?.tagline ?? "").foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                Circle().fill(RecallTheme.accent).frame(width: 28, height: 28)
                                RoundedRectangle(cornerRadius: 8).fill(RecallTheme.cardBackground).frame(width: 52, height: 28).overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                                RoundedRectangle(cornerRadius: 8).fill(RecallTheme.canvas).frame(width: 52, height: 28).overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                            }
                        }
                    }
                    Text("THEMES").font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(.secondary)
                    ForEach(themes, id: \.id) { theme in
                        Button { designTheme = theme.id } label: {
                            HStack(spacing: 14) {
                                Image(systemName: theme.icon).frame(width: 28).foregroundStyle(theme.id == designTheme ? RecallTheme.accent : .secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(theme.name).font(.headline).foregroundStyle(.primary)
                                    Text(theme.tagline).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: theme.id == designTheme ? "checkmark.circle.fill" : "circle").foregroundStyle(theme.id == designTheme ? RecallTheme.accent : .tertiary)
                            }
                            .padding(16)
                            .background(RecallTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(theme.id == designTheme ? RecallTheme.accent : .quaternary, lineWidth: theme.id == designTheme ? 2 : 1))
                        }.buttonStyle(.plain)
                    }
                    RecallCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Live component preview").font(.headline)
                            Text("Study heading").font(.title2.bold())
                            Text("Cards, decks, statistics and study controls use the same native design system.").font(.subheadline).foregroundStyle(.secondary)
                            HStack(spacing: 10) {
                                Button("Primary") {}.buttonStyle(.borderedProminent)
                                Button("Secondary") {}.buttonStyle(.bordered)
                            }
                            ProgressView(value: 0.68).tint(RecallTheme.accent)
                        }
                    }
                    Text("Theme selection is persisted locally. It does not alter scheduling, data, or navigation.").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding()
            }.background(RecallTheme.canvas).navigationTitle("Design Lab").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
