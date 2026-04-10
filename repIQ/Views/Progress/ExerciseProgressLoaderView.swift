import SwiftUI
import Supabase

/// Lightweight wrapper that fetches an Exercise by ID and then displays
/// the full ExerciseProgressView. Used when navigating from the Strength
/// Trajectory card where we only have an exercise ID, not the full object.
struct ExerciseProgressLoaderView: View {
    let exerciseId: UUID
    @State private var exercise: Exercise?
    @State private var isLoading = true

    private let exerciseService = ExerciseLibraryService()

    var body: some View {
        Group {
            if let exercise {
                ExerciseProgressView(exercise: exercise)
            } else if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RQColors.background)
            } else {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Exercise Not Found",
                    message: "Could not load exercise details."
                )
            }
        }
        .task {
            do {
                exercise = try await exerciseService.fetchExercise(id: exerciseId)
            } catch {
                // Leave exercise nil — empty state will show
            }
            isLoading = false
        }
    }
}
