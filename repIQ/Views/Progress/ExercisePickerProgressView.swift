import SwiftUI

struct ExercisePickerProgressView: View {
    @State private var exercises: [Exercise] = []
    @State private var searchText = ""
    @State private var isLoading = false

    private let exerciseService = ExerciseLibraryService()

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return exercises
        }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var groupedExercises: [(group: String, exercises: [Exercise])] {
        let grouped = Dictionary(grouping: filteredExercises) { $0.muscleGroup }
        return grouped
            .map { (group: $0.key, exercises: $0.value.sorted { $0.name < $1.name }) }
            .sorted { ($0.group) < ($1.group) }
    }

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if exercises.isEmpty {
                EmptyStateView(
                    icon: "dumbbell",
                    title: "No Exercise Data",
                    message: "Complete workouts to see per-exercise progress."
                )
            } else {
                VStack(spacing: RQSpacing.lg) {
                    ForEach(groupedExercises, id: \.group) { section in
                        VStack(alignment: .leading, spacing: RQSpacing.md) {
                            // Group header
                            HStack {
                                Text(MuscleGroup(rawValue: section.group)?.displayName.uppercased() ?? section.group.uppercased())
                                    .font(RQTypography.label)
                                    .textCase(.uppercase)
                                    .tracking(1.5)
                                    .foregroundColor(RQColors.textSecondary)
                                Spacer()
                            }

                            ForEach(section.exercises) { exercise in
                                NavigationLink {
                                    ExerciseProgressView(exercise: exercise)
                                } label: {
                                    exerciseRow(exercise)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.top, RQSpacing.lg)
                .padding(.bottom, RQSpacing.xxxl)
            }
        }
        .background(RQColors.background)
        .navigationTitle("Exercise Progress")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .searchable(text: $searchText, prompt: "Search exercises")
        .task {
            await loadExercises()
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        RQCard {
            HStack {
                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(exercise.name)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)

                    HStack(spacing: RQSpacing.sm) {
                        Text(exercise.equipment.capitalized)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                        if exercise.isCompound {
                            Text("\u{00B7}")
                                .foregroundColor(RQColors.textTertiary)
                            Text("Compound")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(RQColors.textTertiary)
            }
        }
    }

    private func loadExercises() async {
        isLoading = true
        do {
            exercises = try await exerciseService.fetchExercises()
        } catch {
            // Silently handle
        }
        isLoading = false
    }
}
