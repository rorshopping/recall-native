import SwiftUI

enum RecallTab: Hashable {
    case decks, create, stats, settings
}

struct RootView: View {
    @State private var selectedTab: RecallTab = .decks

    var body: some View {
        TabView(selection: $selectedTab) {
            DecksView()
                .tabItem { Label("Decks", systemImage: "tray.full") }
                .tag(RecallTab.decks)
            CreateView()
                .tabItem { Label("Create", systemImage: "sparkles") }
                .tag(RecallTab.create)
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(RecallTab.stats)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(RecallTab.settings)
        }
        .tint(RecallTheme.accent)
    }
}
