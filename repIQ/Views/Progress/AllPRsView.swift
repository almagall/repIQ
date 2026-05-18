import SwiftUI
import Supabase

/// A scrollable list of every personal record the user has ever set, grouped
/// by relative time (this week, last week, this month, earlier). Reached from
/// the "VIEW ALL" link in the Progress tab's Recent PRs section.
struct AllPRsView: View {
    @State private var entries: [RecentPREntry] = []
    @State private var isLoading = true
    private let analyticsService = AnalyticsService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RQSpacing.xl) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if entries.isEmpty {
                    EmptyStateView(
                        icon: "star",
                        title: "No PRs Yet",
                        message: "Log workouts to start setting personal records."
                    )
                } else {
                    ForEach(groupedEntries, id: \.title) { group in
                        VStack(alignment: .leading, spacing: RQSpacing.md) {
                            RQSectionHeader(title: "\(group.title) · \(group.entries.count)")
                            RQCard {
                                VStack(spacing: 0) {
                                    ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                                        prRow(entry)
                                        if index < group.entries.count - 1 {
                                            Divider().background(RQColors.surfaceTertiary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.top, RQSpacing.lg)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .background(RQColors.background)
        .navigationTitle("All PRs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
    }

    private func prRow(_ entry: RecentPREntry) -> some View {
        let row = HStack(alignment: .center, spacing: RQSpacing.md) {
            Image(systemName: prIcon(entry.record.recordType))
                .font(.system(size: 12))
                .foregroundColor(prColor(entry.record.recordType))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.exerciseName)
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)
                    .lineLimit(1)
                Text(entry.record.recordType.displayName.uppercased())
                    .font(RQTypography.label)
                    .tracking(0.5)
                    .foregroundColor(RQColors.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(prValueFormatted(entry.record))
                    .font(RQTypography.numbersSmall)
                    .foregroundColor(RQColors.textPrimary)
                if let deltaLabel = prDeltaLabel(entry: entry) {
                    Text(deltaLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(RQColors.success)
                } else {
                    Text(relativeDateString(entry.record.achievedAt))
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }
            }
        }
        .padding(.vertical, RQSpacing.sm)

        if let sessionId = entry.record.sessionId {
            return AnyView(NavigationLink(value: sessionId) { row }.buttonStyle(.plain))
        } else {
            return AnyView(row)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let userId = try? await supabase.auth.session.user.id else {
            entries = []
            return
        }
        entries = (try? await analyticsService.fetchRecentPRs(userId: userId, limit: 1000)) ?? []
    }

    // MARK: - Grouping

    private struct Group {
        let title: String
        let entries: [RecentPREntry]
    }

    private var groupedEntries: [Group] {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
              let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart),
              let monthStart = calendar.dateInterval(of: .month, for: now)?.start
        else {
            return [Group(title: "ALL", entries: entries)]
        }

        var thisWeek: [RecentPREntry] = []
        var lastWeek: [RecentPREntry] = []
        var thisMonth: [RecentPREntry] = []
        var earlier: [RecentPREntry] = []

        for entry in entries {
            let date = entry.record.achievedAt
            if date >= weekStart { thisWeek.append(entry) }
            else if date >= lastWeekStart { lastWeek.append(entry) }
            else if date >= monthStart { thisMonth.append(entry) }
            else { earlier.append(entry) }
        }

        var groups: [Group] = []
        if !thisWeek.isEmpty { groups.append(Group(title: "THIS WEEK", entries: thisWeek)) }
        if !lastWeek.isEmpty { groups.append(Group(title: "LAST WEEK", entries: lastWeek)) }
        if !thisMonth.isEmpty { groups.append(Group(title: "THIS MONTH", entries: thisMonth)) }
        if !earlier.isEmpty { groups.append(Group(title: "EARLIER", entries: earlier)) }
        return groups
    }

    // MARK: - Helpers

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
        case .weight: return "\(formatWeight(record.value)) lbs"
        case .reps: return "\(Int(record.value)) reps"
        case .volume: return formatVolumeCompact(record.value)
        case .estimated1rm: return "\(formatWeight(record.value)) lbs"
        }
    }

    private func prDeltaLabel(entry: RecentPREntry) -> String? {
        guard let delta = entry.delta, delta > 0 else { return nil }
        switch entry.record.recordType {
        case .weight, .estimated1rm: return "+\(formatWeight(delta)) lbs"
        case .reps: return "+\(Int(delta.rounded())) reps"
        case .volume: return "+\(formatVolumeCompact(delta))"
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }

    private func formatVolumeCompact(_ volume: Double) -> String {
        if volume >= 1_000_000 { return String(format: "%.1fM", volume / 1_000_000) }
        if volume >= 1_000 { return String(format: "%.1fK", volume / 1_000) }
        return String(format: "%.0f", volume)
    }

    private func relativeDateString(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days)d ago" }
        if days < 30 { return "\(days / 7)w ago" }
        return "\(days / 30)mo ago"
    }
}
