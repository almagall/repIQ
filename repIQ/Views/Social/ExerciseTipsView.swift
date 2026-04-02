import SwiftUI
import Supabase

/// Crowdsourced exercise tips feed with upvote/downvote system.
struct ExerciseTipsView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var tips: [ExerciseTip] = []
    @State private var isLoading = false
    @State private var showingAddTip = false
    @State private var selectedFilter: TipType?

    // For browsing all exercises
    @State private var exercises: [(id: UUID, name: String, muscleGroup: String)] = []
    @State private var selectedExerciseId: UUID?
    @State private var selectedExerciseName: String = ""
    @State private var searchQuery = ""
    @State private var showingExercisePicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Exercise selector
            exerciseSelector

            // Filter tabs
            filterTabs

            // Tips list
            ScrollView {
                LazyVStack(spacing: RQSpacing.md) {
                    if isLoading {
                        ProgressView()
                            .tint(RQColors.accent)
                            .padding(.top, RQSpacing.xxxl)
                    } else if filteredTips.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredTips) { tip in
                            tipCard(tip)
                        }
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.vertical, RQSpacing.lg)
            }
        }
        .background(RQColors.background)
        .navigationTitle("Exercise Tips")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddTip = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(RQColors.accent)
                }
                .disabled(selectedExerciseId == nil)
            }
        }
        .task {
            await loadExercises()
        }
        .sheet(isPresented: $showingAddTip) {
            addTipSheet
        }
        .sheet(isPresented: $showingExercisePicker) {
            exercisePickerSheet
        }
    }

    // MARK: - Exercise Selector

    private var exerciseSelector: some View {
        Button {
            showingExercisePicker = true
        } label: {
            HStack {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 14))
                    .foregroundColor(RQColors.accent)
                Text(selectedExerciseName.isEmpty ? "Select an exercise" : selectedExerciseName)
                    .font(RQTypography.headline)
                    .foregroundColor(selectedExerciseName.isEmpty ? RQColors.textTertiary : RQColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(RQColors.textTertiary)
            }
            .padding(RQSpacing.md)
            .background(RQColors.surfacePrimary)
        }
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RQSpacing.sm) {
                filterChip(label: "All", type: nil)
                ForEach(TipType.allCases, id: \.self) { type in
                    filterChip(label: type.displayName, type: type)
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.sm)
        }
        .background(RQColors.surfacePrimary.opacity(0.5))
    }

    private func filterChip(label: String, type: TipType?) -> some View {
        Button {
            selectedFilter = type
        } label: {
            Text(label)
                .font(RQTypography.caption)
                .fontWeight(selectedFilter == type ? .bold : .regular)
                .foregroundColor(selectedFilter == type ? RQColors.background : RQColors.textSecondary)
                .padding(.horizontal, RQSpacing.md)
                .padding(.vertical, RQSpacing.xs)
                .background(selectedFilter == type ? RQColors.accent : RQColors.surfaceTertiary)
                .cornerRadius(RQRadius.large)
        }
    }

    private var filteredTips: [ExerciseTip] {
        guard let filter = selectedFilter else { return tips }
        return tips.filter { $0.tipType == filter }
    }

    // MARK: - Tip Card

    private func tipCard(_ tip: ExerciseTip) -> some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.md) {
                // Header
                HStack(spacing: RQSpacing.sm) {
                    // Type badge
                    HStack(spacing: RQSpacing.xxs) {
                        Image(systemName: tip.tipType.icon)
                            .font(.system(size: 10))
                        Text(tip.tipType.displayName)
                            .font(RQTypography.label)
                    }
                    .foregroundColor(RQColors.accent)
                    .padding(.horizontal, RQSpacing.sm)
                    .padding(.vertical, RQSpacing.xxs)
                    .background(RQColors.accent.opacity(0.15))
                    .cornerRadius(RQRadius.small)

                    Spacer()

                    // Author
                    Text(tip.userProfile?.username ?? "User")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }

                // Content
                Text(tip.content)
                    .font(RQTypography.body)
                    .foregroundColor(RQColors.textPrimary)

                // Vote row
                HStack(spacing: RQSpacing.lg) {
                    // Upvote
                    Button {
                        Task { await voteTip(tip: tip, isUpvote: true) }
                    } label: {
                        HStack(spacing: RQSpacing.xxs) {
                            Image(systemName: tip.userVote?.isUpvote == true ? "arrow.up.circle.fill" : "arrow.up.circle")
                                .font(.system(size: 16))
                            Text("\(tip.upvoteCount)")
                                .font(RQTypography.caption)
                        }
                        .foregroundColor(tip.userVote?.isUpvote == true ? RQColors.success : RQColors.textTertiary)
                    }

                    // Downvote
                    Button {
                        Task { await voteTip(tip: tip, isUpvote: false) }
                    } label: {
                        HStack(spacing: RQSpacing.xxs) {
                            Image(systemName: tip.userVote?.isUpvote == false ? "arrow.down.circle.fill" : "arrow.down.circle")
                                .font(.system(size: 16))
                            Text("\(tip.downvoteCount)")
                                .font(RQTypography.caption)
                        }
                        .foregroundColor(tip.userVote?.isUpvote == false ? RQColors.error : RQColors.textTertiary)
                    }

                    Spacer()

                    // Score
                    Text("Score: \(tip.score)")
                        .font(RQTypography.numbersSmall)
                        .foregroundColor(tip.score > 0 ? RQColors.success : tip.score < 0 ? RQColors.error : RQColors.textTertiary)

                    // Flag (only for other users' tips)
                    if tip.userId != viewModel.currentUserId {
                        Button {
                            Task { await flagTip(tip) }
                        } label: {
                            Image(systemName: "flag")
                                .font(.system(size: 12))
                                .foregroundColor(RQColors.textTertiary)
                        }
                    }

                    // Delete (own tips)
                    if tip.userId == viewModel.currentUserId {
                        Button {
                            Task { await deleteTip(tip) }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(RQColors.error)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: RQSpacing.lg) {
            Image(systemName: "lightbulb")
                .font(.system(size: 40))
                .foregroundColor(RQColors.textTertiary)
            Text(selectedExerciseId == nil ? "Select an exercise" : "No tips yet")
                .font(RQTypography.headline)
                .foregroundColor(RQColors.textSecondary)
            Text(selectedExerciseId == nil
                 ? "Pick an exercise to see community tips."
                 : "Be the first to share a tip for this exercise!"
            )
            .font(RQTypography.footnote)
            .foregroundColor(RQColors.textTertiary)
            .multilineTextAlignment(.center)
        }
        .padding(.top, RQSpacing.xxxl)
    }

    // MARK: - Add Tip Sheet

    @State private var newTipContent = ""
    @State private var newTipType: TipType = .form

    private var addTipSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RQSpacing.xl) {
                    // Exercise
                    VStack(alignment: .leading, spacing: RQSpacing.sm) {
                        Text("EXERCISE")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)

                        Text(selectedExerciseName)
                            .font(RQTypography.headline)
                            .foregroundColor(RQColors.textPrimary)
                            .padding(RQSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RQColors.surfacePrimary)
                            .cornerRadius(RQRadius.medium)
                    }

                    // Tip type
                    VStack(alignment: .leading, spacing: RQSpacing.sm) {
                        Text("TIP TYPE")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: RQSpacing.sm) {
                            ForEach(TipType.allCases, id: \.self) { type in
                                Button {
                                    newTipType = type
                                } label: {
                                    VStack(spacing: RQSpacing.xxs) {
                                        Image(systemName: type.icon)
                                            .font(.system(size: 16))
                                        Text(type.displayName)
                                            .font(RQTypography.label)
                                    }
                                    .foregroundColor(newTipType == type ? RQColors.background : RQColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, RQSpacing.md)
                                    .background(newTipType == type ? RQColors.accent : RQColors.surfacePrimary)
                                    .cornerRadius(RQRadius.medium)
                                }
                            }
                        }
                    }

                    // Content
                    VStack(alignment: .leading, spacing: RQSpacing.sm) {
                        HStack {
                            Text("YOUR TIP")
                                .font(RQTypography.label)
                                .textCase(.uppercase)
                                .tracking(1.5)
                                .foregroundColor(RQColors.textSecondary)
                            Spacer()
                            Text("\(newTipContent.count)/500")
                                .font(RQTypography.caption)
                                .foregroundColor(newTipContent.count > 450 ? RQColors.warning : RQColors.textTertiary)
                        }

                        TextEditor(text: $newTipContent)
                            .font(RQTypography.body)
                            .foregroundColor(RQColors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                            .padding(RQSpacing.md)
                            .background(RQColors.surfacePrimary)
                            .cornerRadius(RQRadius.medium)
                            .onChange(of: newTipContent) { _, newValue in
                                if newValue.count > 500 {
                                    newTipContent = String(newValue.prefix(500))
                                }
                            }
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.vertical, RQSpacing.lg)
            }
            .background(RQColors.background)
            .navigationTitle("Share a Tip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showingAddTip = false
                        newTipContent = ""
                    }
                    .foregroundColor(RQColors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Post") {
                        Task {
                            await submitTip()
                            showingAddTip = false
                        }
                    }
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.accent)
                    .disabled(newTipContent.count < 10)
                }
            }
        }
    }

    // MARK: - Exercise Picker Sheet

    private var exercisePickerSheet: some View {
        NavigationStack {
            List {
                ForEach(filteredExercises, id: \.id) { exercise in
                    Button {
                        selectedExerciseId = exercise.id
                        selectedExerciseName = exercise.name
                        showingExercisePicker = false
                        Task { await loadTips() }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                                Text(exercise.name)
                                    .font(RQTypography.body)
                                    .foregroundColor(RQColors.textPrimary)
                                Text(exercise.muscleGroup.capitalized)
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                            }
                            Spacer()
                            if selectedExerciseId == exercise.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(RQColors.accent)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchQuery, prompt: "Search exercises")
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showingExercisePicker = false
                    }
                    .foregroundColor(RQColors.textSecondary)
                }
            }
        }
    }

    private var filteredExercises: [(id: UUID, name: String, muscleGroup: String)] {
        if searchQuery.isEmpty { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    // MARK: - Actions

    private func loadExercises() async {
        struct ExRow: Decodable {
            let id: UUID
            let name: String
            let muscle_group: String
        }

        do {
            let rows: [ExRow] = try await supabase.from("exercises")
                .select("id, name, muscle_group")
                .order("name")
                .execute()
                .value

            exercises = rows.map { (id: $0.id, name: $0.name, muscleGroup: $0.muscle_group) }
        } catch {
            // Silently fail
        }
    }

    private func loadTips() async {
        guard let exerciseId = selectedExerciseId,
              let userId = viewModel.currentUserId else { return }
        isLoading = true
        defer { isLoading = false }

        let service = TipsService()
        do {
            tips = try await service.fetchTips(exerciseId: exerciseId, userId: userId)
        } catch {
            // Silently fail
        }
    }

    private func submitTip() async {
        guard let exerciseId = selectedExerciseId,
              let userId = viewModel.currentUserId,
              newTipContent.count >= 10 else { return }

        let service = TipsService()
        do {
            let newTip = try await service.createTip(
                userId: userId,
                exerciseId: exerciseId,
                content: newTipContent,
                tipType: newTipType
            )
            tips.insert(newTip, at: 0)
            newTipContent = ""
        } catch {
            // Silently fail
        }
    }

    private func voteTip(tip: ExerciseTip, isUpvote: Bool) async {
        guard let userId = viewModel.currentUserId else { return }
        let service = TipsService()

        do {
            try await service.vote(tipId: tip.id, userId: userId, isUpvote: isUpvote)
            // Reload tips to get updated counts
            await loadTips()
        } catch {
            // Silently fail
        }
    }

    private func flagTip(_ tip: ExerciseTip) async {
        let service = TipsService()
        do {
            try await service.flagTip(tipId: tip.id)
            tips.removeAll { $0.id == tip.id }
        } catch {
            // Silently fail
        }
    }

    private func deleteTip(_ tip: ExerciseTip) async {
        let service = TipsService()
        do {
            try await service.deleteTip(tipId: tip.id)
            tips.removeAll { $0.id == tip.id }
        } catch {
            // Silently fail
        }
    }
}
