import SwiftUI
import Charts
import MuscleMap

struct ProgressTabView: View {
    @State private var viewModel = ProgressDashboardViewModel()
    @State private var showExercisePicker = false
    @State private var showMonthlyReport = false
    @State private var showAllPRs = false
    @State private var showCompareLifts = false
    @State private var selectedExerciseId: UUID?
    @State private var socialViewModel = SocialViewModel()
    /// Set when the user taps a bar in the volume chart; presents the
    /// per-week session sheet.
    @State private var selectedVolumeWeek: Date?

    /// True once any data source has populated — the very first signal that
    /// the user has a workout history. Used to drop the all-or-nothing
    /// spinner gate in favor of progressive section reveal.
    private var hasAnyData: Bool {
        !viewModel.sessions.isEmpty
            || viewModel.monthlyStats != nil
            || viewModel.lastWorkoutRecap != nil
            || !viewModel.recentPRs.isEmpty
            || !viewModel.topLifts.isEmpty
            || viewModel.totalSessions > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                // Sections render independently as their data arrives.
                // Sentinel for "truly no data" is the totalSessions count
                // from the milestone aggregate, which is one of the fastest
                // fetches.
                if viewModel.isLoading, !hasAnyData {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if !viewModel.isLoading, !hasAnyData {
                    EmptyStateView(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "No Progress Data",
                        message: "Complete your first workout to start tracking your progress and PRs."
                    )
                } else {
                    VStack(spacing: RQSpacing.xl) {
                        timeWindowPicker

                        // 1. Monthly Stats Header — at-a-glance snapshot of this month
                        MonthlyStatsHeader(stats: viewModel.monthlyStats)

                        // 1b. Lifetime totals — accumulated weight of all sessions
                        if viewModel.totalSessions > 0 {
                            LifetimeTotalsStrip(
                                totalSessions: viewModel.totalSessions,
                                totalVolume: viewModel.totalVolume,
                                totalPRCount: viewModel.totalPRCount
                            )
                        }

                        // 2. Last Workout recap — answers "how did I do last time?"
                        if let recap = viewModel.lastWorkoutRecap {
                            LastWorkoutRecapCard(recap: recap)
                        }

                        // 2b. "You vs past you" card on the user's top lift.
                        // Quietly absent when there's not enough history.
                        if let snapshot = viewModel.pastMeSnapshot {
                            PastMeCard(snapshot: snapshot)
                        }

                        // 3. Hero: Strength Trajectory — top lifts scoped by workout day
                        StrengthTrajectoryCard(
                            lifts: viewModel.topLifts,
                            bodyweightLbs: viewModel.bodyweightLbs,
                            profileSex: viewModel.profileSex,
                            onSelect: { lift in
                                selectedExerciseId = lift.exerciseId
                            },
                            onBrowseAll: {
                                showExercisePicker = true
                            },
                            onCompare: {
                                showCompareLifts = true
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

                        // 5b. Weekly volume zones — MEV/MAV/MRV bands per muscle group
                        if !viewModel.volumeLandmarks.isEmpty {
                            VolumeLandmarksCard(landmarks: viewModel.volumeLandmarks)
                        }

                        // 5c. Effective reps — stimulus vs junk volume
                        if !viewModel.effectiveRepsSummary.isEmpty {
                            EffectiveRepsCard(summaries: viewModel.effectiveRepsSummary)
                        }

                        // 6. Recent PRs — celebration
                        if !viewModel.recentPRs.isEmpty {
                            recentPRsSection
                        }

                        // 7. Monthly Report Card CTA — visible whenever the user has any history.
                        // Current month may be empty; the report falls back to last month with data.
                        monthlyReportCTA
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
            .navigationDestination(isPresented: $showAllPRs) {
                AllPRsView()
            }
            .navigationDestination(isPresented: $showCompareLifts) {
                StrengthCompareView(topLifts: viewModel.topLifts)
            }
            .navigationDestination(item: $selectedExerciseId) { exerciseId in
                ExerciseProgressLoaderView(exerciseId: exerciseId)
            }
            .sheet(item: Binding(
                get: { selectedVolumeWeek.map { VolumeWeekSelection(weekStart: $0) } },
                set: { selectedVolumeWeek = $0?.weekStart }
            )) { selection in
                WeekSessionsSheet(
                    weekStart: selection.weekStart,
                    sessions: viewModel.sessions(inWeekStartingOn: selection.weekStart),
                    templateName: { viewModel.templateName(for: $0) },
                    dayName: { viewModel.dayName(for: $0) },
                    onSelectSession: { _ in
                        // Sessions are read-only inside the week sheet for
                        // now; tap-through to detail will be wired via the
                        // navigation-path refactor in a later pass.
                        selectedVolumeWeek = nil
                    }
                )
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

    // MARK: - Time Window Picker

    /// Segmented row of TimeWindow chips. Affects: volume trend, muscle
    /// balance, effective reps, and the heatmap's PR markers. Sections that
    /// are inherently fixed-window (this month, last workout, weekly volume
    /// zones) ignore the selection.
    private var timeWindowPicker: some View {
        HStack(spacing: RQSpacing.xs) {
            ForEach(TimeWindow.allCases, id: \.self) { window in
                let isSelected = window == viewModel.selectedTimeWindow
                Button {
                    Task { await viewModel.setTimeWindow(window) }
                } label: {
                    Text(window.label)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundColor(isSelected ? RQColors.background : RQColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: RQRadius.small)
                                .fill(isSelected ? RQColors.accent : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: RQRadius.small)
                                        .stroke(
                                            isSelected ? RQColors.accent : RQColors.surfaceTertiary,
                                            lineWidth: 0.5
                                        )
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(viewModel.isReloadingWindowedSections ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isReloadingWindowedSections)
    }

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

                    // Heatmap with PR-day gold dots
                    ConsistencyHeatmap(
                        dailyData: viewModel.frequencyData,
                        prDates: viewModel.prDates
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: RQSpacing.md) {
                        if !viewModel.prDates.isEmpty {
                            HStack(spacing: RQSpacing.xs) {
                                Circle()
                                    .fill(RQColors.supersetGold)
                                    .frame(width: 5, height: 5)
                                Text("PR DAY")
                                    .font(.system(size: 9, weight: .semibold))
                                    .tracking(0.5)
                                    .foregroundColor(RQColors.textTertiary)
                            }
                        }
                        Spacer()
                    }

                    if let narrative = viewModel.consistencyNarrative {
                        HStack(spacing: RQSpacing.xs) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9))
                                .foregroundColor(RQColors.accent)
                            Text(narrative)
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
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

    /// The list of muscle filters offered above the volume chart. "All"
    /// (nil) is the default; the rest match repIQ muscle group keys.
    private let volumeMuscleFilters: [(label: String, key: String?)] = [
        ("ALL", nil),
        ("CHEST", "chest"),
        ("BACK", "back"),
        ("SHOULDERS", "shoulders"),
        ("QUADS", "quads"),
        ("HAMSTRINGS", "hamstrings"),
        ("GLUTES", "glutes"),
        ("BICEPS", "biceps"),
        ("TRICEPS", "triceps"),
        ("CALVES", "calves"),
        ("ABS", "abs")
    ]

    private var volumeChartSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeaderWithInfo("VOLUME TREND", topic: ProgressExplainer.volumeTrend)

            volumeMuscleFilterChips

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
                        .chartXSelection(value: Binding(
                            get: { selectedVolumeWeek },
                            set: { newValue in
                                if let date = newValue,
                                   let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: date)?.start {
                                    selectedVolumeWeek = weekStart
                                }
                            }
                        ))
                        .opacity(viewModel.isReloadingVolumeTrend ? 0.5 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.isReloadingVolumeTrend)

                        // Narrative interpretation (replaces raw % delta). The
                        // server-computed narrative is only meaningful for the
                        // unfiltered view; under a muscle filter we show a
                        // simpler "showing X volume only" caption instead.
                        if viewModel.volumeMuscleFilter == nil, let narrative = viewModel.volumeTrendNarrative {
                            HStack(spacing: RQSpacing.xs) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 9))
                                    .foregroundColor(RQColors.accent)
                                Text(narrative)
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textSecondary)
                            }
                        } else if let muscle = viewModel.volumeMuscleFilter {
                            HStack(spacing: RQSpacing.xs) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 9))
                                    .foregroundColor(RQColors.textTertiary)
                                Text("Showing \(muscle.capitalized) volume only. Tap a bar to see that week's sessions.")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
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

    /// Horizontally-scrolling chip row that lets the user filter the volume
    /// chart to a single muscle group. Tapping a chip triggers an async
    /// refetch on the ViewModel.
    private var volumeMuscleFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RQSpacing.xs) {
                ForEach(volumeMuscleFilters, id: \.label) { filter in
                    let isSelected = filter.key == viewModel.volumeMuscleFilter
                    Button {
                        guard !isSelected else { return }
                        Task { await viewModel.setVolumeMuscleFilter(filter.key) }
                    } label: {
                        Text(filter.label)
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.5)
                            .foregroundColor(isSelected ? RQColors.background : RQColors.textSecondary)
                            .padding(.horizontal, RQSpacing.sm)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: RQRadius.small)
                                    .fill(isSelected ? RQColors.accent : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: RQRadius.small)
                                            .stroke(
                                                isSelected ? RQColors.accent : RQColors.surfaceTertiary,
                                                lineWidth: 0.5
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
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

    /// Recent PR section header text: shows total count followed by a
    /// "this week / this month" breakdown when relevant.
    private var prSectionTitle: String {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let thisWeek = viewModel.recentPRs.filter { $0.record.achievedAt >= weekStart }.count
        let thisMonth = viewModel.recentPRs.filter { $0.record.achievedAt >= monthStart }.count

        if thisWeek > 0 {
            return "RECENT PRS · \(thisWeek) THIS WEEK"
        }
        if thisMonth > 0 {
            return "RECENT PRS · \(thisMonth) THIS MONTH"
        }
        return "RECENT PRS"
    }

    private var viewAllPRsButton: some View {
        Button {
            showAllPRs = true
        } label: {
            HStack(spacing: 2) {
                Text("VIEW ALL")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundColor(RQColors.accent)
        }
        .buttonStyle(.plain)
    }

    private var recentPRsSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            RQSectionHeader(
                title: prSectionTitle,
                trailing: AnyView(viewAllPRsButton)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RQSpacing.md) {
                    ForEach(viewModel.recentPRs.prefix(8), id: \.record.id) { pr in
                        if let sessionId = pr.record.sessionId {
                            NavigationLink(value: sessionId) {
                                prCard(pr.record, exerciseName: pr.exerciseName, delta: pr.delta)
                            }
                            .buttonStyle(.plain)
                        } else {
                            prCard(pr.record, exerciseName: pr.exerciseName, delta: pr.delta)
                        }
                    }
                }
            }
        }
    }

    private func prCard(_ record: PersonalRecord, exerciseName: String, delta: Double?) -> some View {
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

                if let deltaLabel = prDeltaLabel(record: record, delta: delta) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8, weight: .bold))
                        Text(deltaLabel)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(RQColors.success)
                } else if delta == nil {
                    Text("FIRST PR")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(RQColors.warning)
                }

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

