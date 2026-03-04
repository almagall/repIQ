import SwiftUI

@Observable
final class ExercisePickerViewModel {
    var exercises: [Exercise] = []
    var searchText = ""
    var selectedMuscleGroup: String?
    var selectedEquipment: String?
    var isLoading = false

    private let service = ExerciseLibraryService()

    var filteredExercises: [Exercise] {
        exercises
    }

    var groupedExercises: [(String, [Exercise])] {
        let grouped = Dictionary(grouping: filteredExercises) { $0.muscleGroup.capitalized }
        return grouped.sorted { $0.key < $1.key }
    }

    func search() async {
        isLoading = true
        do {
            exercises = try await service.fetchExercises(
                muscleGroup: selectedMuscleGroup,
                equipment: selectedEquipment,
                searchQuery: searchText.isEmpty ? nil : searchText
            )
        } catch {
            exercises = []
        }
        isLoading = false
    }

    func clearFilters() {
        selectedMuscleGroup = nil
        selectedEquipment = nil
        searchText = ""
    }
}

struct ExercisePickerView: View {
    let onSelect: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ExercisePickerViewModel()

    private let muscleGroups = MuscleGroup.allCases
    private let equipmentTypes = Equipment.allCases

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: RQSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(RQColors.textTertiary)
                    TextField("Search exercises...", text: $viewModel.searchText)
                        .font(RQTypography.body)
                        .foregroundColor(RQColors.textPrimary)
                        .autocorrectionDisabled()
                        .onChange(of: viewModel.searchText) {
                            Task { await viewModel.search() }
                        }
                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                            Task { await viewModel.search() }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(RQColors.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, RQSpacing.lg)
                .frame(height: 44)
                .background(RQColors.surfaceTertiary)
                .cornerRadius(RQRadius.medium)
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.vertical, RQSpacing.sm)

                // Muscle group filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: RQSpacing.sm) {
                        filterChip(title: "All", isSelected: viewModel.selectedMuscleGroup == nil) {
                            viewModel.selectedMuscleGroup = nil
                            Task { await viewModel.search() }
                        }
                        ForEach(muscleGroups, id: \.self) { group in
                            filterChip(
                                title: group.displayName,
                                isSelected: viewModel.selectedMuscleGroup == group.rawValue
                            ) {
                                viewModel.selectedMuscleGroup = group.rawValue
                                Task { await viewModel.search() }
                            }
                        }
                    }
                    .padding(.horizontal, RQSpacing.screenHorizontal)
                }
                .padding(.bottom, RQSpacing.sm)

                // Exercise list
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                    Spacer()
                } else if viewModel.exercises.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "dumbbell",
                        title: "No Exercises Found",
                        message: "Try adjusting your search or filters."
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.groupedExercises, id: \.0) { group, exercises in
                            Section {
                                ForEach(exercises) { exercise in
                                    Button {
                                        onSelect(exercise)
                                        dismiss()
                                    } label: {
                                        exerciseRow(exercise)
                                    }
                                    .listRowBackground(Color.clear)
                                }
                            } header: {
                                Text(group)
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.accent)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(RQColors.background)
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(RQColors.accent)
                }
            }
            .task {
                await viewModel.search()
            }
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        HStack(spacing: RQSpacing.md) {
            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                Text(exercise.name)
                    .font(RQTypography.body)
                    .foregroundColor(RQColors.textPrimary)
                HStack(spacing: RQSpacing.sm) {
                    Text(exercise.equipment.capitalized)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                    if exercise.isCompound {
                        Text("Compound")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.accent)
                    }
                }
            }
            Spacer()
            Image(systemName: "plus.circle")
                .foregroundColor(RQColors.accent)
        }
        .padding(.vertical, RQSpacing.xs)
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(RQTypography.label)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(isSelected ? RQColors.background : RQColors.textSecondary)
                .padding(.horizontal, RQSpacing.md)
                .padding(.vertical, RQSpacing.sm)
                .background(isSelected ? RQColors.accent : Color.clear)
                .cornerRadius(RQRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: RQRadius.small)
                        .stroke(isSelected ? RQColors.accent : RQColors.textTertiary, lineWidth: 1)
                )
        }
    }
}
