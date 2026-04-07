import SwiftUI
import Supabase

struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var experienceLevel: OnboardingExperienceLevel?
    @State private var trainingGoal: TrainingGoal?
    @State private var trainingDaysPerWeek: Int?
    @State private var selectedProgram: ProgramDefinition?
    @State private var goalBuilderType: GoalType = .weight
    @State private var goalBuilderExercise: String = ""
    @State private var goalBuilderTargetText: String = ""
    @State private var goalBuilderDaysPerWeek: Int = 3
    @State private var isCreatingTemplate = false
    var onComplete: () -> Void

    private let totalSteps = 6

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
                    frequencyStep.tag(2)
                    programStep.tag(3)
                    goalBuilderStep.tag(4)
                    howItWorksStep.tag(5)
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

    // MARK: - Step 3: Training Frequency

    private var frequencyStep: some View {
        VStack(spacing: RQSpacing.xxxl) {
            Spacer()

            VStack(spacing: RQSpacing.md) {
                Text("How Often Can You Train?")
                    .font(RQTypography.largeTitle)
                    .foregroundColor(RQColors.accent)
                    .multilineTextAlignment(.center)

                Text("We'll match programs to your schedule")
                    .font(RQTypography.subheadline)
                    .foregroundColor(RQColors.textSecondary)
            }

            VStack(spacing: RQSpacing.md) {
                ForEach(trainingFrequencyOptions, id: \.days) { option in
                    Button {
                        trainingDaysPerWeek = option.days
                    } label: {
                        onboardingOption(
                            icon: option.icon,
                            title: option.title,
                            subtitle: option.subtitle,
                            isSelected: trainingDaysPerWeek == option.days
                        )
                    }
                }
            }

            Spacer()

            HStack(spacing: RQSpacing.md) {
                RQButton(title: "Back", style: .secondary) {
                    withAnimation { currentStep = 1 }
                }
                RQButton(title: "Continue", isDisabled: trainingDaysPerWeek == nil) {
                    withAnimation { currentStep = 3 }
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .padding(.horizontal, RQSpacing.screenHorizontal)
    }

    // MARK: - Step 4: Program Selection

    private var programStep: some View {
        VStack(spacing: RQSpacing.lg) {
            VStack(spacing: RQSpacing.md) {
                Text("Pick a Program")
                    .font(RQTypography.largeTitle)
                    .foregroundColor(RQColors.accent)
                    .padding(.top, RQSpacing.xxxl)

                Text("Sorted by best fit for your schedule and level")
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
                        withAnimation { currentStep = 2 }
                    }
                    RQButton(title: "Continue", isDisabled: selectedProgram == nil) {
                        withAnimation { currentStep = 4 }
                    }
                }

                Button {
                    withAnimation { currentStep = 4 }
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

    // MARK: - Step 5: Goal Builder

    private var goalBuilderStep: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xl) {
                // Header
                VStack(spacing: RQSpacing.md) {
                    Text("Set a Goal")
                        .font(RQTypography.largeTitle)
                        .foregroundColor(RQColors.accent)
                        .padding(.top, RQSpacing.xxxl)

                    Text("Give yourself something to chase — you can adjust it anytime")
                        .font(RQTypography.subheadline)
                        .foregroundColor(RQColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Quick example chips
                VStack(alignment: .leading, spacing: RQSpacing.sm) {
                    Text("QUICK EXAMPLES")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(RQColors.textTertiary)
                        .kerning(1)
                        .padding(.horizontal, 2)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: RQSpacing.sm) {
                            ForEach(goalPresets, id: \.title) { preset in
                                Button {
                                    applyPreset(preset)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: preset.icon)
                                            .font(.system(size: 11, weight: .semibold))
                                        Text(preset.title)
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundColor(RQColors.accent)
                                    .padding(.horizontal, RQSpacing.md)
                                    .padding(.vertical, RQSpacing.sm)
                                    .background(RQColors.accent.opacity(0.12))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(RQColors.accent.opacity(0.3), lineWidth: 1))
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                // Goal builder form
                VStack(alignment: .leading, spacing: RQSpacing.lg) {
                    // Goal type selector
                    HStack(spacing: RQSpacing.sm) {
                        goalTypeButton(type: .weight, label: "Lift a Weight", icon: "scalemass.fill")
                        goalTypeButton(type: .consistency, label: "Stay Consistent", icon: "calendar")
                    }

                    // Fields
                    if goalBuilderType == .weight {
                        VStack(alignment: .leading, spacing: RQSpacing.sm) {
                            Text("EXERCISE")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(RQColors.textTertiary)
                                .kerning(1)

                            TextField("e.g. Barbell Bench Press", text: $goalBuilderExercise)
                                .font(RQTypography.body)
                                .foregroundColor(RQColors.textPrimary)
                                .padding(RQSpacing.md)
                                .background(RQColors.surfaceTertiary)
                                .cornerRadius(RQRadius.small)
                        }

                        VStack(alignment: .leading, spacing: RQSpacing.sm) {
                            Text("TARGET WEIGHT")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(RQColors.textTertiary)
                                .kerning(1)

                            HStack(spacing: RQSpacing.sm) {
                                TextField("e.g. 225", text: $goalBuilderTargetText)
                                    .font(RQTypography.numbersSmall)
                                    .foregroundColor(RQColors.textPrimary)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.center)
                                    .padding(RQSpacing.md)
                                    .background(RQColors.surfaceTertiary)
                                    .cornerRadius(RQRadius.small)
                                    .frame(width: 100)

                                Text("lbs")
                                    .font(RQTypography.body)
                                    .foregroundColor(RQColors.textSecondary)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: RQSpacing.sm) {
                            Text("SESSIONS PER WEEK")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(RQColors.textTertiary)
                                .kerning(1)

                            HStack(spacing: RQSpacing.sm) {
                                ForEach(2...6, id: \.self) { days in
                                    Button {
                                        goalBuilderDaysPerWeek = days
                                    } label: {
                                        VStack(spacing: 2) {
                                            Text("\(days)")
                                                .font(RQTypography.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(goalBuilderDaysPerWeek == days ? RQColors.accent : RQColors.textSecondary)
                                            Text("days")
                                                .font(.system(size: 10))
                                                .foregroundColor(RQColors.textTertiary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, RQSpacing.sm)
                                        .background(goalBuilderDaysPerWeek == days ? RQColors.accent.opacity(0.15) : RQColors.surfaceTertiary)
                                        .cornerRadius(RQRadius.small)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: RQRadius.small)
                                                .stroke(goalBuilderDaysPerWeek == days ? RQColors.accent : Color.clear, lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(RQSpacing.lg)
                .background(RQColors.surfaceSecondary)
                .cornerRadius(RQRadius.medium)

                Spacer(minLength: 80)
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: RQSpacing.sm) {
                HStack(spacing: RQSpacing.md) {
                    RQButton(title: "Back", style: .secondary) {
                        withAnimation { currentStep = 3 }
                    }
                    RQButton(title: goalBuilderHasContent ? "Set Goal" : "Continue") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        withAnimation { currentStep = 5 }
                    }
                }

                if !goalBuilderHasContent {
                    Text("You can set goals anytime from the home screen")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.top, RQSpacing.sm)
            .padding(.bottom, RQSpacing.xl)
            .background(RQColors.background)
        }
    }

    // MARK: - Step 6: How It Works

    private var howItWorksStep: some View {
        ScrollView {
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
                    description: "Each exercise in your program starts without targets. Your first session per exercise is a baseline — use a weight you can control and focus on form. On a typical weekly program this means your first full week feels like an introduction. From your second session with each exercise onward, personalized targets kick in."
                )

                howItWorksCard(
                    step: "2",
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Smart Targets Appear",
                    description: "From your second session per exercise, repIQ generates weight, rep, and RPE targets. RPE (Rate of Perceived Exertion) is a 1–10 effort scale — RPE 8 means roughly 2 reps left before failure. A target might read: 185 lbs × 8 reps @ RPE 8. Everything is calibrated to your actual performance, not generic charts."
                )

                howItWorksCard(
                    step: "3",
                    icon: "arrow.up.right.circle",
                    title: "Automatic Progression",
                    description: "The engine adapts to your goal. For hypertrophy, it adds reps first and bumps the weight once you hit your rep ceiling — a double-progression model. For strength, it drives weight up each week using ramping sets that increase load and intensity. If fatigue builds in your RPE data or performance drops, it schedules a deload week so you recover before pushing harder."
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
        .onAppear {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    // MARK: - Goal Presets (used as example chips in builder)

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

        let targetDays = trainingDaysPerWeek ?? 4

        return filtered.sorted { a, b in
            // 1. Exact frequency match first
            let aFreqMatch = a.daysPerWeek == targetDays
            let bFreqMatch = b.daysPerWeek == targetDays
            if aFreqMatch != bFreqMatch { return aFreqMatch }

            // 2. Difficulty match second
            let aDiffMatch = a.difficulty == difficulty
            let bDiffMatch = b.difficulty == difficulty
            if aDiffMatch != bDiffMatch { return aDiffMatch }

            // 3. Closest frequency
            let aDist = abs(a.daysPerWeek - targetDays)
            let bDist = abs(b.daysPerWeek - targetDays)
            if aDist != bDist { return aDist < bDist }

            return a.daysPerWeek < b.daysPerWeek
        }
    }

    // MARK: - Training Frequency Options

    private let trainingFrequencyOptions: [(days: Int, icon: String, title: String, subtitle: String)] = [
        (3, "3.circle.fill", "3 Days/Week", "Classic split — great for building the habit with plenty of recovery"),
        (4, "4.circle.fill", "4 Days/Week", "Upper/lower or push/pull — solid balance of volume and rest"),
        (5, "5.circle.fill", "5 Days/Week", "High frequency training — for those ready to commit"),
        (6, "6.circle.fill", "6 Days/Week", "Push/pull/legs twice per week — maximum volume for advanced athletes"),
    ]

    // MARK: - Goal Builder Helpers

    private var goalBuilderHasContent: Bool {
        switch goalBuilderType {
        case .weight:
            let trimmed = goalBuilderExercise.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && (Double(goalBuilderTargetText) ?? 0) > 0
        case .consistency:
            return goalBuilderDaysPerWeek > 0
        default:
            return false
        }
    }

    private func applyPreset(_ preset: GoalPreset) {
        goalBuilderType = preset.goalType
        if preset.goalType == .weight {
            goalBuilderExercise = preset.exerciseName ?? ""
            goalBuilderTargetText = String(Int(preset.targetValue))
        } else if preset.goalType == .consistency {
            goalBuilderDaysPerWeek = Int(preset.targetValue)
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

            // Create goal from builder if filled in
            await createGoalFromBuilder(userId: userId)

            onComplete()
        } catch {
            isCreatingTemplate = false
        }
    }

    private func createGoalFromBuilder(userId: UUID) async {
        guard goalBuilderHasContent else { return }

        switch goalBuilderType {
        case .weight:
            guard let targetValue = Double(goalBuilderTargetText), targetValue > 0 else { return }
            let exerciseName = goalBuilderExercise.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !exerciseName.isEmpty else { return }

            var exerciseId: UUID?
            let exercises: [Exercise]? = try? await supabase.from("exercises")
                .select()
                .ilike("name", pattern: exerciseName)
                .limit(1)
                .execute()
                .value
            exerciseId = exercises?.first?.id

            _ = try? await GoalService().createGoal(
                userId: userId,
                goalType: .weight,
                exerciseId: exerciseId,
                exerciseName: exerciseName,
                targetValue: targetValue,
                startingValue: 0,
                isEstimated1RM: false,
                unit: "lbs",
                targetDate: Calendar.current.date(byAdding: .day, value: 90, to: Date())
            )

        case .consistency:
            _ = try? await GoalService().createGoal(
                userId: userId,
                goalType: .consistency,
                exerciseId: nil,
                exerciseName: nil,
                targetValue: Double(goalBuilderDaysPerWeek),
                startingValue: 0,
                isEstimated1RM: false,
                unit: "sessions/week",
                targetDate: Calendar.current.date(byAdding: .day, value: 90, to: Date())
            )

        default:
            break
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func goalTypeButton(type: GoalType, label: String, icon: String) -> some View {
        let isSelected = goalBuilderType == type
        Button {
            goalBuilderType = type
        } label: {
            VStack(spacing: RQSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? RQColors.accent : RQColors.textTertiary)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? RQColors.textPrimary : RQColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(RQSpacing.md)
            .background(isSelected ? RQColors.accent.opacity(0.1) : RQColors.surfaceTertiary)
            .cornerRadius(RQRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: RQRadius.small)
                    .stroke(isSelected ? RQColors.accent : Color.clear, lineWidth: 1)
            )
        }
    }

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
                                .foregroundColor(program.daysPerWeek == trainingDaysPerWeek ? RQColors.accent : RQColors.textSecondary)
                            Text("\u{00B7}")
                                .foregroundColor(RQColors.textTertiary)
                            Text(program.difficulty.displayName)
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textSecondary)
                            if program.daysPerWeek == trainingDaysPerWeek {
                                Text("· Best fit")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.accent)
                            }
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
