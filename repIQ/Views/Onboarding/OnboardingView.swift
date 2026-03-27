import SwiftUI
import Supabase

struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var experienceLevel: OnboardingExperienceLevel?
    @State private var trainingGoal: TrainingGoal?
    @State private var selectedProgram: ProgramDefinition?
    @State private var selectedGoalPreset: GoalPreset?
    @State private var isCreatingTemplate = false
    var onComplete: () -> Void

    private let totalSteps = 5

    var body: some View {
        ZStack {
            RQColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: RQSpacing.sm) {
                    ForEach(0..<totalSteps, id: \.self) { step in
                        Capsule()
                            .fill(step <= currentStep ? RQColors.accent : RQColors.surfaceTertiary)
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.top, RQSpacing.lg)

                // Content
                TabView(selection: $currentStep) {
                    experienceStep.tag(0)
                    goalStep.tag(1)
                    programStep.tag(2)
                    goalPresetStep.tag(3)
                    howItWorksStep.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
    }

    // MARK: - Step 1: Experience Level

    private var experienceStep: some View {
        VStack(spacing: RQSpacing.xxxl) {
            Spacer()

            VStack(spacing: RQSpacing.md) {
                Text("Welcome to repIQ")
                    .font(RQTypography.largeTitle)
                    .foregroundColor(RQColors.accent)

                Text("Let's personalize your experience")
                    .font(RQTypography.subheadline)
                    .foregroundColor(RQColors.textSecondary)
            }

            VStack(spacing: RQSpacing.md) {
                Text("What's your training experience?")
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)

                ForEach(OnboardingExperienceLevel.allCases, id: \.self) { level in
                    Button {
                        experienceLevel = level
                    } label: {
                        onboardingOption(
                            icon: level.icon,
                            title: level.displayName,
                            subtitle: level.description,
                            isSelected: experienceLevel == level
                        )
                    }
                }
            }

            Spacer()

            RQButton(title: "Continue", isDisabled: experienceLevel == nil) {
                withAnimation { currentStep = 1 }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .padding(.horizontal, RQSpacing.screenHorizontal)
    }

    // MARK: - Step 2: Training Goal

    private var goalStep: some View {
        VStack(spacing: RQSpacing.xxxl) {
            Spacer()

            VStack(spacing: RQSpacing.md) {
                Text("What's your goal?")
                    .font(RQTypography.largeTitle)
                    .foregroundColor(RQColors.accent)

                Text("This helps us recommend the right program")
                    .font(RQTypography.subheadline)
                    .foregroundColor(RQColors.textSecondary)
            }

            VStack(spacing: RQSpacing.md) {
                ForEach(TrainingGoal.allCases, id: \.self) { goal in
                    Button {
                        trainingGoal = goal
                    } label: {
                        onboardingOption(
                            icon: goal.icon,
                            title: goal.displayName,
                            subtitle: goal.description,
                            isSelected: trainingGoal == goal
                        )
                    }
                }
            }

            Spacer()

            HStack(spacing: RQSpacing.md) {
                RQButton(title: "Back", style: .secondary) {
                    withAnimation { currentStep = 0 }
                }
                RQButton(title: "Continue", isDisabled: trainingGoal == nil) {
                    withAnimation { currentStep = 2 }
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .padding(.horizontal, RQSpacing.screenHorizontal)
    }

    // MARK: - Step 3: Program Selection

    private var programStep: some View {
        VStack(spacing: RQSpacing.lg) {
            VStack(spacing: RQSpacing.md) {
                Text("Pick a Program")
                    .font(RQTypography.largeTitle)
                    .foregroundColor(RQColors.accent)
                    .padding(.top, RQSpacing.xxxl)

                Text("You can always change this later")
                    .font(RQTypography.subheadline)
                    .foregroundColor(RQColors.textSecondary)
            }

            ScrollView {
                VStack(spacing: RQSpacing.md) {
                    ForEach(recommendedPrograms, id: \.id) { program in
                        Button {
                            selectedProgram = program
                        } label: {
                            programCard(program, isSelected: selectedProgram?.id == program.id)
                        }
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
            }

            VStack(spacing: RQSpacing.sm) {
                HStack(spacing: RQSpacing.md) {
                    RQButton(title: "Back", style: .secondary) {
                        withAnimation { currentStep = 1 }
                    }
                    RQButton(title: "Continue", isDisabled: selectedProgram == nil) {
                        withAnimation { currentStep = 3 }
                    }
                }

                Button {
                    withAnimation { currentStep = 3 }
                } label: {
                    Text("Skip for now")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }
                .padding(.bottom, RQSpacing.sm)
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.bottom, RQSpacing.xxxl)
        }
    }

    // MARK: - Step 4: Goal Preset

    private var goalPresetStep: some View {
        VStack(spacing: RQSpacing.xxxl) {
            Spacer()

            VStack(spacing: RQSpacing.md) {
                Text("Set a Goal")
                    .font(RQTypography.largeTitle)
                    .foregroundColor(RQColors.accent)

                Text("Goals keep you focused and help track progress")
                    .font(RQTypography.subheadline)
                    .foregroundColor(RQColors.textSecondary)
            }

            VStack(spacing: RQSpacing.md) {
                ForEach(goalPresets, id: \.title) { preset in
                    Button {
                        selectedGoalPreset = preset
                    } label: {
                        onboardingOption(
                            icon: preset.icon,
                            title: preset.title,
                            subtitle: preset.subtitle,
                            isSelected: selectedGoalPreset?.title == preset.title
                        )
                    }
                }
            }

            Spacer()

            VStack(spacing: RQSpacing.sm) {
                HStack(spacing: RQSpacing.md) {
                    RQButton(title: "Back", style: .secondary) {
                        withAnimation { currentStep = 2 }
                    }
                    RQButton(title: "Continue") {
                        withAnimation { currentStep = 4 }
                    }
                }

                if selectedGoalPreset == nil {
                    Text("You can set goals anytime from the home screen")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .padding(.horizontal, RQSpacing.screenHorizontal)
    }

    // MARK: - Step 5: How It Works

    private var howItWorksStep: some View {
        VStack(spacing: RQSpacing.xxxl) {
            Spacer()

            VStack(spacing: RQSpacing.md) {
                Text("How repIQ Works")
                    .font(RQTypography.largeTitle)
                    .foregroundColor(RQColors.accent)
            }

            VStack(spacing: RQSpacing.lg) {
                howItWorksCard(
                    step: "1",
                    icon: "figure.strengthtraining.traditional",
                    title: "Baseline Sessions",
                    description: "Your first workout for each exercise establishes a baseline. Pick a comfortable weight and focus on form. No targets yet — just log what you do."
                )

                howItWorksCard(
                    step: "2",
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Smart Targets Appear",
                    description: "Starting from your second session, repIQ generates personalized weight, rep, and RPE targets for every set based on your actual performance."
                )

                howItWorksCard(
                    step: "3",
                    icon: "arrow.up.right.circle",
                    title: "Automatic Progression",
                    description: "The app tracks your trends and adjusts. Improving? It pushes you forward. Plateauing? It adapts. Need recovery? It suggests a deload."
                )
            }

            Spacer()

            VStack(spacing: RQSpacing.sm) {
                RQButton(title: "Get Started", isLoading: isCreatingTemplate) {
                    Task { await completeOnboarding() }
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .padding(.horizontal, RQSpacing.screenHorizontal)
    }

    // MARK: - Goal Presets

    private var goalPresets: [GoalPreset] {
        switch (experienceLevel, trainingGoal) {
        case (.beginner, .buildMuscle), (.beginner, .both):
            return [
                GoalPreset(icon: "scalemass.fill", title: "Bench Press 135 lbs", subtitle: "A common first strength milestone", goalType: .weight, exerciseName: "Barbell Bench Press", targetValue: 135),
                GoalPreset(icon: "scalemass.fill", title: "Squat 185 lbs", subtitle: "Build a strong foundation", goalType: .weight, exerciseName: "Barbell Squat", targetValue: 185),
                GoalPreset(icon: "calendar", title: "Train 3x per week", subtitle: "Build the habit of consistency", goalType: .consistency, exerciseName: nil, targetValue: 3),
            ]
        case (.beginner, .getStronger):
            return [
                GoalPreset(icon: "scalemass.fill", title: "Bench Press 135 lbs", subtitle: "Your first plate on each side", goalType: .weight, exerciseName: "Barbell Bench Press", targetValue: 135),
                GoalPreset(icon: "scalemass.fill", title: "Deadlift 225 lbs", subtitle: "Two plates — a real milestone", goalType: .weight, exerciseName: "Deadlift", targetValue: 225),
                GoalPreset(icon: "calendar", title: "Train 3x per week", subtitle: "Build the habit of consistency", goalType: .consistency, exerciseName: nil, targetValue: 3),
            ]
        case (.intermediate, .buildMuscle), (.intermediate, .both):
            return [
                GoalPreset(icon: "scalemass.fill", title: "Bench Press 225 lbs", subtitle: "Two plates — a classic benchmark", goalType: .weight, exerciseName: "Barbell Bench Press", targetValue: 225),
                GoalPreset(icon: "scalemass.fill", title: "Squat 315 lbs", subtitle: "Three plates for serious legs", goalType: .weight, exerciseName: "Barbell Squat", targetValue: 315),
                GoalPreset(icon: "calendar", title: "Train 4x per week", subtitle: "Step up your frequency", goalType: .consistency, exerciseName: nil, targetValue: 4),
            ]
        case (.intermediate, .getStronger):
            return [
                GoalPreset(icon: "scalemass.fill", title: "Bench Press 225 lbs", subtitle: "Two plates on the bench", goalType: .weight, exerciseName: "Barbell Bench Press", targetValue: 225),
                GoalPreset(icon: "scalemass.fill", title: "Deadlift 405 lbs", subtitle: "Four plates — elite territory", goalType: .weight, exerciseName: "Deadlift", targetValue: 405),
                GoalPreset(icon: "calendar", title: "Train 4x per week", subtitle: "Consistency drives strength", goalType: .consistency, exerciseName: nil, targetValue: 4),
            ]
        case (.advanced, _):
            return [
                GoalPreset(icon: "scalemass.fill", title: "Bench Press 315 lbs", subtitle: "Three plates — top 1% territory", goalType: .weight, exerciseName: "Barbell Bench Press", targetValue: 315),
                GoalPreset(icon: "scalemass.fill", title: "Squat 405 lbs", subtitle: "Four plates for a dominant squat", goalType: .weight, exerciseName: "Barbell Squat", targetValue: 405),
                GoalPreset(icon: "calendar", title: "Train 5x per week", subtitle: "Maximize your training frequency", goalType: .consistency, exerciseName: nil, targetValue: 5),
            ]
        default:
            return [
                GoalPreset(icon: "scalemass.fill", title: "Bench Press 135 lbs", subtitle: "A great first milestone", goalType: .weight, exerciseName: "Barbell Bench Press", targetValue: 135),
                GoalPreset(icon: "calendar", title: "Train 3x per week", subtitle: "Build the habit of consistency", goalType: .consistency, exerciseName: nil, targetValue: 3),
            ]
        }
    }

    // MARK: - Recommended Programs

    private var recommendedPrograms: [ProgramDefinition] {
        let allPrograms = ProgramCatalog.allPrograms

        let difficulty: ProgramDifficulty = {
            switch experienceLevel {
            case .beginner: return .beginner
            case .intermediate: return .intermediate
            case .advanced, .none: return .advanced
            }
        }()

        let category: ProgramCategory? = {
            switch trainingGoal {
            case .buildMuscle: return .hypertrophy
            case .getStronger: return .strength
            case .both: return .hybrid
            case .none: return nil
            }
        }()

        var filtered = allPrograms
        if let category {
            filtered = filtered.filter { $0.category == category }
        }

        return filtered.sorted { a, b in
            let aMatch = a.difficulty == difficulty
            let bMatch = b.difficulty == difficulty
            if aMatch != bMatch { return aMatch }
            return a.daysPerWeek < b.daysPerWeek
        }
    }

    // MARK: - Actions

    private func completeOnboarding() async {
        isCreatingTemplate = true

        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }

            // Save onboarding preferences
            try await ProfileService().updateOnboarding(
                userId: userId,
                experienceLevel: experienceLevel?.rawValue,
                trainingGoal: trainingGoal?.rawValue
            )

            // Create template from selected program
            if let program = selectedProgram {
                let browserVM = ProgramBrowserViewModel()
                await browserVM.materializeProgram(program)
            }

            // Create goal from preset if selected
            if let preset = selectedGoalPreset {
                await createGoalFromPreset(preset, userId: userId)
            }

            onComplete()
        } catch {
            isCreatingTemplate = false
        }
    }

    private func createGoalFromPreset(_ preset: GoalPreset, userId: UUID) async {
        // Find the exercise ID if this is an exercise-specific goal
        var exerciseId: UUID?
        if let exerciseName = preset.exerciseName {
            let exercises: [Exercise]? = try? await supabase.from("exercises")
                .select()
                .ilike("name", pattern: exerciseName)
                .limit(1)
                .execute()
                .value
            exerciseId = exercises?.first?.id
        }

        let unit: String = {
            switch preset.goalType {
            case .weight: return "lbs"
            case .reps: return "reps"
            case .consistency: return "sessions/week"
            default: return "lbs"
            }
        }()

        _ = try? await GoalService().createGoal(
            userId: userId,
            goalType: preset.goalType,
            exerciseId: exerciseId,
            exerciseName: preset.exerciseName,
            targetValue: preset.targetValue,
            startingValue: 0,
            isEstimated1RM: false,
            unit: unit,
            targetDate: Calendar.current.date(byAdding: .day, value: 90, to: Date())
        )
    }

    // MARK: - Components

    private func onboardingOption(icon: String, title: String, subtitle: String, isSelected: Bool) -> some View {
        HStack(spacing: RQSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(isSelected ? RQColors.accent : RQColors.textTertiary)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                Text(title)
                    .font(RQTypography.headline)
                    .foregroundColor(isSelected ? RQColors.textPrimary : RQColors.textSecondary)
                Text(subtitle)
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(isSelected ? RQColors.accent : RQColors.textTertiary)
        }
        .padding(RQSpacing.lg)
        .background(isSelected ? RQColors.accent.opacity(0.1) : RQColors.surfaceSecondary)
        .cornerRadius(RQRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: RQRadius.medium)
                .stroke(isSelected ? RQColors.accent : Color.clear, lineWidth: 1)
        )
    }

    private func programCard(_ program: ProgramDefinition, isSelected: Bool) -> some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                        Text(program.name)
                            .font(RQTypography.headline)
                            .foregroundColor(RQColors.textPrimary)
                        HStack(spacing: RQSpacing.sm) {
                            Text("\(program.daysPerWeek) days/week")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textSecondary)
                            Text("\u{00B7}")
                                .foregroundColor(RQColors.textTertiary)
                            Text(program.difficulty.displayName)
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textSecondary)
                        }
                    }
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? RQColors.accent : RQColors.textTertiary)
                }

                Text(program.description)
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: RQRadius.large)
                .stroke(isSelected ? RQColors.accent : Color.clear, lineWidth: 1)
        )
    }

    private func howItWorksCard(step: String, icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: RQSpacing.lg) {
            ZStack {
                Circle()
                    .fill(RQColors.accent.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(RQColors.accent)
            }

            VStack(alignment: .leading, spacing: RQSpacing.xs) {
                Text(title)
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)

                Text(description)
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(RQSpacing.lg)
        .background(RQColors.surfaceSecondary)
        .cornerRadius(RQRadius.medium)
    }
}

// MARK: - Goal Preset Model

struct GoalPreset {
    let icon: String
    let title: String
    let subtitle: String
    let goalType: GoalType
    let exerciseName: String?
    let targetValue: Double
}

// MARK: - Onboarding Enums

enum OnboardingExperienceLevel: String, CaseIterable {
    case beginner
    case intermediate
    case advanced

    var displayName: String {
        rawValue.capitalized
    }

    var description: String {
        switch self {
        case .beginner: return "New to lifting or less than 6 months of consistent training"
        case .intermediate: return "1-3 years of consistent training with solid form"
        case .advanced: return "3+ years of serious training with established strength levels"
        }
    }

    var icon: String {
        switch self {
        case .beginner: return "figure.walk"
        case .intermediate: return "figure.strengthtraining.traditional"
        case .advanced: return "trophy.fill"
        }
    }
}

enum TrainingGoal: String, CaseIterable {
    case buildMuscle = "build_muscle"
    case getStronger = "get_stronger"
    case both

    var displayName: String {
        switch self {
        case .buildMuscle: return "Build Muscle"
        case .getStronger: return "Get Stronger"
        case .both: return "Both"
        }
    }

    var description: String {
        switch self {
        case .buildMuscle: return "Maximize muscle growth with hypertrophy-focused training"
        case .getStronger: return "Increase your 1RM on the big compound lifts"
        case .both: return "A balanced approach combining size and strength"
        }
    }

    var icon: String {
        switch self {
        case .buildMuscle: return "figure.strengthtraining.functional"
        case .getStronger: return "scalemass.fill"
        case .both: return "figure.mixed.cardio"
        }
    }
}
