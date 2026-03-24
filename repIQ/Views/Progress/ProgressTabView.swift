import SwiftUI
import Charts

struct ProgressTabView: View {
    @State private var viewModel = ProgressDashboardViewModel()
    @State private var showExercisePicker = false
    @State private var showMonthlyReport = false
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
                        // 1. Streak Banner — emotional hook
                        streakBanner

                        // 2. Consistency Score — overall training health
                        if let score = viewModel.consistencyScore, score.overall > 0 {
                            consistencyScoreSection
                        }

                        // 3. Overview Stats Grid — quick health check
                        overviewStatsGrid

                        // Exercise Progress — drill-down entry
                        exerciseProgressButton

                        // 4. Weekly Volume Chart — primary trend
                        volumeChartSection

                        // 5. Smart Insights — prescriptive advice (high value)
                        if !viewModel.insights.isEmpty {
                            insightsSection
                        }

                        // 6. Recent PRs — reward/celebration
                        if !viewModel.recentPRs.isEmpty {
                            recentPRsSection
                        }

                        // 7. Push/Pull Balance
                        if let balance = viewModel.pushPullBalance, balance.pushVolume > 0 || balance.pullVolume > 0 {
                            pushPullSection
                        }

                        // 9. Muscle Balance — with fractional volume toggle
                        if !viewModel.activeMuscleDistribution.isEmpty {
                            muscleBalanceSection
                        }

                        // 10. Volume Landmarks
                        if !viewModel.volumeLandmarks.isEmpty {
                            volumeLandmarksSection
                        }

                        // 11. Training Quality — effective reps breakdown
                        if !viewModel.effectiveRepsSummary.isEmpty {
                            trainingQualitySection
                        }

