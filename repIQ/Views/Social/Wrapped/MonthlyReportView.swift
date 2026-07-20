import SwiftUI
import Charts
import Supabase

/// Structured monthly training report — same schema every month so it can
/// be scanned, compared month-over-month, and eventually placed side by
/// side in a comparison view. Pushed from the archetype slide of the
/// Wrapped story flow.
///
/// Uses RQTypography + RQColors throughout to stay visually coherent with
/// the rest of the app. Sections (in order):
/// 1. Header — month + archetype + one-line summary
/// 2. Vitals grid — workouts / volume / sets / PRs / streak / avg duration
///    each with a month-over-month delta when prior data is available
/// 3. Top 3 lifts — by total volume in the month
/// 4. Volume by muscle group — horizontal bar chart
/// 5. Days trained — calendar heatmap of the month
/// 6. Personal records — full list of PRs achieved in the month
/// 7. Archetype rationale — short explanation of why this archetype was picked
struct MonthlyReportView: View {
    let wrapped: RepSheet

    @State private var payload: DigestService.ReportPayload?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showComparePicker = false
    @State private var compareTarget: RepSheet?

    private let service = DigestService()

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xl) {
                if isLoading {
                    ProgressView()
                        .tint(RQColors.accent)
                        .padding(.top, RQSpacing.xxxl)
                } else if let payload {
                    headerSection(payload)
                    vitalsSection(payload)
                    topLiftsSection(payload)
                    muscleVolumeSection(payload)
                    daysTrainedSection(payload)
                    prsSection(payload)
                    archetypeRationaleSection(payload)
                } else {
                    errorState
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.top, RQSpacing.lg)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .background(RQColors.background)
        .navigationTitle(monthLabel(wrapped.monthStart) + " Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showComparePicker = true
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(RQColors.accent)
                }
                .accessibilityLabel("Compare to another month")
            }
        }
        .sheet(isPresented: $showComparePicker) {
            ComparePickerSheet(currentWrappedId: wrapped.id) { selected in
                showComparePicker = false
                compareTarget = selected
            }
        }
        .navigationDestination(item: $compareTarget) { other in
            MonthlyComparisonView(primary: wrapped, secondary: other)
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            payload = try await service.fetchReportPayload(for: wrapped)
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
            Text("Couldn't load the report")
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

    // MARK: - Sections

    private func headerSection(_ p: DigestService.ReportPayload) -> some View {
        let archetype = WrappedArchetype(rawValue: p.current.archetype ?? "") ?? .steadyBuilder
        return VStack(alignment: .leading, spacing: RQSpacing.md) {
            HStack(spacing: RQSpacing.md) {
                Image(systemName: archetype.systemImageName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(RQColors.accent)
                    .frame(width: 48, height: 48)
                    .background(RQColors.accent.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(monthLabel(p.current.monthStart).uppercased())
                        .font(RQTypography.label)
                        .tracking(2)
                        .foregroundColor(RQColors.textSecondary)
                    Text(archetype.displayName)
                        .font(RQTypography.title2)
                        .foregroundColor(RQColors.textPrimary)
                }
                Spacer()
            }

            Text(headlineSummary(for: p))
                .font(RQTypography.body)
                .foregroundColor(RQColors.textSecondary)
        }
    }

    private func vitalsSection(_ p: DigestService.ReportPayload) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeader("Vitals")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: RQSpacing.md), GridItem(.flexible(), spacing: RQSpacing.md)],
                spacing: RQSpacing.md
            ) {
                vitalCard(
                    label: "WORKOUTS",
                    value: "\(p.current.totalSessions)",
                    delta: delta(p.current.totalSessions, p.prior?.totalSessions)
                )
                vitalCard(
                    label: "TOTAL VOLUME",
                    value: formatVolume(p.current.totalVolume) + " lbs",
                    delta: delta(p.current.totalVolume, p.prior?.totalVolume, format: .volume)
                )
                vitalCard(
                    label: "WORKING SETS",
                    value: "\(p.current.totalSets)",
                    delta: delta(p.current.totalSets, p.prior?.totalSets)
                )
                vitalCard(
                    label: "PERSONAL RECORDS",
                    value: "\(p.current.totalPRs)",
                    delta: delta(p.current.totalPRs, p.prior?.totalPRs)
                )
                vitalCard(
                    label: "LONGEST STREAK",
                    value: "\(p.current.longestStreak) days",
                    delta: delta(p.current.longestStreak, p.prior?.longestStreak)
                )
                vitalCard(
                    label: "AVG DURATION",
                    value: formatDuration(p.current.avgSessionDuration ?? 0),
                    delta: deltaSeconds(p.current.avgSessionDuration, p.prior?.avgSessionDuration)
                )
            }
        }
    }

    private func topLiftsSection(_ p: DigestService.ReportPayload) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeader("Top Lifts by Volume")

            if p.topLifts.isEmpty {
                emptyRow("No working sets logged this month.")
            } else {
                VStack(spacing: RQSpacing.sm) {
                    ForEach(Array(p.topLifts.enumerated()), id: \.offset) { idx, lift in
                        topLiftRow(rank: idx + 1, lift: lift)
                    }
                }
            }
        }
    }

    private func muscleVolumeSection(_ p: DigestService.ReportPayload) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeader("Volume by Muscle Group")

            if p.muscleGroupVolume.isEmpty {
                emptyRow("No muscle data this month.")
            } else {
                RQCard {
                    Chart(p.muscleGroupVolume, id: \.muscle) { item in
                        BarMark(
                            x: .value("Volume", item.volume),
                            y: .value("Muscle", item.muscle.capitalized)
                        )
                        .foregroundStyle(muscleColor(item.muscle))
                        .cornerRadius(2)
                        .annotation(position: .trailing, alignment: .leading, spacing: 6) {
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
                    .frame(height: max(CGFloat(p.muscleGroupVolume.count) * 26 + 16, 120))
                }
            }
        }
    }

    private func daysTrainedSection(_ p: DigestService.ReportPayload) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeader("Days Trained")

            RQCard {
                VStack(spacing: RQSpacing.md) {
                    monthCalendarGrid(month: p.current.monthStart, trainedDates: p.trainedDates)

                    HStack {
                        Text("\(p.trainedDates.count) day\(p.trainedDates.count == 1 ? "" : "s") trained")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                        Spacer()
                        if let prior = p.prior {
                            Text(deltaSessionsLabel(p.current.totalSessions, prior.totalSessions))
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }
                    }
                }
            }
        }
    }

    private func prsSection(_ p: DigestService.ReportPayload) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeader("Personal Records (\(p.personalRecords.count))")

            if p.personalRecords.isEmpty {
                emptyRow("No PRs this month — plateaus are part of the work.")
            } else {
                VStack(spacing: RQSpacing.sm) {
                    ForEach(Array(p.personalRecords.enumerated()), id: \.offset) { _, pr in
                        prRow(pr)
                    }
                }
            }
        }
    }

    private func archetypeRationaleSection(_ p: DigestService.ReportPayload) -> some View {
        let archetype = WrappedArchetype(rawValue: p.current.archetype ?? "") ?? .steadyBuilder
        let avgVolume = p.current.totalSessions > 0
            ? p.current.totalVolume / Double(p.current.totalSessions)
            : 0

        let rationale: String = {
            switch archetype {
            case .prHunter:
                return "You hit \(p.current.totalPRs) PRs across \(p.current.totalSessions) sessions — roughly \(String(format: "%.1f", Double(p.current.totalPRs) / Double(max(p.current.totalSessions, 1)))) PRs per session. That high a strike rate is what triggered the PR Hunter archetype."
            case .volumeHammer:
                return "You averaged \(formatVolume(avgVolume)) lbs per session. That's well past the 15,000-lb threshold for the Volume Hammer archetype — you came to put in real work."
            case .consistencyKing:
                if p.current.longestStreak >= 14 {
                    return "Your longest streak this month was \(p.current.longestStreak) consecutive days. Showing up that consistently is what triggered the Consistency King archetype."
                } else {
                    return "You logged \(p.current.totalSessions) sessions this month — roughly \(String(format: "%.1f", Double(p.current.totalSessions) / 4.3))×/week. That cadence is what triggered the Consistency King archetype."
                }
            case .varietySeeker:
                return "You worked across a broad pool of exercises this month. The high per-session variety is what triggered the Variety Seeker archetype."
            case .steadyBuilder:
                return "Steady, sustainable training across \(p.current.totalSessions) sessions. No archetype spike — the kind of foundation month long-term progress is built on."
            }
        }()

        return VStack(alignment: .leading, spacing: RQSpacing.md) {
            sectionHeader("Why \(archetype.displayName)?")

            RQCard {
                Text(rationale)
                    .font(RQTypography.body)
                    .foregroundColor(RQColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(RQTypography.label)
            .tracking(1.5)
            .foregroundColor(RQColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func vitalCard(label: String, value: String, delta: DeltaDescriptor?) -> some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.xs) {
                Text(label)
                    .font(RQTypography.label)
                    .tracking(1.2)
                    .foregroundColor(RQColors.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(value)
                    .font(RQTypography.numbers)
                    .foregroundColor(RQColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let delta {
                    HStack(spacing: 2) {
                        Image(systemName: delta.icon)
                            .font(.system(size: 9, weight: .bold))
                        Text(delta.text)
                            .font(RQTypography.caption)
                    }
                    .foregroundColor(delta.color)
                } else {
                    Text("—")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func topLiftRow(rank: Int, lift: DigestService.ReportPayload.TopLift) -> some View {
        RQCard {
            HStack(spacing: RQSpacing.md) {
                Text("\(rank)")
                    .font(RQTypography.numbersSmall)
                    .foregroundColor(RQColors.accent)
                    .frame(width: 28, height: 28)
                    .background(RQColors.accent.opacity(0.12), in: Circle())

                Text(lift.exerciseName)
                    .font(RQTypography.body)
                    .foregroundColor(RQColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(formatVolume(lift.totalVolume) + " lbs")
                    .font(RQTypography.numbersSmall)
                    .foregroundColor(RQColors.textPrimary)
            }
        }
    }

    private func prRow(_ pr: DigestService.ReportPayload.PRDetail) -> some View {
        RQCard {
            HStack(spacing: RQSpacing.md) {
                Image(systemName: prIcon(pr.recordType))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(RQColors.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pr.exerciseName)
                        .font(RQTypography.body)
                        .foregroundColor(RQColors.textPrimary)
                        .lineLimit(1)
                    Text(prSubtitle(pr))
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }

                Spacer()

                Text(prValueDisplay(pr))
                    .font(RQTypography.numbersSmall)
                    .foregroundColor(RQColors.accent)
            }
        }
    }

    private func emptyRow(_ message: String) -> some View {
        RQCard {
            Text(message)
                .font(RQTypography.caption)
                .foregroundColor(RQColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func monthCalendarGrid(month: Date, trainedDates: Set<Date>) -> some View {
        let calendar = Calendar.current
        let dayHeaders = ["S", "M", "T", "W", "T", "F", "S"]
        let days = calendarDays(for: month)

        return VStack(spacing: RQSpacing.xs) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(dayHeaders[i])
                        .font(RQTypography.label)
                        .foregroundColor(RQColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: RQSpacing.xs) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let isTrainingDay = trainedDates.contains(calendar.startOfDay(for: date))
                        let dayNum = calendar.component(.day, from: date)

                        Text("\(dayNum)")
                            .font(RQTypography.caption)
                            .foregroundColor(isTrainingDay ? RQColors.accent : RQColors.textTertiary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(isTrainingDay ? RQColors.accent.opacity(0.18) : Color.clear)
                            )
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("")
                            .frame(width: 28, height: 28)
                            .frame(maxWidth: .infinity)
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
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1 // 0=Sun
        var out: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                out.append(date)
            }
        }
        return out
    }

    // MARK: - Deltas

    private struct DeltaDescriptor {
        let text: String
        let color: Color
        let icon: String
    }

    private func delta(_ current: Int, _ prior: Int?) -> DeltaDescriptor? {
        guard let prior else { return nil }
        let diff = current - prior
        return makeDelta(absolute: Double(diff), display: "\(abs(diff))")
    }

    private enum DeltaDisplayKind {
        case raw
        case volume
    }

    private func delta(_ current: Double, _ prior: Double?, format: DeltaDisplayKind = .raw) -> DeltaDescriptor? {
        guard let prior else { return nil }
        let diff = current - prior
        let display: String
        switch format {
        case .raw:
            display = String(format: "%.0f", abs(diff))
        case .volume:
            display = formatVolume(abs(diff))
        }
        return makeDelta(absolute: diff, display: display)
    }

    private func deltaSeconds(_ current: Int?, _ prior: Int?) -> DeltaDescriptor? {
        guard let current, let prior else { return nil }
        let diff = current - prior
        let absMin = abs(diff) / 60
        return makeDelta(absolute: Double(diff), display: "\(absMin)m")
    }

    private func makeDelta(absolute diff: Double, display: String) -> DeltaDescriptor {
        if diff > 0 {
            return DeltaDescriptor(text: "+\(display) vs last month", color: RQColors.success, icon: "arrow.up")
        }
        if diff < 0 {
            return DeltaDescriptor(text: "-\(display) vs last month", color: RQColors.error, icon: "arrow.down")
        }
        return DeltaDescriptor(text: "Unchanged", color: RQColors.textTertiary, icon: "equal")
    }

    private func deltaSessionsLabel(_ current: Int, _ prior: Int) -> String {
        let diff = current - prior
        if diff > 0 { return "+\(diff) vs last month" }
        if diff < 0 { return "\(diff) vs last month" }
        return "Same as last month"
    }

    // MARK: - Headline summary

    private func headlineSummary(for p: DigestService.ReportPayload) -> String {
        let sessions = p.current.totalSessions
        let prs = p.current.totalPRs
        if sessions == 0 {
            return "A quiet month. The next breakthrough comes after the longest pause."
        }
        let prsPart: String
        if prs == 0 {
            prsPart = "no new PRs"
        } else if prs == 1 {
            prsPart = "1 new PR"
        } else {
            prsPart = "\(prs) new PRs"
        }
        return "\(sessions) workout\(sessions == 1 ? "" : "s") this month, \(prsPart), and \(formatVolume(p.current.totalVolume)) lbs of total volume."
    }

    // MARK: - Helpers

    private func muscleColor(_ muscle: String) -> Color {
        RQColors.muscleGroupColors[muscle.lowercased()] ?? RQColors.accent
    }

    private func prIcon(_ recordType: String) -> String {
        switch recordType {
        case "weight": return "scalemass.fill"
        case "estimated_1rm": return "chart.line.uptrend.xyaxis"
        case "reps": return "repeat"
        case "volume": return "sum"
        default: return "trophy.fill"
        }
    }

    private func prSubtitle(_ pr: DigestService.ReportPayload.PRDetail) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let date = f.string(from: pr.achievedAt)
        switch pr.recordType {
        case "weight": return "Weight PR · \(date)"
        case "estimated_1rm": return "Est. 1RM PR · \(date)"
        case "reps": return "Reps PR · \(date)"
        case "volume": return "Volume PR · \(date)"
        default: return date
        }
    }

    private func prValueDisplay(_ pr: DigestService.ReportPayload.PRDetail) -> String {
        let valueStr = pr.value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", pr.value)
            : String(format: "%.1f", pr.value)
        switch pr.recordType {
        case "weight", "estimated_1rm":
            if let reps = pr.repsAtWeight, reps > 0 {
                return "\(valueStr) × \(reps)"
            }
            return "\(valueStr) lbs"
        case "reps":
            return "\(Int(pr.value)) reps"
        default:
            return valueStr
        }
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
}

// MARK: - Compare Picker Sheet

/// Sheet that lets the user pick a prior month's wrapped to compare
/// against. Fetches the user's wrapped history on appear and excludes the
/// month they're already viewing.
private struct ComparePickerSheet: View {
    let currentWrappedId: UUID
    var onSelect: (RepSheet) -> Void

    @State private var options: [RepSheet] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    private let service = DigestService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack {
                        ProgressView().tint(RQColors.accent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if options.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: RQSpacing.md) {
                            ForEach(options) { option in
                                Button { onSelect(option) } label: {
                                    rowFor(option)
                                }
                            }
                        }
                        .padding(.horizontal, RQSpacing.screenHorizontal)
                        .padding(.top, RQSpacing.lg)
                    }
                }
            }
            .background(RQColors.background)
            .navigationTitle("Compare to…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(RQColors.textSecondary)
                }
            }
            .task { await load() }
        }
        .preferredColorScheme(.dark)
    }

    private func rowFor(_ option: RepSheet) -> some View {
        RQCard {
            HStack(spacing: RQSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(monthLabel(option.monthStart))
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)
                    HStack(spacing: RQSpacing.md) {
                        Label("\(option.totalSessions)", systemImage: "figure.strengthtraining.traditional")
                        Label("\(option.totalPRs)", systemImage: "trophy.fill")
                    }
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(RQColors.accent)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: RQSpacing.md) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 32))
                .foregroundColor(RQColors.textTertiary)
            Text("No other months yet")
                .font(RQTypography.headline)
                .foregroundColor(RQColors.textPrimary)
            Text("You'll be able to compare once you have at least two months of training logged.")
                .font(RQTypography.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(RQColors.textTertiary)
                .padding(.horizontal, RQSpacing.xl)
            if let errorMessage {
                Text(errorMessage)
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.error)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            errorMessage = "Not signed in."
            isLoading = false
            return
        }
        do {
            let history = try await service.fetchWrappedHistory(userId: userId)
            options = history.filter { $0.id != currentWrappedId }
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        isLoading = false
    }

    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}
