import SwiftUI

/// View for selecting an exercise substitution during an active workout.
/// Shows suggested exercises (same muscle group) and allows full manual browsing.
struct ExerciseSubstitutionView: View {
    let currentExercise: ExerciseLogEntry
    let onSelect: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var suggestedExercises: [Exercise] = []
    @State private var allExercises: [Exercise] = []
    @State private var searchText = ""
    @State private var selectedTab: SubstitutionTab = .suggested
    @State private var selectedMuscleGroup: String?
    @State private var isLoading = false

    private let service = ExerciseLibraryService()

    enum SubstitutionTab: String, CaseIterable {
        case suggested = "Suggested"
        case browse = "Browse All"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Current exercise info
                currentExerciseHeader

                // Tab selector
                tabSelector

                // Search bar
                searchBar

                // Content
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                    Spacer()
                } else {
                    switch selectedTab {
                    case .suggested:
                        suggestedList
                    case .browse:
                        browseList
                    }
                }
            }
            .background(RQColors.background)
            .navigationTitle("Swap Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(RQColors.accent)
                }
            }
            .task {
                await loadExercises()
            }
        }
    }

    // MARK: - Current Exercise Header

    private var currentExerciseHeader: some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                Text("REPLACING")
                    .font(RQTypography.label)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(RQColors.textTertiary)

                HStack(spacing: RQSpacing.sm) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 14))
                        .foregroundColor(RQColors.warning)

                    Text(currentExercise.exerciseName)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)
                }

                HStack(spacing: RQSpacing.sm) {
                    Text(currentExercise.muscleGroup.capitalized)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                    Text("·")
                        .foregroundColor(RQColors.textTertiary)
                    Text(currentExercise.equipment.capitalized)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }

                // Info callout
                HStack(spacing: RQSpacing.sm) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(RQColors.accent)
                    Text("Targets will be based on the substitute exercise's history, not the original.")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textSecondary)
                }
                .padding(.top, RQSpacing.xs)
            }
        }
        .padding(.horizontal, RQSpacing.screenHorizontal)
        .padding(.top, RQSpacing.sm)
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(SubstitutionTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(selectedTab == tab ? RQColors.background : RQColors.textSecondary)
                        .padding(.horizontal, RQSpacing.lg)
                        .padding(.vertical, RQSpacing.sm)
                        .background(selectedTab == tab ? RQColors.accent : RQColors.surfaceTertiary)
                }
            }
        }
        .cornerRadius(RQRadius.small)
        .padding(.horizontal, RQSpacing.screenHorizontal)
        .padding(.vertical, RQSpacing.sm)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: RQSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(RQColors.textTertiary)
            TextField("Search exercises...", text: $searchText)
                .font(RQTypography.body)
                .foregroundColor(RQColors.textPrimary)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
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
        .padding(.bottom, RQSpacing.sm)
    }

    // MARK: - Suggested List

    private var suggestedList: some View {
        let filtered = filteredSuggested
        return Group {
            if filtered.isEmpty {
                emptyState(message: "No matching exercises found for this muscle group.")
            } else {
                ScrollView {
                    LazyVStack(spacing: RQSpacing.sm) {
                        ForEach(filtered) { exercise in
                            exerciseRow(exercise, showMuscleGroup: false)
                        }
                    }
                    .padding(.horizontal, RQSpacing.screenHorizontal)
                    .padding(.bottom, RQSpacing.xxxl)
                }
            }
        }
    }

    // MARK: - Browse List

    private var browseList: some View {
        let filtered = filteredAll
        let grouped = Dictionary(grouping: filtered) { $0.muscleGroup.capitalized }
        let sortedGroups = grouped.sorted { $0.key < $1.key }

        return Group {
            if filtered.isEmpty {
                emptyState(message: "No exercises found. Try adjusting your search.")
            } else {
                // Muscle group filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: RQSpacing.sm) {
                        filterChip(title: "All", isSelected: selectedMuscleGroup == nil) {
                            selectedMuscleGroup = nil
                        }
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            filterChip(
                                title: group.displayName,
                                isSelected: selectedMuscleGroup == group.rawValue
                            ) {
                                selectedMuscleGroup = group.rawValue
                            }
                        }
                    }
                    .padding(.horizontal, RQSpacing.screenHorizontal)
                }
                .padding(.bottom, RQSpacing.sm)

                ScrollView {
                    LazyVStack(spacing: RQSpacing.sm) {
                        ForEach(sortedGroups, id: \.key) { group, exercises in
                            // Group header
                            HStack {
                                Text(group)
                                    .font(RQTypography.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(RQColors.accent)
                                Spacer()
                                Text("\(exercises.count)")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                            }
                            .padding(.top, RQSpacing.sm)

                            ForEach(exercises) { exercise in
                                exerciseRow(exercise, showMuscleGroup: true)
                            }
                        }
                    }
                    .padding(.horizontal, RQSpacing.screenHorizontal)
                    .padding(.bottom, RQSpacing.xxxl)
                }
            }
        }
    }

    // MARK: - Exercise Row

    private func exerciseRow(_ exercise: Exercise, showMuscleGroup: Bool) -> some View {
        Button {
            onSelect(exercise)
            dismiss()
        } label: {
            HStack(spacing: RQSpacing.md) {
                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(exercise.name)
                        .font(RQTypography.body)
                        .foregroundColor(RQColors.textPrimary)

                    HStack(spacing: RQSpacing.sm) {
                        Text(exercise.equipment.capitalized)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)

                        if showMuscleGroup {
                            Text("·")
                                .foregroundColor(RQColors.textTertiary)
                            Text(exercise.muscleGroup.capitalized)
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }

                        if exercise.isCompound {
                            Text("Compound")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.accent)
                        }
                    }
                }

                Spacer()

                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 14))
                    .foregroundColor(RQColors.accent)
            }
            .padding(.vertical, RQSpacing.sm)
            .padding(.horizontal, RQSpacing.md)
            .background(RQColors.surfaceSecondary)
            .cornerRadius(RQRadius.medium)
        }
    }

    // MARK: - Empty State

    private func emptyState(message: String) -> some View {
        VStack(spacing: RQSpacing.md) {
            Spacer()
            Image(systemName: "dumbbell")
                .font(.system(size: 32))
                .foregroundColor(RQColors.textTertiary)
            Text(message)
                .font(RQTypography.subheadline)
                .foregroundColor(RQColors.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, RQSpacing.xl)
    }

    // MARK: - Filter Chip

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

    // MARK: - Filtering

    private var filteredSuggested: [Exercise] {
        let exercises = suggestedExercises.filter { $0.id != currentExercise.exerciseId }
        if searchText.isEmpty { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredAll: [Exercise] {
        var exercises = allExercises.filter { $0.id != currentExercise.exerciseId }
        if let muscleGroup = selectedMuscleGroup {
            exercises = exercises.filter { $0.muscleGroup == muscleGroup }
        }
        if !searchText.isEmpty {
            exercises = exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return exercises
    }

    // MARK: - Data Loading

    private func loadExercises() async {
        isLoading = true

        // Fetch suggested (same muscle group) and all exercises in parallel
        async let suggestedTask = service.fetchExercises(muscleGroup: currentExercise.muscleGroup)
        async let allTask = service.fetchExercises()

        suggestedExercises = (try? await suggestedTask) ?? []
        allExercises = (try? await allTask) ?? []

        isLoading = false
    }
}
