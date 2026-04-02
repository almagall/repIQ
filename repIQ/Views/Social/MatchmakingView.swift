import SwiftUI

/// Smart matchmaking: find lifters with similar training style, experience, and habits.
struct MatchmakingView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var matches: [MatchmakingResult] = []
    @State private var isLoading = false
    @State private var showingPreferences = false

    // Preference editing
    @State private var selectedStyle: TrainingStyle?
    @State private var selectedLevel: ExperienceLevel?
    @State private var selectedFrequency: Int = 4
    @State private var gymName: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xl) {
                // Preferences card
                preferencesCard

                // Coaching nudges
                if !viewModel.coachingNudges.isEmpty {
                    nudgesSection
                }

                // Match results
                if isLoading {
                    ProgressView()
                        .tint(RQColors.accent)
                        .padding(.top, RQSpacing.xxxl)
                } else if matches.isEmpty {
                    emptyState
                } else {
                    matchResults
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.lg)
        }
        .background(RQColors.background)
        .navigationTitle("Find Training Partners")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadCurrentPreferences()
            await findMatches()
        }
        .sheet(isPresented: $showingPreferences) {
            preferencesSheet
        }
    }

    // MARK: - Preferences Card

    private var preferencesCard: some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.md) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16))
                        .foregroundColor(RQColors.accent)
                    Text("Your Training Profile")
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)
                    Spacer()
                    Button("Edit") {
                        showingPreferences = true
                    }
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.accent)
                }

                HStack(spacing: RQSpacing.lg) {
                    if let style = selectedStyle {
                        prefPill(icon: style.icon, label: style.displayName)
                    }
                    if let level = selectedLevel {
                        prefPill(icon: "chart.bar.fill", label: level.displayName)
                    }
                    prefPill(icon: "calendar", label: "\(selectedFrequency)x/week")
                }

                if !gymName.isEmpty {
                    HStack(spacing: RQSpacing.xs) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(RQColors.textTertiary)
                        Text(gymName)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textSecondary)
                    }
                }
            }
        }
    }

    private func prefPill(icon: String, label: String) -> some View {
        HStack(spacing: RQSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(RQTypography.caption)
        }
        .foregroundColor(RQColors.accent)
        .padding(.horizontal, RQSpacing.sm)
        .padding(.vertical, RQSpacing.xxs)
        .background(RQColors.accent.opacity(0.15))
        .cornerRadius(RQRadius.small)
    }

    // MARK: - Nudges Section

    private var nudgesSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            Text("COACHING INSIGHTS")
                .font(RQTypography.label)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(RQColors.textSecondary)

            ForEach(viewModel.coachingNudges) { nudge in
                nudgeCard(nudge)
            }
        }
    }

    private func nudgeCard(_ nudge: CoachingNudge) -> some View {
        let color = nudgeColor(nudge.accentColor)
        return RQCard {
            HStack(alignment: .top, spacing: RQSpacing.md) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 3)

                Image(systemName: nudge.icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: RQSpacing.xs) {
                    Text(nudge.title)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)
                    Text(nudge.message)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textSecondary)

                    if let context = nudge.socialContext {
                        Text(context)
                            .font(RQTypography.label)
                            .foregroundColor(color)
                            .padding(.top, RQSpacing.xxs)
                    }
                }

                Spacer()
            }
        }
    }

    private func nudgeColor(_ name: String) -> Color {
        switch name {
        case "accent": return RQColors.accent
        case "success": return RQColors.success
        case "warning": return RQColors.warning
        case "error": return RQColors.error
        default: return RQColors.accent
        }
    }

    // MARK: - Match Results

    private var matchResults: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            Text("SUGGESTED PARTNERS")
                .font(RQTypography.label)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(RQColors.textSecondary)

            ForEach(matches) { match in
                matchCard(match)
            }
        }
    }

    private func matchCard(_ match: MatchmakingResult) -> some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.md) {
                HStack(spacing: RQSpacing.md) {
                    // Avatar
                    Circle()
                        .fill(RQColors.accent.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(String((match.profile.username ?? "?").prefix(1)).uppercased())
                                .font(RQTypography.headline)
                                .foregroundColor(RQColors.accent)
                        )

                    VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                        Text(match.profile.username ?? "User")
                            .font(RQTypography.headline)
                            .foregroundColor(RQColors.textPrimary)
                    }

                    Spacer()

                    // Compatibility score
                    VStack(spacing: RQSpacing.xxs) {
                        Text("\(Int(match.compatibilityScore * 100))%")
                            .font(RQTypography.numbersSmall)
                            .foregroundColor(RQColors.accent)
                        Text("Match")
                            .font(RQTypography.label)
                            .foregroundColor(RQColors.textTertiary)
                    }
                }

                // Match reasons
                HStack(spacing: RQSpacing.sm) {
                    ForEach(match.reasons.prefix(3), id: \.self) { reason in
                        Text(reason)
                            .font(RQTypography.label)
                            .foregroundColor(RQColors.textSecondary)
                            .padding(.horizontal, RQSpacing.sm)
                            .padding(.vertical, RQSpacing.xxs)
                            .background(RQColors.surfaceTertiary)
                            .cornerRadius(RQRadius.small)
                    }
                }

                // Action
                Button {
                    Task {
                        await viewModel.sendFriendRequest(to: match.profile.id)
                    }
                } label: {
                    Text("Send Friend Request")
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(RQColors.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RQSpacing.sm)
                        .background(RQColors.accent)
                        .cornerRadius(RQRadius.medium)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: RQSpacing.lg) {
            Image(systemName: "person.2.wave.2")
                .font(.system(size: 40))
                .foregroundColor(RQColors.textTertiary)
            Text("No matches yet")
                .font(RQTypography.headline)
                .foregroundColor(RQColors.textSecondary)
            Text("Set your training preferences to find compatible training partners.")
                .font(RQTypography.footnote)
                .foregroundColor(RQColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, RQSpacing.xxxl)
    }

    // MARK: - Preferences Sheet

    private var preferencesSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RQSpacing.xl) {
                    // Training style
                    VStack(alignment: .leading, spacing: RQSpacing.sm) {
                        Text("TRAINING STYLE")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: RQSpacing.sm) {
                            ForEach(TrainingStyle.allCases, id: \.self) { style in
                                Button {
                                    selectedStyle = style
                                } label: {
                                    HStack(spacing: RQSpacing.sm) {
                                        Image(systemName: style.icon)
                                            .font(.system(size: 14))
                                        Text(style.displayName)
                                            .font(RQTypography.caption)
                                    }
                                    .foregroundColor(selectedStyle == style ? RQColors.background : RQColors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, RQSpacing.md)
                                    .background(selectedStyle == style ? RQColors.accent : RQColors.surfacePrimary)
                                    .cornerRadius(RQRadius.medium)
                                }
                            }
                        }
                    }

                    // Experience level
                    VStack(alignment: .leading, spacing: RQSpacing.sm) {
                        Text("EXPERIENCE LEVEL")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)

                        ForEach(ExperienceLevel.allCases, id: \.self) { level in
                            Button {
                                selectedLevel = level
                            } label: {
                                HStack {
                                    Text(level.displayName)
                                        .font(RQTypography.body)
                                    Spacer()
                                    if selectedLevel == level {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(RQColors.accent)
                                    }
                                }
                                .foregroundColor(RQColors.textPrimary)
                                .padding(RQSpacing.md)
                                .background(selectedLevel == level ? RQColors.accent.opacity(0.1) : RQColors.surfacePrimary)
                                .cornerRadius(RQRadius.medium)
                            }
                        }
                    }

                    // Frequency
                    VStack(alignment: .leading, spacing: RQSpacing.sm) {
                        Text("TRAINING FREQUENCY")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)

                        HStack {
                            Text("\(selectedFrequency) days/week")
                                .font(RQTypography.headline)
                                .foregroundColor(RQColors.textPrimary)
                            Spacer()
                            Stepper("", value: $selectedFrequency, in: 1...7)
                                .labelsHidden()
                        }
                        .padding(RQSpacing.md)
                        .background(RQColors.surfacePrimary)
                        .cornerRadius(RQRadius.medium)
                    }

                    // Gym
                    VStack(alignment: .leading, spacing: RQSpacing.sm) {
                        Text("YOUR GYM (OPTIONAL)")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)

                        TextField("e.g. Equinox SoHo", text: $gymName)
                            .font(RQTypography.body)
                            .foregroundColor(RQColors.textPrimary)
                            .padding(RQSpacing.md)
                            .background(RQColors.surfacePrimary)
                            .cornerRadius(RQRadius.medium)
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.vertical, RQSpacing.lg)
            }
            .background(RQColors.background)
            .navigationTitle("Training Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showingPreferences = false
                    }
                    .foregroundColor(RQColors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            await savePreferences()
                            showingPreferences = false
                            await findMatches()
                        }
                    }
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.accent)
                }
            }
        }
    }

    // MARK: - Actions

    private func loadCurrentPreferences() {
        guard let profile = viewModel.socialProfile else { return }
        if let style = profile.trainingStyle {
            selectedStyle = TrainingStyle(rawValue: style)
        }
        if let level = profile.experienceLevel {
            selectedLevel = ExperienceLevel(rawValue: level)
        }
        selectedFrequency = profile.preferredFrequency ?? 4
        gymName = profile.gymName ?? ""
    }

    private func findMatches() async {
        guard let userId = viewModel.currentUserId else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let service = MatchmakingService()
            matches = try await service.findMatches(
                userId: userId,
                existingFriendIds: viewModel.friendIds
            )
        } catch {
            // Silently fail
        }
    }

    private func savePreferences() async {
        guard let userId = viewModel.currentUserId else { return }

        do {
            let service = MatchmakingService()
            try await service.updatePreferences(
                userId: userId,
                trainingStyle: selectedStyle,
                experienceLevel: selectedLevel,
                preferredFrequency: selectedFrequency,
                gymName: gymName.isEmpty ? nil : gymName
            )

            // Update local profile
            viewModel.socialProfile?.trainingStyle = selectedStyle?.rawValue
            viewModel.socialProfile?.experienceLevel = selectedLevel?.rawValue
            viewModel.socialProfile?.preferredFrequency = selectedFrequency
            viewModel.socialProfile?.gymName = gymName.isEmpty ? nil : gymName
        } catch {
            // Silently fail
        }
    }
}
