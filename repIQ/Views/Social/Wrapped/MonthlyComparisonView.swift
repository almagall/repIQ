import SwiftUI
import Charts

/// Side-by-side month comparison. Loads each month's full report payload
/// in parallel, then renders matching sections in a two-column layout.
/// Reached from `MonthlyReportView` via the "Compare" toolbar button.
///
/// Phone-screen-friendly layout choices:
/// - Vitals are stacked one-per-row with both values + delta arrow on a
///   single line (tighter than a 2×N grid which makes labels truncate)
/// - Top lifts show two short columns side-by-side
/// - Volume bar charts use a small fixed height each, stacked vertically
///   under their month label, so muscle group labels stay readable
/// - Days-trained calendars compress to a small grid in each column
/// - Archetype cards sit side by side at the top so the comparison
///   reveals the personality difference first
struct MonthlyComparisonView: View {
    let primary: RepSheet
    let secondary: RepSheet

    @State private var primaryPayload: DigestService.ReportPayload?
    @State private var secondaryPayload: DigestService.ReportPayload?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let service = DigestService()

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xl) {
                if isLoading {
                    ProgressView()
                        .tint(RQColors.accent)
                        .padding(.top, RQSpacing.xxxl)
                } else if let p = primaryPayload, let s = secondaryPayload {
                    monthHeader(primary: p.current, secondary: s.current)
                    archetypesRow(primary: p, secondary: s)
                    vitalsSection(primary: p, secondary: s)
                    topLiftsSection(primary: p, secondary: s)
                    volumeByMuscleSection(primary: p, secondary: s)
                    daysTrainedSection(primary: p, secondary: s)
                    prsSummaryRow(primary: p, secondary: s)
                } else {
                    errorState
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.top, RQSpacing.lg)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .background(RQColors.background)
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let primaryTask = service.fetchReportPayload(for: primary)
            async let secondaryTask = service.fetchReportPayload(for: secondary)
            primaryPayload = try await primaryTask
            secondaryPayload = try await secondaryTask
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        isLoading = false
    }

    @ViewBuilder
    private var errorState: some View {
        VStack(spacing: RQSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(RQColors.warning)
            Text("Couldn't load the comparison")
                .font(RQTypography.headline)
                .foregroundColor(RQColors.textPrimary)
            if let errorMessage {
                Text(errorMessage)
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            Button("Try again") { Task { await load() } }
                .font(RQTypography.body)
                .foregroundColor(RQColors.accent)
        }
        .padding(.top, RQSpacing.xxxl)
    }

    // MARK: - Header

    private func monthHeader(primary: RepSheet, secondary: RepSheet) -> some View {
        HStack(spacing: RQSpacing.md) {
            monthHeaderCell(date: primary.monthStart, alignment: .leading)
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(RQColors.textTertiary)
            monthHeaderCell(date: secondary.monthStart, alignment: .trailing)
        }
    }

    private func monthHeaderCell(date: Date, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(monthLabelShort(date).uppercased())
                .font(RQTypography.label)
                .tracking(2)
                .foregroundColor(RQColors.textSecondary)
            Text(monthLabel(date))
                .font(RQTypography.title3)
                .foregroundColor(RQColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    // MARK: - Archetype row

    private func archetypesRow(
        primary: DigestService.ReportPayload,
        secondary: DigestService.ReportPayload
    ) -> some View {
        let primaryArchetype = WrappedArchetype(rawValue: primary.current.archetype ?? "") ?? .steadyBuilder
        let secondaryArchetype = WrappedArchetype(rawValue: secondary.current.archetype ?? "") ?? .steadyBuilder
        return VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeader("Archetype")
            HStack(spacing: RQSpacing.md) {
                archetypeCard(archetype: primaryArchetype)
                archetypeCard(archetype: secondaryArchetype)
            }
        }
    }

    private func archetypeCard(archetype: WrappedArchetype) -> some View {
        RQCard {
            VStack(spacing: RQSpacing.sm) {
                Image(systemName: archetype.systemImageName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(RQColors.accent)
                Text(archetype.displayName)
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, RQSpacing.xs)
        }
    }

    // MARK: - Vitals (one row per metric)

    private func vitalsSection(
        primary: DigestService.ReportPayload,
        secondary: DigestService.ReportPayload
    ) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeader("Vitals")
            VStack(spacing: RQSpacing.sm) {
                vitalRow(
                    label: "Workouts",
                    primaryValue: "\(primary.current.totalSessions)",
                    secondaryValue: "\(secondary.current.totalSessions)",
                    delta: deltaInt(primary.current.totalSessions, secondary.current.totalSessions)
                )
                vitalRow(
                    label: "Total Volume",
                    primaryValue: formatVolume(primary.current.totalVolume) + " lbs",
                    secondaryValue: formatVolume(secondary.current.totalVolume) + " lbs",
                    delta: deltaDouble(primary.current.totalVolume, secondary.current.totalVolume, kind: .volume)
                )
                vitalRow(
                    label: "Working Sets",
                    primaryValue: "\(primary.current.totalSets)",
                    secondaryValue: "\(secondary.current.totalSets)",
                    delta: deltaInt(primary.current.totalSets, secondary.current.totalSets)
                )
                vitalRow(
                    label: "Personal Records",
                    primaryValue: "\(primary.current.totalPRs)",
                    secondaryValue: "\(secondary.current.totalPRs)",
                    delta: deltaInt(primary.current.totalPRs, secondary.current.totalPRs)
                )
                vitalRow(
                    label: "Longest Streak",
                    primaryValue: "\(primary.current.longestStreak) days",
                    secondaryValue: "\(secondary.current.longestStreak) days",
                    delta: deltaInt(primary.current.longestStreak, secondary.current.longestStreak)
                )
                vitalRow(
                    label: "Avg Duration",
                    primaryValue: formatDuration(primary.current.avgSessionDuration ?? 0),
                    secondaryValue: formatDuration(secondary.current.avgSessionDuration ?? 0),
                    delta: deltaDuration(primary.current.avgSessionDuration, secondary.current.avgSessionDuration)
                )
            }
        }
    }

    private func vitalRow(
        label: String,
        primaryValue: String,
        secondaryValue: String,
        delta: DeltaDescriptor?
    ) -> some View {
        RQCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(label.uppercased())
                    .font(RQTypography.label)
                    .tracking(1.2)
                    .foregroundColor(RQColors.textTertiary)

                HStack(spacing: RQSpacing.md) {
                    Text(primaryValue)
                        .font(RQTypography.numbersSmall)
                        .foregroundColor(RQColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    if let delta {
                        HStack(spacing: 4) {
                            Image(systemName: delta.icon)
                                .font(.system(size: 10, weight: .bold))
                            Text(delta.text)
                                .font(RQTypography.caption)
                                .lineLimit(1)
                        }
                        .foregroundColor(delta.color)
                    }

                    Text(secondaryValue)
                        .font(RQTypography.numbersSmall)
                        .foregroundColor(RQColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
    }

    // MARK: - Top lifts (two columns)

    private func topLiftsSection(
        primary: DigestService.ReportPayload,
        secondary: DigestService.ReportPayload
    ) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeader("Top Lifts by Volume")
            HStack(alignment: .top, spacing: RQSpacing.md) {
                topLiftsColumn(date: primary.current.monthStart, lifts: primary.topLifts)
                topLiftsColumn(date: secondary.current.monthStart, lifts: secondary.topLifts)
            }
        }
    }

    private func topLiftsColumn(date: Date, lifts: [DigestService.ReportPayload.TopLift]) -> some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                Text(monthLabelShort(date).uppercased())
                    .font(RQTypography.label)
                    .tracking(1.2)
                    .foregroundColor(RQColors.textSecondary)

                if lifts.isEmpty {
                    Text("No lifts logged.")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                } else {
                    ForEach(Array(lifts.enumerated()), id: \.offset) { _, lift in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lift.exerciseName)
                                .font(RQTypography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(RQColors.textPrimary)
                                .lineLimit(1)
                            Text(formatVolume(lift.totalVolume) + " lbs")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Volume by muscle

    private func volumeByMuscleSection(
        primary: DigestService.ReportPayload,
        secondary: DigestService.ReportPayload
    ) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeader("Volume by Muscle Group")
            VStack(spacing: RQSpacing.md) {
                muscleVolumeColumn(date: primary.current.monthStart, items: primary.muscleGroupVolume)
                muscleVolumeColumn(date: secondary.current.monthStart, items: secondary.muscleGroupVolume)
            }
        }
    }

    private func muscleVolumeColumn(
        date: Date,
        items: [(muscle: String, volume: Double)]
    ) -> some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                Text(monthLabelShort(date).uppercased())
                    .font(RQTypography.label)
                    .tracking(1.2)
                    .foregroundColor(RQColors.textSecondary)

                if items.isEmpty {
                    Text("No data.")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                } else {
                    Chart(items, id: \.muscle) { item in
                        BarMark(
                            x: .value("Volume", item.volume),
                            y: .value("Muscle", item.muscle.capitalized)
                        )
                        .foregroundStyle(muscleColor(item.muscle))
                        .cornerRadius(2)
                        .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                            Text(formatVolume(item.volume))
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textSecondary)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisValueLabel()
                                .foregroundStyle(RQColors.textSecondary)
                                .font(RQTypography.caption)
                        }
                    }
                    .frame(height: max(CGFloat(items.count) * 22 + 12, 100))
                }
            }
        }
    }

    // MARK: - Days trained (mini calendars side by side)

    private func daysTrainedSection(
        primary: DigestService.ReportPayload,
        secondary: DigestService.ReportPayload
    ) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeader("Days Trained")
            HStack(alignment: .top, spacing: RQSpacing.md) {
                daysTrainedColumn(payload: primary)
                daysTrainedColumn(payload: secondary)
            }
        }
    }

    private func daysTrainedColumn(payload: DigestService.ReportPayload) -> some View {
        RQCard {
            VStack(spacing: RQSpacing.sm) {
                HStack {
                    Text(monthLabelShort(payload.current.monthStart).uppercased())
                        .font(RQTypography.label)
                        .tracking(1.2)
                        .foregroundColor(RQColors.textSecondary)
                    Spacer()
                    Text("\(payload.trainedDates.count)d")
                        .font(RQTypography.numbersSmall)
                        .foregroundColor(RQColors.textPrimary)
                }
                miniCalendarGrid(month: payload.current.monthStart, trainedDates: payload.trainedDates)
            }
        }
    }

    private func miniCalendarGrid(month: Date, trainedDates: Set<Date>) -> some View {
        let calendar = Calendar.current
        let dayHeaders = ["S", "M", "T", "W", "T", "F", "S"]
        let days = calendarDays(for: month)
        let cellSize: CGFloat = 18

        return VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(dayHeaders[i])
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(RQColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 3) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let trained = trainedDates.contains(calendar.startOfDay(for: date))
                        Circle()
                            .fill(trained ? RQColors.accent : RQColors.surfaceTertiary)
                            .frame(width: cellSize, height: cellSize)
                            .frame(maxWidth: .infinity)
                    } else {
                        Color.clear.frame(width: cellSize, height: cellSize).frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func calendarDays(for month: Date) -> [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
        var out: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                out.append(date)
            }
        }
        return out
    }

    // MARK: - PR summary

    private func prsSummaryRow(
        primary: DigestService.ReportPayload,
        secondary: DigestService.ReportPayload
    ) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeader("Personal Records")
            RQCard {
                HStack(spacing: RQSpacing.md) {
                    prSummaryCell(date: primary.current.monthStart, count: primary.personalRecords.count, alignment: .leading)
                    Divider()
                        .frame(width: 1, height: 32)
                        .background(RQColors.surfaceTertiary)
                    prSummaryCell(date: secondary.current.monthStart, count: secondary.personalRecords.count, alignment: .trailing)
                }
            }
        }
    }

    private func prSummaryCell(date: Date, count: Int, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(monthLabelShort(date).uppercased())
                .font(RQTypography.label)
                .tracking(1.2)
                .foregroundColor(RQColors.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(count)")
                    .font(RQTypography.numbers)
                    .foregroundColor(RQColors.textPrimary)
                Text(count == 1 ? "PR" : "PRs")
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(RQTypography.label)
            .tracking(1.5)
            .foregroundColor(RQColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Deltas

    private struct DeltaDescriptor {
        let text: String
        let color: Color
        let icon: String
    }

    private enum DeltaKind {
        case raw
        case volume
    }

    private func deltaInt(_ a: Int, _ b: Int) -> DeltaDescriptor? {
        makeDelta(diff: Double(a - b), display: "\(abs(a - b))")
    }

    private func deltaDouble(_ a: Double, _ b: Double, kind: DeltaKind) -> DeltaDescriptor? {
        let diff = a - b
        let display: String
        switch kind {
        case .raw: display = String(format: "%.0f", abs(diff))
        case .volume: display = formatVolume(abs(diff))
        }
        return makeDelta(diff: diff, display: display)
    }

    private func deltaDuration(_ a: Int?, _ b: Int?) -> DeltaDescriptor? {
        guard let a, let b else { return nil }
        let diff = a - b
        return makeDelta(diff: Double(diff), display: "\(abs(diff) / 60)m")
    }

    private func makeDelta(diff: Double, display: String) -> DeltaDescriptor {
        if diff > 0 {
            return .init(text: "+\(display)", color: RQColors.success, icon: "arrow.up")
        }
        if diff < 0 {
            return .init(text: "-\(display)", color: RQColors.error, icon: "arrow.down")
        }
        return .init(text: "Equal", color: RQColors.textTertiary, icon: "equal")
    }

    // MARK: - Helpers

    private func muscleColor(_ muscle: String) -> Color {
        RQColors.muscleGroupColors[muscle.lowercased()] ?? RQColors.accent
    }

    private func formatVolume(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", value / 1_000) }
        return String(format: "%.0f", value)
    }

    private func formatDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "—" }
        let minutes = seconds / 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }

    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    private func monthLabelShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: date)
    }
}
