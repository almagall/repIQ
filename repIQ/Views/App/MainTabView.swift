import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "house.fill", value: 0) {
                DashboardView()
            }

            Tab("Templates", systemImage: "rectangle.stack.fill", value: 1) {
                TemplateListView()
            }

            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis", value: 2) {
                ProgressTabView()
            }

            Tab("Profile", systemImage: "person.fill", value: 3) {
                ProfileView()
            }
        }
        .tint(RQColors.accent)
    }
}