                        // Training Frequency moved to Home page (Activity calendar)
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
            .task {
                await viewModel.loadDashboard()
                await socialViewModel.loadSocialData()
            }
            .refreshable {
                await viewModel.loadDashboard()
            }
        }
    }

    // MARK: - Share Text

    // Share text removed — replaced with Monthly Report Card button

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

    // MARK: - 2. Consistency Score

    private var consistencyScoreSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeaderWithInfo("CONSISTENCY", topic: ProgressExplainer.consistencyScore)

            if let score = viewModel.consistencyScore {
                RQCard {
                    VStack(spacing: RQSpacing.lg) {
                        HStack(spacing: RQSpacing.lg) {
                            // Score ring
                            ZStack {
                                Circle()
                                    .stroke(RQColors.surfaceTertiary, lineWidth: 5)
                                    .frame(width: 68, height: 68)
                                Circle()
                                    .trim(from: 0, to: Double(score.overall) / 100.0)
                                    .stroke(
                                        score.grade.color,
                                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                    )
                                    .frame(width: 68, height: 68)
                                    .rotationEffect(.degrees(-90))
                                VStack(spacing: 0) {
                                    Text("\(score.overall)")
                                        .font(RQTypography.numbers)
                                        .foregroundColor(RQColors.textPrimary)
                                }
                            }

                            VStack(alignment: .leading, spacing: RQSpacing.xs) {
                                Text(score.grade.displayName.uppercased())
                                    .font(RQTypography.label)
                                    .tracking(1)
                                    .foregroundColor(score.grade.color)
                                Text("Training consistency over the past 8 weeks")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                            }

                            Spacer()
                        }

                        // Factor breakdown
                        VStack(spacing: RQSpacing.sm) {
                            consistencyFactor(label: "Frequency", value: score.frequencyScore, weight: "40%")
                            consistencyFactor(label: "Volume Stability", value: score.volumeStabilityScore, weight: "25%")
                            consistencyFactor(label: "Streak", value: score.streakScore, weight: "20%")
                            consistencyFactor(label: "Recency", value: score.recencyScore, weight: "15%")
                        }
                    }
                }
            }
        }
    }

    private func consistencyFactor(label: String, value: Double, weight: String) -> some View {
        HStack(spacing: RQSpacing.sm) {
            Text(label)
                .font(RQTypography.caption)
                .foregroundColor(RQColors.textSecondary)
                .frame(width: 100, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(RQColors.surfaceTertiary)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(factorColor(value))
                        .frame(width: max(0, geo.size.width * value), height: 4)
                }
            }
            .frame(height: 4)

            Text(weight)
                .font(RQTypography.label)
                .foregroundColor(RQColors.textTertiary)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private func factorColor(_ value: Double) -> Color {
        if value >= 0.75 { return RQColors.success }
        if value >= 0.5 { return RQColors.accent }
        if value >= 0.25 { return RQColors.warning }
        return RQColors.error
    }

    // MARK: - 3. Overview Stats Grid

    private var overviewStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: RQSpacing.md) {
            overviewStatCard(
                label: "WEEKLY VOLUME",
                value: formatVolumeCompact(viewModel.weeklyVolume),
                icon: "scalemass.fill",
                color: RQColors.accent
            )
            overviewStatCard(
                label: "THIS WEEK",
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

    // MARK: - 4. Weekly Volume Chart

    private var volumeChartSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeaderWithInfo("VOLUME TREND", topic: ProgressExplainer.volumeTrend)

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

    // MARK: - 6. Recent PRs

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

    // MARK: - 7. Push/Pull Balance

    private var pushPullSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeaderWithInfo("PUSH / PULL BALANCE", topic: ProgressExplainer.pushPullBalance)

            if let balance = viewModel.pushPullBalance {
                RQCard {
                    VStack(spacing: RQSpacing.lg) {
                        // Ratio display
                        HStack(spacing: RQSpacing.md) {
                            Image(systemName: balance.status.icon)
                                .font(.system(size: 22))
                                .foregroundColor(balance.status.color)

                            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                                HStack(spacing: RQSpacing.sm) {
                                    Text(balance.ratioString)
                                        .font(RQTypography.numbers)
                                        .foregroundColor(RQColors.textPrimary)
                                    Text(balance.status.displayName.uppercased())
                                        .font(RQTypography.label)
                                        .tracking(0.5)
                                        .foregroundColor(balance.status.color)
                                }
                                Text("Push : Pull ratio (past 30 days)")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                            }

                            Spacer()
                        }

                        // Visual bar
                        let total = balance.pushVolume + balance.pullVolume
                        if total > 0 {
                            VStack(spacing: RQSpacing.sm) {
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
                                .frame(height: 10)

                                HStack {
                                    HStack(spacing: RQSpacing.xs) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(RQColors.strength)
                                            .frame(width: 10, height: 10)
                                        Text("Push \(balance.pushSets) sets")
                                            .font(RQTypography.caption)
                                            .foregroundColor(RQColors.textSecondary)
                                    }
                                    Spacer()
                                    HStack(spacing: RQSpacing.xs) {
                                        Text("Pull \(balance.pullSets) sets")
                                            .font(RQTypography.caption)
                                            .foregroundColor(RQColors.textSecondary)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(RQColors.accent)
                                            .frame(width: 10, height: 10)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 9. Muscle Group Balance

    private var muscleBalanceSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            HStack {
                sectionHeaderWithInfo("MUSCLE BALANCE", topic: ProgressExplainer.muscleBalance)
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

    // MARK: - 10. Volume Landmarks

    private var volumeLandmarksSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeaderWithInfo("VOLUME LANDMARKS", topic: ProgressExplainer.volumeLandmarks)

            RQCard {
                VStack(spacing: RQSpacing.md) {
                    // Legend
                    HStack(spacing: RQSpacing.lg) {
                        landmarkLegendItem(label: "MEV", color: RQColors.warning)
                        landmarkLegendItem(label: "MAV", color: RQColors.success)
                        landmarkLegendItem(label: "MRV", color: RQColors.error)
                    }

                    ForEach(viewModel.volumeLandmarks) { data in
                        volumeLandmarkRow(data)
                    }
                }
            }
        }
    }

    private func landmarkLegendItem(label: String, color: Color) -> some View {
        HStack(spacing: RQSpacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(RQTypography.label)
                .foregroundColor(RQColors.textTertiary)
        }
    }

    private func volumeLandmarkRow(_ data: VolumeLandmarkData) -> some View {
        VStack(spacing: RQSpacing.xs) {
            HStack {
                HStack(spacing: RQSpacing.sm) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(data.color)
                        .frame(width: 10, height: 10)
                    Text(data.displayName)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textSecondary)
                }

                Spacer()

                HStack(spacing: RQSpacing.xs) {
                    Text("\(data.currentWeeklySets) sets")
                        .font(RQTypography.numbersSmall)
                        .foregroundColor(RQColors.textPrimary)
                    Image(systemName: data.status.icon)
                        .font(.system(size: 10))
                        .foregroundColor(data.status.color)
                }
            }

            // Range bar visualization
            GeometryReader { geo in
                let totalRange = Double(data.mrv + 4) // Give visual breathing room
                let barWidth = geo.size.width

                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(RQColors.surfaceTertiary)
                        .frame(height: 6)

                    // MEV marker
                    let mevX = barWidth * (Double(data.mev) / totalRange)
                    Rectangle()
                        .fill(RQColors.warning)
                        .frame(width: 1.5, height: 10)
                        .offset(x: mevX)

                    // MAV zone (green)
                    let mavStartX = barWidth * (Double(data.mav.lowerBound) / totalRange)
                    let mavEndX = barWidth * (Double(data.mav.upperBound) / totalRange)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(RQColors.success.opacity(0.2))
                        .frame(width: max(0, mavEndX - mavStartX), height: 6)
                        .offset(x: mavStartX)

                    // MRV marker
                    let mrvX = barWidth * (Double(data.mrv) / totalRange)
                    Rectangle()
                        .fill(RQColors.error)
                        .frame(width: 1.5, height: 10)
                        .offset(x: mrvX)

                    // Current position dot
                    let currentX = barWidth * (min(Double(data.currentWeeklySets), totalRange) / totalRange)
                    Circle()
                        .fill(data.status.color)
                        .frame(width: 8, height: 8)
                        .offset(x: currentX - 4)
                }
            }
            .frame(height: 10)
        }
    }

    // MARK: - 11. Training Quality (Effective Reps)

    private var trainingQualitySection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            HStack {
                sectionHeaderWithInfo("TRAINING QUALITY", topic: ProgressExplainer.effectiveReps)
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

    // MARK: - 12. Training Frequency Heatmap

    // Training Frequency removed — Activity calendar available on Home page

    // MARK: - 13. Exercise Progress Entry

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
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(RQColors.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

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
