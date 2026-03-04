import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var workoutCoordinator = WorkoutCoordinator()
    @State private var activeWorkoutViewModel: ActiveWorkoutViewModel?

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
        .environment(workoutCoordinator)
        .fullScreenCover(isPresented: $workoutCoordinator.showActiveWorkout) {
            // Clean up when dismissed
            activeWorkoutViewModel = nil
        } content: {
            if let template = workoutCoordinator.selectedTemplate,
               let day = workoutCoordinator.selectedWorkoutDay {
                let vm = makeWorkoutViewModel(template: template, day: day)
                ActiveWorkoutView(viewModel: vm) {
                    workoutCoordinator.dismissWorkout()
                }
            }
        }
    }

    private func makeWorkoutViewModel(template: Template, day: WorkoutDay) -> ActiveWorkoutViewModel {
        if let existing = activeWorkoutViewModel {
            return existing
        }
        let vm = ActiveWorkoutViewModel()
        activeWorkoutViewModel = vm
        return vm
    }
}
