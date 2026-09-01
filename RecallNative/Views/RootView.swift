import SwiftUI

enum RecallTab: Hashable {
    case today, library, create, review, settings
}

struct RootView: View {
    @State private var selectedTab: RecallTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(onStartReview: { selectedTab = .review })
                .tabItem { Label("Today", systemImage: "sparkles") }
                .tag(RecallTab.today)
            DecksView()
                .tabItem { Label("Library", systemImage: "rectangle.stack") }
                .tag(RecallTab.library)
            CreateView()
                .tabItem { Label("Create", systemImage: "plus.circle.fill") }
                .tag(RecallTab.create)
            ReviewView()
                .tabItem { Label("Review", systemImage: "brain.head.profile") }
                .tag(RecallTab.review)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(RecallTab.settings)
        }
        .tint(RecallTheme.accent)
    }
}
