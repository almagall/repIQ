import SwiftUI

struct WorkoutSummaryView: View {
    let summary: WorkoutSummaryData
    let onDismiss: () -> Void
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    @State private var selectedTab = 0 // 0 = Summary, 1 = Report

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary / Report toggle
                Picker("View", selection: $selectedTab) {
                    Text("Summary").tag(0)
                    Text("Report").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.vertical, RQSpacing.md)

                if selectedTab == 0 {
                    summaryView
                } else {
                    reportView
                }
            }
            .background(RQColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        generateShareImage()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundColor(RQColors.accent)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.accent)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = shareImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }

    // MARK: - Summary View (Shareable Card)

    private var summaryView: some View {
        ScrollView {
            VStack(spacing: RQSpacing.lg) {
                // Share card displayed inline
                WorkoutShareCard(summary: summary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: RQColors.accent.opacity(0.1), radius: 12, y: 4)

                // Share button
                Button {
                    generateShareImage()
                } label: {
                    HStack(spacing: RQSpacing.sm) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                        Text("Share Workout")
                            .font(RQTypography.headline)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RQSpacing.md)
                    .background(RQColors.accent)
                    .cornerRadius(RQRadius.medium)
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
            }
            .padding(.top, RQSpacing.md)
            .padding(.bottom, RQSpacing.xxxl)
        }
    }

    // MARK: - Report View (Detailed Breakdown)

    private var reportView: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xl) {
                // Header
                VStack(spacing: RQSpacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(RQColors.success)

                    Text("Workout Complete!")
                        .font(RQTypography.title1)
                        .foregroundColor(RQColors.textPrimary)
                }
                .padding(.top, RQSpacing.xl)

                // Stats row
                HStack(spacing: RQSpacing.lg) {
                    statCard(
                        label: "Duration",
                        value: formattedDuration,
                        icon: "clock"
                    )
                    statCard(
                        label: "Sets",
                        value: "\(summary.totalSets)",
                        icon: "number"
                    )
                    statCard(
                        label: "Volume",
                        value: formattedVolume,
                        icon: "scalemass"
                    )
                }

                // Streak
                if summary.currentStreak > 0 {
                    gamificationSection
                }

                // First workout baseline message (streak of 1 = first ever workout)
                if summary.currentStreak == 1 {
                    baselineRecordedCard
                }

                // PR celebrations (exclude volume)
                let displayPRs = summary.newPRs.filter { $0.recordType != .volume }
                if !displayPRs.isEmpty {
                    VStack(alignment: .leading, spacing: RQSpacing.md) {
                        Text("New Personal Records")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)

                        ForEach(displayPRs) { pr in
                            prCard(pr)
                        }
                    }
                }

                // Exercise breakdown
                if !summary.exerciseSummaries.isEmpty {
                    VStack(alignment: .leading, spacing: RQSpacing.md) {
                        Text("Exercise Breakdown")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)

                        ForEach(summary.exerciseSummaries) { exercise in
                            exerciseCard(exercise)
                        }
                    }
                }

                // Next session progression
                if !summary.progressionDecisions.isEmpty {
                    VStack(alignment: .leading, spacing: RQSpacing.md) {
                        Text("Next Session")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)

                        ForEach(summary.progressionDecisions) { progression in
                            progressionCard(progression)
                        }
                    }
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.bottom, RQSpacing.xxxl)
        }
    }

    // MARK: - Gamification

    private var gamificationSection: some View {
        RQCard {
            VStack(spacing: RQSpacing.sm) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 20))
                    .foregroundColor(RQColors.warning)
                Text("\(summary.currentStreak)")
                    .font(RQTypography.numbers)
                    .foregroundColor(RQColors.warning)
                Text("Day Streak")
                    .font(RQTypography.label)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(RQColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Baseline Recorded

    private var baselineRecordedCard: some View {
        RQCard {
            HStack(alignment: .top, spacing: RQSpacing.md) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(RQColors.accent)

                VStack(alignment: .leading, spacing: RQSpacing.xs) {
                    Text("Baseline Recorded")
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.accent)

                    let exerciseCount = summary.exerciseSummaries.count
                    Text("The app now knows your starting point for \(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s"). Next time, you will see personalized targets based on today's performance.")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Components

    private func statCard(label: String, value: String, icon: String) -> some View {
        RQCard {
            VStack(spacing: RQSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(RQColors.accent)

                Text(value)
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)

                Text(label)
                    .font(RQTypography.label)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(RQColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func exerciseCard(_ exercise: WorkoutSummaryData.ExerciseSummary) -> some View {
        RQCard {
            HStack {
                RoundedRectangle(cornerRadius: 1)
                    .fill(exercise.trainingMode == .hypertrophy ? RQColors.hypertrophy : RQColors.strength)
                    .frame(width: 3, height: 40)

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(exercise.name)
                        .font(RQTypography.body)
                        .foregroundColor(RQColors.textPrimary)

                    HStack(spacing: RQSpacing.sm) {
                        Text("\(exercise.setsCompleted) sets")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textSecondary)

                        if exercise.topWeight > 0 {
                            Text("·")
                                .foregroundColor(RQColors.textTertiary)
                            Text("Top: \(formatWeight(exercise.topWeight)) × \(exercise.topReps)")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textSecondary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: RQSpacing.xxs) {
                    Text(formatVolume(exercise.totalVolume))
                        .font(RQTypography.numbersSmall)
                        .foregroundColor(RQColors.accent)
                    Text("volume")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }
            }
        }
    }

    private func prCard(_ pr: PRSummary) -> some View {
        RQCard {
            HStack(spacing: RQSpacing.md) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 20))
                    .foregroundColor(RQColors.warning)

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(pr.exerciseName)
                        .font(RQTypography.body)
                        .foregroundColor(RQColors.textPrimary)

                    Text(pr.recordType.displayName)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textSecondary)
                }

                Spacer()

                Text(formatPRValue(pr.value, type: pr.recordType))
                    .font(RQTypography.numbersSmall)
                    .foregroundColor(RQColors.warning)
            }
        }
    }

    private func progressionCard(_ progression: ProgressionSummary) -> some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                Text(progression.exerciseName)
                    .font(RQTypography.body)
                    .foregroundColor(RQColors.textPrimary)

                HStack(spacing: RQSpacing.sm) {
                    Image(systemName: decisionIcon(progression.decision))
                        .font(.system(size: 12))
                        .foregroundColor(decisionColor(progression.decision))

                    Text(progression.decision.displayName)
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(decisionColor(progression.decision))

                    Text("→")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)

                    Text("\(formatWeight(progression.targetWeight)) lbs for \(progression.targetReps) reps")
                        .font(RQTypography.numbersSmall)
                        .foregroundColor(RQColors.textPrimary)
                }

                Text(progression.reasoning)
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textSecondary)
            }
        }
    }

    private func decisionIcon(_ decision: ProgressionDecision) -> String {
        switch decision {
        case .increaseWeight: return "arrow.up.circle.fill"
        case .increaseReps: return "arrow.up.right.circle.fill"
        case .maintain: return "arrow.right.circle.fill"
        case .deload, .deloadVolume: return "arrow.down.circle.fill"
        }
    }

    private func decisionColor(_ decision: ProgressionDecision) -> Color {
        switch decision {
        case .increaseWeight: return RQColors.success
        case .increaseReps: return RQColors.success
        case .maintain: return RQColors.warning
        case .deload, .deloadVolume: return RQColors.error
        }
    }

    private func formatPRValue(_ value: Double, type: RecordType) -> String {
        switch type {
        case .weight:
            return "\(formatWeight(value)) lbs"
        case .reps:
            return "\(Int(value)) reps"
        case .volume:
            return formatVolume(value)
        case .estimated1rm:
            return "\(formatWeight(value)) lbs"
        }
    }

    // MARK: - Formatting

    private var formattedDuration: String {
        let hours = summary.duration / 3600
        let minutes = (summary.duration % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private var formattedVolume: String {
        formatVolume(summary.totalVolume)
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }

    // MARK: - Share Image

    private func generateShareImage() {
        let card = WorkoutShareCard(summary: summary)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2.0
        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
