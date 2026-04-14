import SwiftUI
import Charts

struct ProgressTabView: View {
    @State private var viewModel = ProgressDashboardViewModel()
    @State private var showExercisePicker = false
    @State private var showMonthlyReport = false
    @State private var selectedExerciseId: UUID?
    @State private var socialViewModel = SocialViewModel()

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
                        // 1. Monthly Stats Header — at-a-glance snapshot of this month
                        MonthlyStatsHeader(stats: viewModel.monthlyStats)

                        // 2. Last Workout recap — answers "how did I do last time?"
                        if let recap = viewModel.lastWorkoutRecap {
                            LastWorkoutRecapCard(recap: recap)
                        }

                        // 3. Hero: Strength Trajectory — top lifts scoped by workout day
                        StrengthTrajectoryCard(
                            lifts: viewModel.topLifts,
                            onSelect: { lift in
                                selectedExerciseId = lift.exerciseId
                            },
                            onBrowseAll: {
                                showExercisePicker = true
                            }
                        )

                        // 3. Streak + Consistency (merged)
                        streakConsistencySection

                        // 3. Smart Insights — prescriptive coaching (promoted from #6)
                        if !viewModel.insights.isEmpty {
                            insightsSection
                        }

                        // 4. Volume Trend with 4-week baseline overlay
                        volumeChartSection

                        // 5. Muscle Balance + Push/Pull (merged)
                        if !viewModel.activeMuscleDistribution.isEmpty {
                            muscleBalanceSection
                        }

                        // 6. Recent PRs — celebration
                        if !viewModel.recentPRs.isEmpty {
                            recentPRsSection
                        }

