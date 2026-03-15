import SwiftUI
import Supabase

struct GoalSettingView: View {
    @State private var viewModel = GoalViewModel()
    @State private var showCreateGoal = false

    var body: some View {
        VStack(spacing: RQSpacing.lg) {
            // Active Goals
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

    private func goalCard(_ goal: Goal) -> some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.md) {
                HStack {
                    Image(systemName: goal.goalType.icon)
                        .font(.system(size: 16))
                        .foregroundColor(RQColors.accent)

                    VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                        if let name = goal.exerciseName {
                            Text(name)
                                .font(RQTypography.headline)
                                .foregroundColor(RQColors.textPrimary)
                        }
                        Text("\(goal.goalType.displayName): \(goal.displayTarget)")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textSecondary)
                    }

                    Spacer()

                    if goal.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(RQColors.success)
                    } else {
                        Text("\(Int(goal.progress * 100))%")
                            .font(RQTypography.numbersSmall)
                            .foregroundColor(RQColors.accent)
                    }
                }

                // Progress bar
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
                    Text("Current: \(goal.displayCurrent)")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)

                    Spacer()

                    if let targetDate = goal.targetDate {
                        Text("By \(targetDate, style: .date)")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
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
}

// MARK: - Create Goal View

struct CreateGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var goalType: GoalType = .weight
    @State private var selectedExercise: Exercise?
    @State private var targetValue = ""
    @State private var targetDate = Date().addingTimeInterval(90 * 24 * 3600) // 90 days out
    @State private var hasTargetDate = true
    @State private var showExercisePicker = false
    @State private var isCreating = false
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
                        Task { await createGoal() }
                    }
                    .foregroundColor(RQColors.accent)
                    .disabled(!isFormValid || isCreating)
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { exercise in
                    selectedExercise = exercise
                    showExercisePicker = false
                }
            }
        }
    }

    private var targetPlaceholder: String {
        switch goalType {
        case .weight: return "225"
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

    private func createGoal() async {
        guard let value = Double(targetValue) else { return }
        isCreating = true

        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            let goal = try await GoalService().createGoal(
                userId: userId,
                goalType: goalType,
                exerciseId: selectedExercise?.id,
                exerciseName: selectedExercise?.name,
                targetValue: value,
                unit: targetUnit,
                targetDate: hasTargetDate ? targetDate : nil
            )
            onCreated(goal)
            dismiss()
        } catch {
            isCreating = false
        }
    }
}
