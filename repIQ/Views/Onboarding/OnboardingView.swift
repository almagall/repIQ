import SwiftUI
import Supabase

struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var experienceLevel: OnboardingExperienceLevel?
    @State private var trainingGoal: TrainingGoal?
    @State private var selectedProgram: ProgramDefinition?
    @State private var isCreatingTemplate = false
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            RQColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: RQSpacing.sm) {
                    ForEach(0..<3) { step in
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
                RQButton(title: "Get Started", isLoading: isCreatingTemplate, isDisabled: selectedProgram == nil) {
                    Task { await completeOnboarding() }
                }

                Button {
                    Task { await skipProgram() }
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

        // Filter by goal category first, then sort by difficulty match
        var filtered = allPrograms
        if let category {
            filtered = filtered.filter { $0.category == category }
        }

        // Sort: exact difficulty match first, then close matches
        return filtered.sorted { a, b in
            let aMatch = a.difficulty == difficulty
            let bMatch = b.difficulty == difficulty
            if aMatch != bMatch { return aMatch }
            return a.daysPerWeek < b.daysPerWeek
        }
    }

    // MARK: - Actions

    private func completeOnboarding() async {
        guard let program = selectedProgram else { return }
        isCreatingTemplate = true

        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }

            // Save onboarding preferences
            try await ProfileService().updateOnboarding(
                userId: userId,
                experienceLevel: experienceLevel?.rawValue,
                trainingGoal: trainingGoal?.rawValue
            )

            // Create template from selected program using existing materialize flow
            let browserVM = ProgramBrowserViewModel()
            await browserVM.materializeProgram(program)

            onComplete()
        } catch {
            isCreatingTemplate = false
        }
    }

    private func skipProgram() async {
        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            try await ProfileService().updateOnboarding(
                userId: userId,
                experienceLevel: experienceLevel?.rawValue,
                trainingGoal: trainingGoal?.rawValue
            )
        } catch {}
        onComplete()
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
