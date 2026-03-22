import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var workoutCoordinator = WorkoutCoordinator()
    @State private var activeWorkoutViewModel: ActiveWorkoutViewModel?
    @State private var socialViewModel = SocialViewModel()

    var body: some View {
        @Bindable var coordinator = workoutCoordinator

        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                DashboardView()
            }

            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis", value: 1) {
                ProgressTabView()
            }

            Tab("Social", systemImage: "person.2.fill", value: 2) {
                SocialTabView(viewModel: socialViewModel)
            }
            .badge(socialViewModel.notificationCount)

            Tab("Profile", systemImage: "person.fill", value: 3) {
                ProfileView()
            }
        }
        .tint(RQColors.accent)
        .environment(workoutCoordinator)
        .fullScreenCover(isPresented: $coordinator.showActiveWorkout) {
            // Clean up when dismissed
            activeWorkoutViewModel = nil
        } content: {
            if let template = workoutCoordinator.selectedTemplate,
               let day = workoutCoordinator.selectedWorkoutDay {
                let vm = makeWorkoutViewModel(template: template, day: day)
                ActiveWorkoutView(viewModel: vm) {
                    workoutCoordinator.dismissWorkout()
                }
                .environment(workoutCoordinator)
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