    /// Formats the PR delta to read naturally per record type. Returns nil
    /// when the delta is missing or non-positive (we don't display flat or
    /// negative deltas — the "PR" being present already implies it's an
    /// improvement).
    private func prDeltaLabel(record: PersonalRecord, delta: Double?) -> String? {
        guard let delta, delta > 0 else { return nil }
        switch record.recordType {
        case .weight, .estimated1rm:
            return "\(formatWeight(delta)) lbs"
        case .reps:
            return "\(Int(delta.rounded())) reps"
        case .volume:
            return formatVolumeCompact(delta)
        }
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
                        Text(viewModel.showFractionalVolume ? "+ SYNERGISTS" : "DIRECT ONLY")
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
                    MuscleBalanceBodyView(
                        distribution: viewModel.activeMuscleDistribution,
                        gender: viewModel.bodyDiagramGender
                    )

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

                    if let narrative = viewModel.muscleBalanceNarrative {
                        Divider().background(RQColors.surfaceTertiary)
                        HStack(spacing: RQSpacing.xs) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9))
                                .foregroundColor(RQColors.accent)
                            Text(narrative)
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
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
    // Thin wrappers over RQSectionHeader so legacy call sites keep their
    // short syntax. Prefer RQSectionHeader directly in new code.

    private func sectionHeader(_ title: String) -> some View {
        RQSectionHeader(title: title)
    }

    private func sectionHeaderWithInfo(_ title: String, topic: ProgressExplainer.Topic) -> some View {
        RQSectionHeader(title: title, infoTopic: topic)
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

/// Identifiable wrapper that lets us drive `.sheet(item:)` from an optional
/// week-start Date when the user taps a bar in the volume chart.
private struct VolumeWeekSelection: Identifiable {
    let weekStart: Date
    var id: Date { weekStart }
}
