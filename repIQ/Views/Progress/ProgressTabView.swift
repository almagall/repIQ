import SwiftUI

struct ProgressTabView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                EmptyStateView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "No Progress Data",
                    message: "Complete your first workout to start tracking your progress and PRs."
                )
            }
            .background(RQColors.background)
            .navigationTitle("Progress")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
