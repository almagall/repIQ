import SwiftUI
import Supabase

struct GoalSettingView: View {
    @State private var viewModel = GoalViewModel()
    @State private var showCreateGoal = false

    var body: some View {
        VStack(spacing: RQSpacing.lg) {
            if viewModel.activeGoals.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    icon: "target",
                    title: "No Goals Set",
                    message: "Set a training goal to track your progress and stay motivated.",
                    buttonTitle: "Set a Goal"
                ) {
                    showCreateGoal = true
                }
            } else {
                ScrollView {
                    VStack(spacing: RQSpacing.md) {
                        ForEach(viewModel.activeGoals) { goal in
                            goalCard(goal)
                        }

                        // Completed goals section
                        if !viewModel.completedGoals.isEmpty {
                            Text("Completed")
                                .font(RQTypography.label)
                                .textCase(.uppercase)
                                .tracking(1.5)
                                .foregroundColor(RQColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, RQSpacing.md)

                            ForEach(viewModel.completedGoals) { goal in
                                goalCard(goal)
                                    .opacity(0.6)
                            }
                        }
                    }
                    .padding(.horizontal, RQSpacing.screenHorizontal)
                    .padding(.top, RQSpacing.lg)
                    .padding(.bottom, RQSpacing.xxxl)
                }
            }
        }
        .background(RQColors.background)
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateGoal = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(RQColors.accent)
                }
            }
        }
        .sheet(isPresented: $showCreateGoal) {
            CreateGoalView { goal in
                viewModel.activeGoals.insert(goal, at: 0)
            }
        }
        .task {
            await viewModel.loadGoals()
        }
    }

    // MARK: - Redesigned Goal Card

    private func goalCard(_ goal: Goal) -> some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.md) {
                // Header: exercise name + type badge + pace status
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                        if let name = goal.exerciseName {
                            Text(name)
                                .font(RQTypography.headline)
                                .foregroundColor(RQColors.textPrimary)
                        }

                        HStack(spacing: RQSpacing.sm) {
                            // Goal type badge
                            Text(goal.goalTypeBadge)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(RQColors.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(RQColors.accent.opacity(0.15))
                                .cornerRadius(4)

                            Text("Target: \(goal.displayTarget)")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textSecondary)
                        }
                    }

                    Spacer()

                    if goal.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(RQColors.success)
                    } else {
                        // Pace status pill (when target date set)
                        let pace = goal.paceStatus
                        if pace != .noDate {
                            Text(pace.label)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(pace.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(pace.color.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                }

                // Progress bar with percentage
                VStack(spacing: RQSpacing.xs) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(RQColors.surfaceTertiary)
                                .frame(height: 6)

                            Capsule()
                                .fill(goal.isCompleted ? RQColors.success : RQColors.accent)
                                .frame(width: geo.size.width * goal.progress, height: 6)
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Text("\(Int(goal.progress * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(RQColors.accent)

                        if !goal.isCompleted && goal.delta > 0 {
                            Text("-- \(formatDelta(goal.delta)) \(goal.unit) to go")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }

                        Spacer()

                        // Milestone label
                        if let milestone = goal.milestoneLabel, !goal.isCompleted {
                            Text(milestone)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(RQColors.textSecondary)
                                .italic()
                        }
                    }
                }

                // Actionable insight
                if !goal.isCompleted {
                    Text(goal.nextStepDescription)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textSecondary)
                }

                // Time remaining (when target date set)
                if let timeDisplay = goal.timeRemainingDisplay, !goal.isCompleted {
                    HStack(spacing: RQSpacing.xs) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(goal.isOverdue ? .red : RQColors.textTertiary)

                        Text(timeDisplay)
                            .font(RQTypography.caption)
                            .foregroundColor(goal.isOverdue ? .red : RQColors.textTertiary)

                        if let targetDate = goal.targetDate {
                            Text("(\(targetDate, style: .date))")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }
                    }
                }
            }
        }
        .contextMenu {
            if !goal.isCompleted {
                Button {
                    Task { await viewModel.syncGoalProgress(goal) }
                } label: {
                    Label("Sync Progress", systemImage: "arrow.triangle.2.circlepath")
                }
                Button(role: .destructive) {
                    Task { await viewModel.abandonGoal(goal) }
                } label: {
                    Label("Abandon Goal", systemImage: "xmark.circle")
                }
            }
            Button(role: .destructive) {
                Task { await viewModel.deleteGoal(goal) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func formatDelta(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

// MARK: - Create Goal View

struct CreateGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var goalType: GoalType = .weight
    @State private var isEstimated1RM = false
    @State private var selectedExercise: Exercise?
    @State private var targetValue = ""
    @State private var targetDate = Date().addingTimeInterval(90 * 24 * 3600)
    @State private var hasTargetDate = true
    @State private var showExercisePicker = false
    @State private var isCreating = false
    @State private var currentBest: Double = 0
    @State private var isFetchingBest = false
    @State private var showReview = false
    @State private var createdGoal: Goal?
    @State private var errorMessage: String?
    var onCreated: (Goal) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RQSpacing.lg) {
                    // Goal Type
                    RQCard {
                        VStack(alignment: .leading, spacing: RQSpacing.md) {
                            Text("Goal Type")
                                .font(RQTypography.label)
                                .textCase(.uppercase)
                                .tracking(1.5)
                                .foregroundColor(RQColors.textSecondary)

                            ForEach([GoalType.weight, .reps, .consistency], id: \.self) { type in
                                Button {
                                    goalType = type
                                    if type != .weight { isEstimated1RM = false }
                                } label: {
                                    HStack {
                                        Image(systemName: type.icon)
                                            .font(.system(size: 16))
                                            .foregroundColor(goalType == type ? RQColors.accent : RQColors.textTertiary)
                                            .frame(width: 24)

                                        Text(type.displayName)
                                            .font(RQTypography.body)
                                            .foregroundColor(RQColors.textPrimary)

                                        Spacer()

                                        Image(systemName: goalType == type ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(goalType == type ? RQColors.accent : RQColors.textTertiary)
                                    }
                                    .padding(.vertical, RQSpacing.xs)
                                }
                            }
                        }
                    }

                    // Weight Goal Mode: Actual vs Est. 1RM
                    if goalType == .weight {
                        RQCard {
                            VStack(alignment: .leading, spacing: RQSpacing.md) {
                                HStack {
                                    Text("Weight Goal Type")
                                        .font(RQTypography.label)
                                        .textCase(.uppercase)
                                        .tracking(1.5)
                                        .foregroundColor(RQColors.textSecondary)

                                    Spacer()

                                    InfoButton(topic: ProgressExplainer.goalWeightType)
                                }

                                HStack(spacing: 0) {
                                    Button {
                                        isEstimated1RM = false
                                        fetchCurrentBest()
                                    } label: {
                                        Text("Actual Weight")
                                            .font(RQTypography.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(!isEstimated1RM ? .white : RQColors.textSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, RQSpacing.sm)
                                            .background(!isEstimated1RM ? RQColors.accent : RQColors.surfaceTertiary)
                                    }

                                    Button {
                                        isEstimated1RM = true
                                        fetchCurrentBest()
                                    } label: {
                                        Text("Estimated 1RM")
                                            .font(RQTypography.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(isEstimated1RM ? .white : RQColors.textSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, RQSpacing.sm)
                                            .background(isEstimated1RM ? RQColors.accent : RQColors.surfaceTertiary)
                                    }
                                }
                                .cornerRadius(RQRadius.medium)

                                Text(isEstimated1RM
                                    ? "Track your estimated max based on any set you complete"
                                    : "Track the heaviest weight you actually lift for reps")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                            }
                        }
                    }

                    // Exercise Selection (for weight/reps goals)
                    if goalType == .weight || goalType == .reps {
                        RQCard {
                            VStack(alignment: .leading, spacing: RQSpacing.md) {
                                Text("Exercise")
                                    .font(RQTypography.label)
                                    .textCase(.uppercase)
                                    .tracking(1.5)
                                    .foregroundColor(RQColors.textSecondary)

                                Button {
                                    showExercisePicker = true
                                } label: {
                                    HStack {
                                        Text(selectedExercise?.name ?? "Select Exercise")
                                            .font(RQTypography.body)
                                            .foregroundColor(selectedExercise != nil ? RQColors.textPrimary : RQColors.textTertiary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(RQColors.textTertiary)
                                    }
                                }

                                // Current best display
                                if selectedExercise != nil && currentBest > 0 {
                                    HStack(spacing: RQSpacing.xs) {
                                        Image(systemName: "info.circle")
                                            .font(.system(size: 12))
                                            .foregroundColor(RQColors.accent)
                                        Text("Current \(isEstimated1RM ? "est. 1RM" : "best"): \(formatValue(currentBest)) lbs")
                                            .font(RQTypography.caption)
                                            .foregroundColor(RQColors.accent)
                                    }
                                } else if isFetchingBest {
                                    HStack(spacing: RQSpacing.xs) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                                            .scaleEffect(0.7)
                                        Text("Loading current best...")
                                            .font(RQTypography.caption)
                                            .foregroundColor(RQColors.textTertiary)
                                    }
                                }
                            }
                        }
                    }

                    // Target Value
                    RQCard {
                        VStack(alignment: .leading, spacing: RQSpacing.md) {
                            Text("Target")
                                .font(RQTypography.label)
                                .textCase(.uppercase)
                                .tracking(1.5)
                                .foregroundColor(RQColors.textSecondary)

                            HStack {
                                TextField(targetPlaceholder, text: $targetValue)
                                    .font(RQTypography.numbers)
                                    .foregroundColor(RQColors.textPrimary)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, RQSpacing.md)
                                    .background(RQColors.surfaceTertiary)
                                    .cornerRadius(RQRadius.medium)

                                Text(targetUnit)
                                    .font(RQTypography.body)
                                    .foregroundColor(RQColors.textSecondary)
                            }
                        }
                    }

                    // Target Date
                    RQCard {
                        VStack(alignment: .leading, spacing: RQSpacing.md) {
                            Toggle(isOn: $hasTargetDate) {
                                Text("Target Date")
                                    .font(RQTypography.label)
                                    .textCase(.uppercase)
                                    .tracking(1.5)
                                    .foregroundColor(RQColors.textSecondary)
                            }
                            .tint(RQColors.accent)

                            if hasTargetDate {
                                // Days from now context
                                let daysFromNow = Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day ?? 0
                                Text("\(daysFromNow) days from today")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)

                                DatePicker("", selection: $targetDate, in: Date()..., displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                    .tint(RQColors.accent)
                            }
                        }
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.top, RQSpacing.lg)
                .padding(.bottom, RQSpacing.xxxl)
            }
            .background(RQColors.background)
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(RQColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        showReview = true
                    }
                    .foregroundColor(RQColors.accent)
                    .disabled(!isFormValid || isCreating)
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { exercise in
                    selectedExercise = exercise
                    showExercisePicker = false
                    fetchCurrentBest()
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .overlay {
                if showReview {
                    goalReviewOverlay
                }
                if let goal = createdGoal {
                    goalCreatedOverlay(goal)
                }
            }
        }
    }

    // MARK: - Review Overlay

    @ViewBuilder
    private var goalReviewOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { showReview = false }

            VStack(spacing: RQSpacing.lg) {
                Image(systemName: "target")
                    .font(.system(size: 36))
                    .foregroundColor(RQColors.accent)

                Text("Review Goal")
                    .font(RQTypography.title1)
                    .foregroundColor(RQColors.textPrimary)

                VStack(spacing: RQSpacing.md) {
                    if let name = selectedExercise?.name {
                        reviewRow(label: "Exercise", value: name)
                    }
                    reviewRow(label: "Type", value: goalType == .weight && isEstimated1RM ? "Estimated 1RM" : goalType.displayName)
                    reviewRow(label: "Target", value: "\(targetValue) \(targetUnit)")
                    if currentBest > 0 {
                        reviewRow(label: "Current Best", value: "\(formatValue(currentBest)) \(targetUnit)")
                    }
                    if hasTargetDate {
                        let daysFromNow = Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day ?? 0
                        reviewRow(label: "Deadline", value: "\(daysFromNow) days from now")
                    }
                }
                .padding(RQSpacing.lg)
                .background(RQColors.surfaceSecondary)
                .cornerRadius(RQRadius.large)

                HStack(spacing: RQSpacing.md) {
                    Button {
                        showReview = false
                    } label: {
                        Text("Edit")
                            .font(RQTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(RQColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, RQSpacing.md)
                            .background(RQColors.surfaceTertiary)
                            .cornerRadius(RQRadius.medium)
                    }

                    Button {
                        showReview = false
                        Task { await createGoal() }
                    } label: {
                        Text("Confirm")
                            .font(RQTypography.body)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, RQSpacing.md)
                            .background(RQColors.accent)
                            .cornerRadius(RQRadius.medium)
                    }
                    .disabled(isCreating)
                }
            }
            .padding(RQSpacing.xl)
            .padding(.horizontal, RQSpacing.md)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: showReview)
    }

    private func reviewRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(RQTypography.caption)
                .foregroundColor(RQColors.textTertiary)
            Spacer()
            Text(value)
                .font(RQTypography.body)
                .fontWeight(.medium)
                .foregroundColor(RQColors.textPrimary)
        }
    }

    // MARK: - Goal Created Overlay

    private func goalCreatedOverlay(_ goal: Goal) -> some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    onCreated(goal)
                    dismiss()
                }

            VStack(spacing: RQSpacing.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(RQColors.success)

                Text("Goal Set")
                    .font(RQTypography.title1)
                    .foregroundColor(RQColors.textPrimary)

                VStack(spacing: RQSpacing.xs) {
                    if let name = goal.exerciseName {
                        Text(name)
                            .font(RQTypography.headline)
                            .foregroundColor(RQColors.textPrimary)
                    }
                    Text("\(goal.goalTypeBadge): \(goal.displayTarget)")
                        .font(RQTypography.body)
                        .foregroundColor(RQColors.textSecondary)

                    if let timeDisplay = goal.timeRemainingDisplay {
                        Text(timeDisplay)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }
                }

                Button {
                    onCreated(goal)
                    dismiss()
                } label: {
                    Text("Continue")
                        .font(RQTypography.body)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RQSpacing.md)
                        .background(RQColors.accent)
                        .cornerRadius(RQRadius.medium)
                }
            }
            .padding(RQSpacing.xl)
            .padding(.horizontal, RQSpacing.md)
        }
        .transition(.opacity)
    }

    private var targetPlaceholder: String {
        switch goalType {
        case .weight: return isEstimated1RM ? "315" : "225"
        case .reps: return "10"
        case .consistency: return "4"
        case .volume: return "50000"
        case .bodyweight: return "180"
        }
    }

    private var targetUnit: String {
        switch goalType {
        case .weight: return "lbs"
        case .reps: return "reps"
        case .consistency: return "sessions/week"
        case .volume: return "lbs/week"
        case .bodyweight: return "lbs"
        }
    }

    private var isFormValid: Bool {
        guard let value = Double(targetValue), value > 0 else { return false }
        if (goalType == .weight || goalType == .reps) && selectedExercise == nil { return false }
        return true
    }

    private func fetchCurrentBest() {
        guard let exercise = selectedExercise, goalType == .weight else { return }
        isFetchingBest = true
        Task {
            do {
                guard let userId = try? await supabase.auth.session.user.id else { return }
                currentBest = try await GoalService().fetchCurrentBest(
                    userId: userId,
                    exerciseId: exercise.id,
                    isEstimated1RM: isEstimated1RM
                )
            } catch {}
            isFetchingBest = false
        }
    }

    private func createGoal() async {
        guard let value = Double(targetValue) else { return }
        isCreating = true

        do {
            guard let userId = try await supabase.auth.session.user.id as UUID? else {
                errorMessage = "Unable to get user session. Please sign in again."
                isCreating = false
                return
            }
            let goal = try await GoalService().createGoal(
                userId: userId,
                goalType: goalType,
                exerciseId: selectedExercise?.id,
                exerciseName: selectedExercise?.name,
                targetValue: value,
                startingValue: currentBest,
                isEstimated1RM: isEstimated1RM,
                unit: targetUnit,
                targetDate: hasTargetDate ? targetDate : nil
            )
            createdGoal = goal
        } catch {
            errorMessage = "Failed to create goal: \(error.localizedDescription)"
            isCreating = false
        }
    }

    private func formatValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
