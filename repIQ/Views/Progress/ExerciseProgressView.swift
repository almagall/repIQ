import SwiftUI
import Charts
import Supabase

struct ExerciseProgressView: View {
    let exercise: Exercise
    @State private var snapshots: [ExerciseSessionSnapshot] = []
    @State private var currentPRs: [PersonalRecord] = []
    @State private var isLoading = false
    @State private var selectedMetric: ProgressMetric = .weight

    private let analyticsService = AnalyticsService()
    private let progressionService = ProgressionService()

    enum ProgressMetric: String, CaseIterable {
        case weight = "Weight"
        case volume = "Volume"
        case estimated1rm = "Est. 1RM"
        case rpe = "RPE"
    }

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                VStack(spacing: RQSpacing.xl) {
                    // Header badges
                    headerBadges

                    // Metric selector
                    metricPicker

                    // Trend chart
                    trendChart

                    // PR cards
                    if !currentPRs.isEmpty {
                        prSection
                    }

                    // Recent sessions
                    if !snapshots.isEmpty {
                        recentSessionsSection
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.top, RQSpacing.lg)
                .padding(.bottom, RQSpacing.xxxl)
            }
        }
        .background(RQColors.background)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await loadData()
        }
    }

    // MARK: - Header Badges

    private var headerBadges: some View {
        HStack(spacing: RQSpacing.sm) {
            badge(text: MuscleGroup(rawValue: exercise.muscleGroup)?.displayName ?? exercise.muscleGroup.capitalized, color: RQColors.accent)
            badge(text: exercise.equipment.capitalized, color: RQColors.textTertiary)
            if exercise.isCompound {
                badge(text: "Compound", color: RQColors.strength)
            }
            Spacer()
        }
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text.uppercased())
            .font(RQTypography.label)
            .tracking(0.5)
            .foregroundColor(color)
            .padding(.horizontal, RQSpacing.sm)
            .padding(.vertical, RQSpacing.xxs)
            .overlay(
                RoundedRectangle(cornerRadius: RQRadius.small)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
    }

    // MARK: - Metric Picker

    private var metricPicker: some View {
        Picker("Metric", selection: $selectedMetric) {
            ForEach(ProgressMetric.allCases, id: \.self) { metric in
                Text(metric.rawValue).tag(metric)
            }
        }
        .pickerStyle(.segmented)
        .tint(RQColors.accent)
    }

    // MARK: - Trend Chart

    private var trendChart: some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.md) {
                if snapshots.count >= 2 {
                    Chart(snapshots) { snapshot in
                        LineMark(
                            x: .value("Date", snapshot.date),
                            y: .value(selectedMetric.rawValue, metricValue(for: snapshot))
                        )
                        .foregroundStyle(RQColors.accent)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", snapshot.date),
                            y: .value(selectedMetric.rawValue, metricValue(for: snapshot))
                        )
                        .foregroundStyle(RQColors.accent)
                        .symbolSize(24)
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(chartDateLabel(date))
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
                                    Text(formatChartValue(val))
                                        .font(RQTypography.label)
                                        .foregroundStyle(RQColors.textTertiary)
                                }
                            }
                        }
                    }
                    .chartPlotStyle { plotArea in
                        plotArea.background(Color.clear)
                    }
                    .frame(height: 200)

                    // Trend summary
                    if let trend = trendSummary {
                        HStack(spacing: RQSpacing.xs) {
                            Image(systemName: trend.isPositive ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                            Text(trend.text)
                                .font(RQTypography.caption)
                        }
                        .foregroundColor(trend.isPositive ? RQColors.chartPositive : RQColors.chartNegative)
                    }
                } else if snapshots.count == 1 {
                    VStack(spacing: RQSpacing.md) {
                        Text("1 session recorded")
                            .font(RQTypography.headline)
                            .foregroundColor(RQColors.textPrimary)
                        Text("Complete more sessions to see trends")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    Text("No data for this exercise yet")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
        }
    }

    // MARK: - PR Section

    private var prSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            HStack {
                Text("PERSONAL RECORDS")
                    .font(RQTypography.label)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(RQColors.textSecondary)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: RQSpacing.md) {
                ForEach(currentPRs) { pr in
                    RQCard {
                        VStack(spacing: RQSpacing.sm) {
                            Text(pr.recordType.displayName.uppercased())
                                .font(RQTypography.label)
                                .tracking(0.5)
                                .foregroundColor(prColor(pr.recordType))

                            Text(prValueFormatted(pr))
                                .font(RQTypography.numbers)
                                .foregroundColor(RQColors.textPrimary)

                            Text(prDateFormatted(pr.achievedAt))
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - Recent Sessions

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            HStack {
                Text("RECENT SESSIONS")
                    .font(RQTypography.label)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(RQColors.textSecondary)
                Spacer()
            }

            ForEach(snapshots.suffix(5).reversed()) { snapshot in
                RQCard {
                    HStack {
                        VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                            Text(sessionDateFormatted(snapshot.date))
                                .font(RQTypography.headline)
                                .foregroundColor(RQColors.textPrimary)
                            HStack(spacing: RQSpacing.sm) {
                                Text("\(snapshot.setCount) sets")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                                Text("\u{00B7}")
                                    .foregroundColor(RQColors.textTertiary)
                                Text("\(formatWeight(snapshot.bestWeight)) lbs x \(snapshot.bestReps)")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: RQSpacing.xxs) {
                            Text(formatVolumeCompact(snapshot.totalVolume))
                                .font(RQTypography.numbersSmall)
                                .foregroundColor(RQColors.accent)
                            Text("volume")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func metricValue(for snapshot: ExerciseSessionSnapshot) -> Double {
        switch selectedMetric {
        case .weight: return snapshot.bestWeight
        case .volume: return snapshot.totalVolume
        case .estimated1rm: return snapshot.estimated1RM
        case .rpe: return snapshot.avgRPE ?? 0
        }
    }

    private var trendSummary: (text: String, isPositive: Bool)? {
        guard snapshots.count >= 2 else { return nil }
        let recent = snapshots.suffix(3)
        let older = snapshots.prefix(max(1, snapshots.count - 3))

        let recentAvg = recent.map { metricValue(for: $0) }.reduce(0, +) / Double(recent.count)
        let olderAvg = older.map { metricValue(for: $0) }.reduce(0, +) / Double(older.count)

        guard olderAvg > 0 else { return nil }
        let change = ((recentAvg - olderAvg) / olderAvg) * 100

        let metricName = selectedMetric.rawValue.lowercased()
        let isPositive = selectedMetric == .rpe ? change < 0 : change > 0
        return (text: String(format: "%+.1f%% %@ over time", change, metricName), isPositive: isPositive)
    }

    private func formatChartValue(_ value: Double) -> String {
        if selectedMetric == .rpe {
            return String(format: "%.1f", value)
        }
        if value >= 1_000 {
            return String(format: "%.0fK", value / 1_000)
        }
        return String(format: "%.0f", value)
    }

    private func chartDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func prColor(_ type: RecordType) -> Color {
        switch type {
        case .weight: return RQColors.accent
        case .reps: return RQColors.success
        case .volume: return RQColors.hypertrophy
        case .estimated1rm: return RQColors.strength
        }
    }

    private func prValueFormatted(_ pr: PersonalRecord) -> String {
        switch pr.recordType {
        case .weight: return "\(formatWeight(pr.value)) lbs"
        case .reps: return "\(Int(pr.value))"
        case .volume: return formatVolumeCompact(pr.value)
        case .estimated1rm: return "\(formatWeight(pr.value)) lbs"
        }
    }

    private func prDateFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func sessionDateFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }

    private func formatVolumeCompact(_ volume: Double) -> String {
        if volume >= 1_000 {
            return String(format: "%.1fK", volume / 1_000)
        }
        return String(format: "%.0f", volume)
    }

    private func loadData() async {
        isLoading = true
        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                isLoading = false
                return
            }

            async let historyTask = analyticsService.fetchExerciseHistory(userId: userId, exerciseId: exercise.id)
            async let prTask = progressionService.fetchCurrentPRs(userId: userId, exerciseId: exercise.id)

            snapshots = try await historyTask
            currentPRs = try await prTask
        } catch {
            // Silently handle
        }
        isLoading = false
    }
}
