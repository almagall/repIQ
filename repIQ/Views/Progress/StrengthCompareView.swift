import SwiftUI
import Charts
import Supabase

/// Multi-select overlay view that lets the user pick 2-3 of their top lifts
/// and see their e1RM curves on a single chart. Curves are normalized to
/// each lift's starting e1RM (% change vs. first snapshot) so lifts at very
/// different absolute weights remain visually comparable.
struct StrengthCompareView: View {
    let topLifts: [TopLiftTrajectory]
    @State private var selectedIds: Set<UUID> = []
    @State private var snapshotsByExercise: [UUID: [ExerciseSessionSnapshot]] = [:]
    @State private var isLoading = false
    private let analyticsService = AnalyticsService()

    private let palette: [Color] = [.cyan, .pink, .yellow]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RQSpacing.xl) {
                instructions

                chips

                if selectedIds.count >= 1 {
                    chartCard
                }

                summaryTable
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.top, RQSpacing.lg)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .background(RQColors.background)
        .navigationTitle("Compare Lifts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            // Pre-select the user's top two lifts so the chart isn't empty
            // on first load.
            if selectedIds.isEmpty {
                selectedIds = Set(topLifts.prefix(2).map(\.exerciseId))
            }
            await loadSnapshots()
        }
    }

    private var instructions: some View {
        Text("Pick up to 3 lifts. Curves are normalized to each lift's starting e1RM so different magnitudes remain comparable.")
            .font(RQTypography.caption)
            .foregroundColor(RQColors.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var chips: some View {
        FlowLayout(spacing: RQSpacing.xs) {
            ForEach(topLifts) { lift in
                let isSelected = selectedIds.contains(lift.exerciseId)
                let colorIndex = orderedIds.firstIndex(of: lift.exerciseId) ?? 0
                let chipColor = isSelected ? palette[colorIndex % palette.count] : RQColors.textTertiary

                Button {
                    toggle(lift.exerciseId)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 11))
                        Text(lift.exerciseName)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(chipColor)
                    .padding(.horizontal, RQSpacing.sm)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: RQRadius.small)
                            .stroke(chipColor.opacity(0.6), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!isSelected && selectedIds.count >= 3)
                .opacity(!isSelected && selectedIds.count >= 3 ? 0.4 : 1.0)
            }
        }
    }

    private var orderedIds: [UUID] {
        topLifts.map(\.exerciseId).filter { selectedIds.contains($0) }
    }

    @ViewBuilder
    private var chartCard: some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.md) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    overlayChart
                    chartLegend
                }
            }
        }
    }

    private var overlayChart: some View {
        Chart {
            ForEach(Array(orderedIds.enumerated()), id: \.element) { index, id in
                if let snaps = snapshotsByExercise[id], let first = snaps.first, first.estimated1RM > 0 {
                    let lift = topLifts.first(where: { $0.exerciseId == id })
                    ForEach(snaps, id: \.id) { snap in
                        let pct = (snap.estimated1RM - first.estimated1RM) / first.estimated1RM * 100
                        LineMark(
                            x: .value("Date", snap.date),
                            y: .value("% change", pct)
                        )
                        .foregroundStyle(by: .value("Lift", lift?.exerciseName ?? "Lift"))
                        .interpolationMethod(.monotone)
                    }
                }
            }

            RuleMark(y: .value("Baseline", 0))
                .foregroundStyle(RQColors.textTertiary.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
        }
        .chartForegroundStyleScale(range: Array(palette.prefix(orderedIds.count)))
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 1)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(monthLabel(date))
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
                        Text("\(Int(val))%")
                            .font(RQTypography.label)
                            .foregroundStyle(RQColors.textTertiary)
                    }
                }
            }
        }
        .frame(height: 220)
    }

    private var chartLegend: some View {
        HStack(spacing: RQSpacing.md) {
            ForEach(Array(orderedIds.enumerated()), id: \.element) { index, id in
                if let lift = topLifts.first(where: { $0.exerciseId == id }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(palette[index % palette.count])
                            .frame(width: 8, height: 8)
                        Text(lift.exerciseName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(RQColors.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var summaryTable: some View {
        if !orderedIds.isEmpty {
            VStack(alignment: .leading, spacing: RQSpacing.md) {
                RQSectionHeader(title: "ABSOLUTE")
                RQCard {
                    VStack(spacing: 0) {
                        ForEach(Array(orderedIds.enumerated()), id: \.element) { index, id in
                            if let lift = topLifts.first(where: { $0.exerciseId == id }) {
                                summaryRow(lift: lift, color: palette[index % palette.count])
                                if index < orderedIds.count - 1 {
                                    Divider().background(RQColors.surfaceTertiary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func summaryRow(lift: TopLiftTrajectory, color: Color) -> some View {
        HStack(spacing: RQSpacing.md) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(lift.exerciseName)
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)
                    .lineLimit(1)
                Text(lift.narrative)
                    .font(.system(size: 11))
                    .foregroundColor(RQColors.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(lift.currentE1RM.rounded())) lb")
                    .font(RQTypography.numbersSmall)
                    .foregroundColor(RQColors.textPrimary)
                if abs(lift.fourWeekDelta) >= 1 {
                    Text(String(format: "%@%.0f lb · 4wk",
                                lift.fourWeekDelta >= 0 ? "+" : "−",
                                abs(lift.fourWeekDelta)))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(lift.fourWeekDelta >= 0 ? RQColors.success : RQColors.warning)
                }
            }
        }
        .padding(.vertical, RQSpacing.sm)
    }

    private func toggle(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            guard selectedIds.count < 3 else { return }
            selectedIds.insert(id)
            Task { await loadSnapshots() }
        }
    }

    private func loadSnapshots() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        isLoading = true
        defer { isLoading = false }

        var newMap = snapshotsByExercise
        for id in selectedIds where newMap[id] == nil {
            if let snaps = try? await analyticsService.fetchExerciseHistory(userId: userId, exerciseId: id) {
                newMap[id] = snaps
            }
        }
        snapshotsByExercise = newMap
    }

    private func monthLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
}

// MARK: - Flow Layout

/// Minimal wrapping HStack for chip lists. Identical to the one used in
/// MuscleHeatmapView but namespaced here to avoid cross-file private access.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxY: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxY = y + rowHeight
        }
        return CGSize(width: width, height: maxY)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
