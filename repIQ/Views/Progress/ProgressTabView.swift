import SwiftUI
import Charts

struct ProgressTabView: View {
    @State private var viewModel = ProgressDashboardViewModel()
    @State private var showExercisePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading && viewModel.sessions.isEmpty {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if viewModel.sessions.isEmpty {
                    EmptyStateView(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "No Progress Data",
                        message: "Complete your first workout to start tracking your progress and PRs."
                    )
                } else {
                    VStack(spacing: RQSpacing.xl) {
                        // 1. Streak Banner — emotional hook
                        streakBanner

                        // 2. Overview Stats Grid — quick health check
                        overviewStatsGrid

                        // 3. Weekly Volume Chart — primary trend
                        volumeChartSection

                        // 4. Smart Insights — prescriptive advice (high value)
                        if !viewModel.insights.isEmpty {
                            insightsSection
                        }

                        // 5. Recent PRs — reward/celebration
                        if !viewModel.recentPRs.isEmpty {
                            recentPRsSection
                        }

                        // 6. Milestones — gamification, next goals
                        if !viewModel.milestones.isEmpty {
                            milestonesSection
                        }

                        // 7. Muscle Balance — with fractional volume toggle
                        if !viewModel.activeMuscleDistribution.isEmpty {
                            muscleBalanceSection
                        }

                        // 8. Training Quality — effective reps breakdown
                        if !viewModel.effectiveRepsSummary.isEmpty {
                            trainingQualitySection
                        }

                        // 9. Training Frequency Heatmap
                        if !viewModel.frequencyData.isEmpty {
                            frequencyHeatmapSection
                        }

                        // 10. Exercise Progress — drill-down entry
                        exerciseProgressButton

                        // 11. Workout History — reference
                        workoutHistorySection
                    }
                    .padding(.horizontal, RQSpacing.screenHorizontal)
                    .padding(.top, RQSpacing.lg)
                    .padding(.bottom, RQSpacing.xxxl)
                }
            }
            .background(RQColors.background)
            .navigationTitle("Progress")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: UUID.self) { sessionId in
                SessionDetailView(viewModel: viewModel, sessionId: sessionId)
            }
            .navigationDestination(isPresented: $showExercisePicker) {
                ExercisePickerProgressView()
            }
            .task {
                await viewModel.loadDashboard()
            }
            .refreshable {
                await viewModel.loadDashboard()
            }
        }
    }

    // MARK: - 1. Streak Banner

    private var streakBanner: some View {
        RQCard {
            HStack {
                HStack(spacing: RQSpacing.md) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 28))
                        .foregroundColor(streakColor)

                    VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                        if let streak = viewModel.streakData, streak.currentStreak > 0 {
                            Text("\(streak.currentStreak) DAY STREAK")
                                .font(RQTypography.numbers)
                                .foregroundColor(RQColors.textPrimary)
                        } else {
                            Text("START YOUR STREAK")
                                .font(RQTypography.headline)
                                .foregroundColor(RQColors.textSecondary)
                        }

                        if let streak = viewModel.streakData, streak.bestStreak > 0 {
                            Text("Best: \(streak.bestStreak) days")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }
                    }
                }

                Spacer()

                if let streak = viewModel.streakData, streak.currentStreak >= 7 {
                    Text("\(streak.currentStreak)")
                        .font(RQTypography.title1)
                        .foregroundColor(RQColors.accent.opacity(0.2))
                }
            }
        }
    }

    private var streakColor: Color {
        guard let streak = viewModel.streakData else { return RQColors.textTertiary }
        if streak.currentStreak >= 14 { return RQColors.warning }
        if streak.currentStreak >= 7 { return RQColors.accent }
        if streak.currentStreak >= 3 { return RQColors.success }
        if streak.currentStreak > 0 { return RQColors.textSecondary }
        return RQColors.textTertiary
    }

    // MARK: - 2. Overview Stats Grid

    private var overviewStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: RQSpacing.md) {
            overviewStatCard(
                label: "WEEKLY VOLUME",
                value: formatVolumeCompact(viewModel.weeklyVolume),
                icon: "scalemass.fill",
                color: RQColors.accent
            )
            overviewStatCard(
                label: "SESSIONS",
                value: "\(viewModel.weeklySessionCount)",
                icon: "figure.strengthtraining.traditional",
                color: RQColors.accent
            )
            overviewStatCard(
                label: "TOTAL VOLUME",
                value: formatVolumeCompact(viewModel.totalVolume),
                icon: "trophy.fill",
                color: RQColors.accent
            )
            overviewStatCard(
                label: "PERSONAL RECORDS",
                value: "\(viewModel.totalPRCount)",
                icon: "star.fill",
                color: RQColors.warning
            )
        }
    }

    private func overviewStatCard(label: String, value: String, icon: String, color: Color) -> some View {
        RQCard {
            VStack(spacing: RQSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)

                Text(value)
                    .font(RQTypography.numbers)
                    .foregroundColor(RQColors.textPrimary)

                Text(label)
                    .font(RQTypography.label)
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(RQColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 3. Weekly Volume Chart

    private var volumeChartSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeader("VOLUME TREND")

            RQCard {
                VStack(alignment: .leading, spacing: RQSpacing.md) {
                    if viewModel.volumeTrend.contains(where: { $0.totalVolume > 0 }) {
                        Chart(viewModel.volumeTrend) { week in
                            BarMark(
                                x: .value("Week", week.weekStart, unit: .weekOfYear),
                                y: .value("Volume", week.totalVolume)
                            )
                            .foregroundStyle(isCurrentWeek(week.weekStart) ? RQColors.accent : RQColors.textTertiary)
                            .cornerRadius(RQRadius.small)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
                                AxisValueLabel {
                                    if let date = value.as(Date.self) {
                                        Text(shortDateLabel(date))
                                            .font(RQTypography.label)
                                            .foregroundStyle(RQColors.textTertiary)
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(RQColors.chartGrid)
                                AxisValueLabel {
                                    if let val = value.as(Double.self) {
                                        Text(formatVolumeCompact(val))
                                            .font(RQTypography.label)
                                            .foregroundStyle(RQColors.textTertiary)
                                    }
                                }
                            }
                        }
                        .chartPlotStyle { plotArea in
                            plotArea.background(Color.clear)
                        }
                        .frame(height: 160)

                        // Delta indicator
                        if let delta = viewModel.volumeDeltaPercent {
                            HStack(spacing: RQSpacing.xs) {
                                Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 10, weight: .bold))
                                Text(String(format: "%+.0f%% vs last week", delta))
                                    .font(RQTypography.caption)
                            }
                            .foregroundColor(delta >= 0 ? RQColors.chartPositive : RQColors.chartNegative)
                        }
                    } else {
                        Text("Complete more workouts to see volume trends")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                            .frame(maxWidth: .infinity, minHeight: 100)
                    }
                }
            }
        }
    }

    // MARK: - 4. Smart Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeader("INSIGHTS")

            ForEach(viewModel.insights) { insight in
                insightCard(insight)
            }
        }
    }

    private func insightCard(_ insight: InsightCard) -> some View {
        HStack(spacing: RQSpacing.md) {
            // Colored left bar
            RoundedRectangle(cornerRadius: 1)
                .fill(insight.accentColor)
                .frame(width: 3)

            Image(systemName: insight.icon)
                .font(.system(size: 16))
                .foregroundColor(insight.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                Text(insight.title)
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)
                Text(insight.message)
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(RQSpacing.cardPadding)
        .background(Color.clear)
        .cornerRadius(RQSpacing.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: RQSpacing.cardCornerRadius)
                .stroke(RQColors.textTertiary, lineWidth: 1)
        )
    }

    // MARK: - 5. Recent PRs

    private var recentPRsSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeader("RECENT PRS")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RQSpacing.md) {
                    ForEach(viewModel.recentPRs.prefix(8), id: \.record.id) { pr in
                        prCard(pr.record, exerciseName: pr.exerciseName)
                    }
                }
            }
        }
    }

    private func prCard(_ record: PersonalRecord, exerciseName: String) -> some View {
        RQCard(padding: RQSpacing.md) {
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                HStack(spacing: RQSpacing.xs) {
                    Image(systemName: prIcon(record.recordType))
                        .font(.system(size: 10))
                        .foregroundColor(prColor(record.recordType))
                    Text(record.recordType.displayName.uppercased())
                        .font(RQTypography.label)
                        .tracking(0.5)
                        .foregroundColor(prColor(record.recordType))
                }

                Text(prValueFormatted(record))
                    .font(RQTypography.numbersSmall)
                    .foregroundColor(RQColors.textPrimary)

                Text(exerciseName)
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textSecondary)
                    .lineLimit(1)

                Text(relativeDateString(record.achievedAt))
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
            }
        }
        .frame(width: 130)
    }

    // MARK: - 6. Milestones

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            HStack {
                sectionHeader("MILESTONES")
                Spacer()
                let achieved = viewModel.achievedMilestones.count
                let total = viewModel.milestones.count
                Text("\(achieved)/\(total)")
                    .font(RQTypography.label)
                    .foregroundColor(RQColors.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RQSpacing.md) {
                    // Show next milestones first (most motivating), then achieved
                    ForEach(viewModel.nextMilestones) { milestone in
                        milestoneCard(milestone)
                    }
                    ForEach(viewModel.achievedMilestones.prefix(5)) { milestone in
                        milestoneCard(milestone)
                    }
                }
            }
        }
    }

    private func milestoneCard(_ milestone: MilestoneDefinition) -> some View {
        VStack(spacing: RQSpacing.sm) {
            // Progress ring with icon
            ZStack {
                Circle()
                    .stroke(RQColors.surfaceTertiary, lineWidth: 3)
                    .frame(width: 48, height: 48)

                Circle()
                    .trim(from: 0, to: milestone.progress)
                    .stroke(
                        milestone.isAchieved ? RQColors.accent : RQColors.textTertiary,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))

                Image(systemName: milestone.isAchieved ? "checkmark" : milestone.icon)
                    .font(.system(size: 16, weight: milestone.isAchieved ? .bold : .regular))
                    .foregroundColor(milestone.isAchieved ? RQColors.accent : RQColors.textTertiary)
            }

            Text(milestone.title)
                .font(RQTypography.caption)
                .foregroundColor(milestone.isAchieved ? RQColors.textPrimary : RQColors.textSecondary)
                .lineLimit(1)

            if milestone.isAchieved {
                Text("ACHIEVED")
                    .font(RQTypography.label)
                    .tracking(0.5)
                    .foregroundColor(RQColors.accent)
            } else {
                Text("\(Int(milestone.progress * 100))%")
                    .font(RQTypography.label)
                    .foregroundColor(RQColors.textTertiary)
            }
        }
        .frame(width: 90)
        .padding(.vertical, RQSpacing.sm)
        .padding(.horizontal, RQSpacing.xs)
        .background(Color.clear)
        .cornerRadius(RQSpacing.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: RQSpacing.cardCornerRadius)
                .stroke(
                    milestone.isAchieved ? RQColors.accent.opacity(0.5) : RQColors.textTertiary,
                    lineWidth: milestone.isAchieved ? 1 : 0.5
                )
        )
    }

    // MARK: - 7. Muscle Group Balance

    private var muscleBalanceSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            HStack {
                sectionHeader("MUSCLE BALANCE")
                Spacer()
                // Fractional volume toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.showFractionalVolume.toggle()
                    }
                } label: {
                    HStack(spacing: RQSpacing.xs) {
                        Image(systemName: viewModel.showFractionalVolume ? "arrow.triangle.branch" : "scope")
                            .font(.system(size: 10))
                        Text(viewModel.showFractionalVolume ? "ADJUSTED" : "DIRECT")
                            .font(RQTypography.label)
                            .tracking(0.5)
                    }
                    .foregroundColor(viewModel.showFractionalVolume ? RQColors.accent : RQColors.textTertiary)
                    .padding(.horizontal, RQSpacing.sm)
                    .padding(.vertical, RQSpacing.xxs)
                    .overlay(
                        RoundedRectangle(cornerRadius: RQRadius.small)
                            .stroke(
                                viewModel.showFractionalVolume ? RQColors.accent.opacity(0.5) : RQColors.textTertiary,
                                lineWidth: 0.5
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            RQCard {
                VStack(spacing: RQSpacing.lg) {
                    // Donut chart
                    Chart(viewModel.activeMuscleDistribution) { group in
                        SectorMark(
                            angle: .value("Volume", group.volume),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(group.color)
                        .cornerRadius(RQRadius.small)
                    }
                    .frame(height: 180)

                    if viewModel.showFractionalVolume {
                        HStack(spacing: RQSpacing.xs) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 10))
                            Text("Includes 0.5x synergist credit for compound lifts")
                                .font(RQTypography.caption)
                        }
                        .foregroundColor(RQColors.textTertiary)
                    }

                    // Legend
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: RQSpacing.sm) {
                        ForEach(viewModel.activeMuscleDistribution) { group in
                            HStack(spacing: RQSpacing.sm) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(group.color)
                                    .frame(width: 10, height: 10)

                                Text(group.displayName)
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textSecondary)
                                    .lineLimit(1)

                                Spacer()

                                Text(String(format: "%.0f%%", group.percentage))
                                    .font(RQTypography.label)
                                    .foregroundColor(RQColors.textTertiary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 8. Training Quality (Effective Reps)

    private var trainingQualitySection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            HStack {
                sectionHeader("TRAINING QUALITY")
                Spacer()
                if let ratio = viewModel.overallEffectiveRatio {
                    Text("\(Int(ratio * 100))% EFFECTIVE")
                        .font(RQTypography.label)
                        .tracking(0.5)
                        .foregroundColor(effectiveRatioColor(ratio))
                }
            }

            RQCard {
                VStack(spacing: RQSpacing.md) {
                    // Overall effective reps gauge
                    if let ratio = viewModel.overallEffectiveRatio {
                        HStack(spacing: RQSpacing.lg) {
                            // Circular gauge
                            ZStack {
                                Circle()
                                    .stroke(RQColors.surfaceTertiary, lineWidth: 4)
                                    .frame(width: 56, height: 56)
                                Circle()
                                    .trim(from: 0, to: ratio)
                                    .stroke(
                                        effectiveRatioColor(ratio),
                                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                    )
                                    .frame(width: 56, height: 56)
                                    .rotationEffect(.degrees(-90))
                                Text("\(Int(ratio * 100))")
                                    .font(RQTypography.numbersSmall)
                                    .foregroundColor(RQColors.textPrimary)
                            }

                            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                                Text("Effective Rep Ratio")
                                    .font(RQTypography.headline)
                                    .foregroundColor(RQColors.textPrimary)
                                Text("% of reps near failure (RPE 7+) that drive growth")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    // Per muscle group breakdown
                    ForEach(viewModel.effectiveRepsSummary.prefix(6)) { data in
                        HStack(spacing: RQSpacing.sm) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(data.color)
                                .frame(width: 10, height: 10)

                            Text(data.displayName)
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textSecondary)
                                .frame(width: 80, alignment: .leading)

                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(RQColors.surfaceTertiary)
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(effectiveRatioColor(data.effectiveRatio))
                                        .frame(width: max(0, geo.size.width * data.effectiveRatio), height: 6)
                                }
                            }
                            .frame(height: 6)

                            Text("\(data.effectiveReps)/\(data.totalReps)")
                                .font(RQTypography.label)
                                .foregroundColor(RQColors.textTertiary)
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private func effectiveRatioColor(_ ratio: Double) -> Color {
        if ratio >= 0.4 { return RQColors.success }
        if ratio >= 0.25 { return RQColors.accent }
        if ratio >= 0.15 { return RQColors.warning }
        return RQColors.error
    }

    // MARK: - 9. Training Frequency Heatmap

    private var frequencyHeatmapSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeader("TRAINING FREQUENCY")

            RQCard {
                VStack(alignment: .leading, spacing: RQSpacing.sm) {
                    // Day labels
                    HStack(spacing: 0) {
                        ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, day in
                            Text(day)
                                .font(RQTypography.label)
                                .foregroundColor(RQColors.textTertiary)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    // Heatmap grid
                    let weeks = organizeFrequencyByWeek()
                    VStack(spacing: 3) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                            HStack(spacing: 3) {
                                ForEach(0..<7, id: \.self) { dayIndex in
                                    let count = week.count > dayIndex ? week[dayIndex] : 0
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(heatmapColor(count: count))
                                        .aspectRatio(1, contentMode: .fit)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func organizeFrequencyByWeek() -> [[Int]] {
        let calendar = Calendar.current
        var weeks: [[Int]] = []
        var currentWeek: [Int] = []

        for entry in viewModel.frequencyData {
            let weekday = calendar.component(.weekday, from: entry.date)
            let mondayIndex = (weekday + 5) % 7

            if mondayIndex == 0 && !currentWeek.isEmpty {
                while currentWeek.count < 7 { currentWeek.append(0) }
                weeks.append(currentWeek)
                currentWeek = []
            }

            while currentWeek.count < mondayIndex { currentWeek.append(0) }
            currentWeek.append(entry.count)
        }

        if !currentWeek.isEmpty {
            while currentWeek.count < 7 { currentWeek.append(0) }
            weeks.append(currentWeek)
        }

        return weeks
    }

    private func heatmapColor(count: Int) -> Color {
        switch count {
        case 0: return RQColors.surfaceTertiary
        case 1: return RQColors.accent.opacity(0.4)
        default: return RQColors.accent
        }
    }

    // MARK: - 10. Exercise Progress Entry

    private var exerciseProgressButton: some View {
        Button {
            showExercisePicker = true
        } label: {
            RQCard {
                HStack {
                    VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                        Text("EXERCISE PROGRESS")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)
                        Text("View per-exercise trends, velocity, and plateau detection")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 20))
                        .foregroundColor(RQColors.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 11. Workout History

    private var workoutHistorySection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeader("WORKOUT HISTORY")

            LazyVStack(spacing: RQSpacing.md) {
                ForEach(viewModel.sessions) { session in
                    NavigationLink(value: session.id) {
                        sessionRow(session)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        let date = session.completedAt ?? session.startedAt
        let workout = viewModel.dayName(for: session)
        let template = viewModel.templateName(for: session)

        return RQCard {
            HStack(spacing: RQSpacing.md) {
                VStack(spacing: 2) {
                    Text(dayOfMonth(date))
                        .font(RQTypography.title3)
                        .foregroundColor(RQColors.textPrimary)
                    Text(monthAbbrev(date))
                        .font(RQTypography.label)
                        .textCase(.uppercase)
                        .foregroundColor(RQColors.textSecondary)
                }
                .frame(width: 44)

                RoundedRectangle(cornerRadius: 1)
                    .fill(RQColors.surfaceTertiary)
                    .frame(width: 1, height: 44)

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(workout ?? dayOfWeek(date))
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: RQSpacing.sm) {
                        if let template {
                            Text(template)
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.accent)
                                .lineLimit(1)
                        }

                        if template != nil, session.durationSeconds != nil {
                            Text("\u{00B7}")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }

                        if let duration = session.durationSeconds {
                            Label(formatDuration(duration), systemImage: "clock")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(RQColors.textTertiary)
            }
        }
    }

    // MARK: - Shared Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(RQTypography.label)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(RQColors.textSecondary)
            Spacer()
        }
    }

    private func isCurrentWeek(_ weekStart: Date) -> Bool {
        let calendar = Calendar.current
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return false }
        return calendar.isDate(weekStart, inSameDayAs: currentWeekStart)
    }

    private func shortDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func formatVolumeCompact(_ volume: Double) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.1fM", volume / 1_000_000)
        }
        if volume >= 1_000 {
            return String(format: "%.1fK", volume / 1_000)
        }
        return String(format: "%.0f", volume)
    }

    private func prIcon(_ type: RecordType) -> String {
        switch type {
        case .weight: return "scalemass"
        case .reps: return "number"
        case .volume: return "chart.bar"
        case .estimated1rm: return "bolt"
        }
    }

    private func prColor(_ type: RecordType) -> Color {
        switch type {
        case .weight: return RQColors.accent
        case .reps: return RQColors.success
        case .volume: return RQColors.hypertrophy
        case .estimated1rm: return RQColors.strength
        }
    }

    private func prValueFormatted(_ record: PersonalRecord) -> String {
        switch record.recordType {
        case .weight:
            return "\(formatWeight(record.value)) lbs"
        case .reps:
            return "\(Int(record.value)) reps"
        case .volume:
            return formatVolumeCompact(record.value)
        case .estimated1rm:
            return "\(formatWeight(record.value)) lbs"
        }
    }

    private func relativeDateString(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days) days ago" }
        if days < 30 { return "\(days / 7) weeks ago" }
        return "\(days / 30) months ago"
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }

    private func dayOfMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func monthAbbrev(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