                        // 7. Monthly Report Card CTA — only when there's enough data
                        if (viewModel.monthlyStats?.workouts ?? 0) >= 3 {
                            monthlyReportCTA
                        }
                    }
                    .padding(.horizontal, RQSpacing.screenHorizontal)
                    .padding(.top, RQSpacing.lg)
                    .padding(.bottom, RQSpacing.xxxl)
                }
            }
            .background(RQColors.background)
            .navigationTitle("Progress")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showMonthlyReport = true
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(RQColors.accent)
                    }
                }
            }
            .navigationDestination(isPresented: $showMonthlyReport) {
                MonthlyWrappedView(viewModel: socialViewModel)
            }
            .navigationDestination(for: UUID.self) { sessionId in
                SessionDetailView(viewModel: viewModel, sessionId: sessionId)
            }
            .navigationDestination(isPresented: $showExercisePicker) {
                ExercisePickerProgressView()
            }
            .navigationDestination(item: $selectedExerciseId) { exerciseId in
                ExerciseProgressLoaderView(exerciseId: exerciseId)
            }
            .task {
                await viewModel.loadDashboard()
                await socialViewModel.loadSocialData()
            }
            .refreshable {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                await viewModel.loadDashboard()
            }
        }
    }

    // MARK: - Share Text

    // Share text removed — replaced with Monthly Report Card button

    // MARK: - 2. Streak + Consistency (merged)

    private var streakConsistencySection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeaderWithInfo("CONSISTENCY", topic: ProgressExplainer.consistencyScore)

            RQCard {
                VStack(alignment: .leading, spacing: RQSpacing.lg) {
                    // Top row: flame + streak + consistency ring
                    HStack(spacing: RQSpacing.lg) {
                        // Flame + streak
                        HStack(spacing: RQSpacing.sm) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 22))
                                .foregroundColor(streakColor)

                            VStack(alignment: .leading, spacing: 0) {
                                if let streak = viewModel.streakData, streak.currentStreak > 0 {
                                    Text("\(streak.currentStreak)")
                                        .font(RQTypography.numbers)
                                        .foregroundColor(RQColors.textPrimary)
                                    Text("WEEK STREAK")
                                        .font(.system(size: 8, weight: .semibold))
                                        .tracking(0.5)
                                        .foregroundColor(RQColors.textTertiary)
                                } else {
                                    Text("—")
                                        .font(RQTypography.numbers)
                                        .foregroundColor(RQColors.textTertiary)
                                    Text("NO STREAK")
                                        .font(.system(size: 8, weight: .semibold))
                                        .tracking(0.5)
                                        .foregroundColor(RQColors.textTertiary)
                                }
                            }
                        }

                        Spacer()

                        // Consistency ring
                        if let score = viewModel.consistencyScore, score.overall > 0 {
                            HStack(spacing: RQSpacing.sm) {
                                ZStack {
                                    Circle()
                                        .stroke(RQColors.surfaceTertiary, lineWidth: 4)
                                        .frame(width: 48, height: 48)
                                    Circle()
                                        .trim(from: 0, to: Double(score.overall) / 100.0)
                                        .stroke(
                                            score.grade.color,
                                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                        )
                                        .frame(width: 48, height: 48)
                                        .rotationEffect(.degrees(-90))
                                    Text("\(score.overall)")
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(RQColors.textPrimary)
                                }

                                VStack(alignment: .leading, spacing: 0) {
                                    Text(score.grade.displayName.uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(0.5)
                                        .foregroundColor(score.grade.color)
                                    Text("8-week score")
                                        .font(.system(size: 9))
                                        .foregroundColor(RQColors.textTertiary)
                                }
                            }
                        }
                    }

                    // Heatmap
                    ConsistencyHeatmap(dailyData: viewModel.frequencyData)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var streakColor: Color {
        guard let streak = viewModel.streakData else { return RQColors.textTertiary }
        if streak.currentStreak >= 12 { return RQColors.warning }  // 3+ months
        if streak.currentStreak >= 4 { return RQColors.accent }    // 1+ month
        if streak.currentStreak >= 2 { return RQColors.success }   // 2+ weeks
        if streak.currentStreak > 0 { return RQColors.textSecondary }
        return RQColors.textTertiary
    }

    // MARK: - 4. Weekly Volume Chart

    private var volumeChartSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeaderWithInfo("VOLUME TREND", topic: ProgressExplainer.volumeTrend)

            RQCard {
                VStack(alignment: .leading, spacing: RQSpacing.md) {
                    if viewModel.volumeTrend.contains(where: { $0.totalVolume > 0 }) {
                        Chart {
                            ForEach(viewModel.volumeTrend) { week in
                                BarMark(
                                    x: .value("Week", week.weekStart, unit: .weekOfYear),
                                    y: .value("Volume", week.totalVolume)
                                )
                                .foregroundStyle(isCurrentWeek(week.weekStart) ? RQColors.accent : RQColors.textTertiary)
                                .cornerRadius(RQRadius.small)
                            }
                            // 4-week baseline reference line
                            if let baseline = viewModel.volumeBaseline {
                                RuleMark(y: .value("Baseline", baseline))
                                    .foregroundStyle(RQColors.success.opacity(0.7))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                    .annotation(position: .top, alignment: .trailing) {
                                        Text("4wk avg")
                                            .font(.system(size: 8, weight: .semibold))
                                            .foregroundColor(RQColors.success.opacity(0.8))
                                    }
                            }
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

                        // Narrative interpretation (replaces raw % delta)
                        if let narrative = viewModel.volumeTrendNarrative {
                            HStack(spacing: RQSpacing.xs) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 9))
                                    .foregroundColor(RQColors.accent)
                                Text(narrative)
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textSecondary)
                            }
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

    // MARK: - 5. Smart Insights

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

    // MARK: - Monthly Report CTA

    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date())
    }

    private var monthlyReportCTA: some View {
        Button {
            showMonthlyReport = true
        } label: {
            HStack(spacing: RQSpacing.md) {
                ZStack {
                    Circle()
                        .fill(RQColors.accent.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(RQColors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Your \(currentMonthName) Report Card")
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)
                    Text("See your monthly highlights, top lifts, and stats")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(RQColors.textTertiary)
            }
            .padding(RQSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: RQSpacing.cardCornerRadius)
                    .fill(RQColors.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: RQSpacing.cardCornerRadius)
                            .stroke(RQColors.accent.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 6. Recent PRs

    private var recentPRsSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeader("RECENT PRS")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RQSpacing.md) {
                    ForEach(viewModel.recentPRs.prefix(8), id: \.record.id) { pr in
                        if let sessionId = pr.record.sessionId {
                            NavigationLink(value: sessionId) {
                                prCard(pr.record, exerciseName: pr.exerciseName)
                            }
                            .buttonStyle(.plain)
                        } else {
                            prCard(pr.record, exerciseName: pr.exerciseName)
                        }
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

    // MARK: - 5. Muscle Balance (with merged Push/Pull)

    private var muscleBalanceSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            HStack {
                sectionHeaderWithInfo("MUSCLE BALANCE", topic: ProgressExplainer.muscleBalance)
                Spacer()
                // Info button explaining the DIRECT/ADJUSTED toggle
                InfoButton(topic: ProgressExplainer.fractionalVolume)
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
                    // Body diagram hero + watch list
                    MuscleBalanceBodyView(distribution: viewModel.activeMuscleDistribution)

                    if viewModel.showFractionalVolume {
                        HStack(spacing: RQSpacing.xs) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 10))
                            Text("Includes 0.5x synergist credit for compound lifts")
                                .font(RQTypography.caption)
                        }
                        .foregroundColor(RQColors.textTertiary)
                    }

                    // Push / Pull ratio (merged in)
                    if let balance = viewModel.pushPullBalance,
                       balance.pushVolume + balance.pullVolume > 0 {
                        Divider().background(RQColors.surfaceTertiary)
                        pushPullStrip(balance)
                    }
                }
            }
        }
    }

    private func pushPullStrip(_ balance: PushPullBalance) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.xs) {
            HStack(spacing: RQSpacing.sm) {
                Image(systemName: balance.status.icon)
                    .font(.system(size: 12))
                    .foregroundColor(balance.status.color)
                Text("PUSH : PULL")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(RQColors.textTertiary)
                Text(balance.ratioString)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(RQColors.textPrimary)
                Spacer()
                Text(balance.status.displayName.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(balance.status.color)
            }

            // Visual bar
            let total = balance.pushVolume + balance.pullVolume
            if total > 0 {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(RQColors.strength)
                            .frame(width: max(4, geo.size.width * (balance.pushVolume / total)))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(RQColors.accent)
                            .frame(width: max(4, geo.size.width * (balance.pullVolume / total)))
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("Push \(balance.pushSets)")
                        .font(.system(size: 9))
                        .foregroundColor(RQColors.textTertiary)
                    Spacer()
                    Text("Pull \(balance.pullSets)")
                        .font(.system(size: 9))
                        .foregroundColor(RQColors.textTertiary)
                }
            }
        }
    }

    // MARK: - Training Frequency Heatmap

    // Training Frequency removed — Activity calendar available on Home page
    // Exercise Progress entry now lives in the Strength Trajectory hero card (tap through).
    // Workout History removed — available via Home page

    // MARK: - Section Header Helpers

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

    private func sectionHeaderWithInfo(_ title: String, topic: ProgressExplainer.Topic) -> some View {
        HStack(spacing: RQSpacing.xs) {
            Text(title)
                .font(RQTypography.label)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(RQColors.textSecondary)
            InfoButton(topic: topic)
        }
    }

    // MARK: - Shared Helpers

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

}
