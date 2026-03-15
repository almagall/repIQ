import SwiftUI
import Supabase

/// A compact sparkline chart showing an exercise's best weight over the last 8 sessions.
struct ExerciseHistoryChart: View {
    let exerciseId: UUID
    @State private var snapshots: [ExerciseSessionSnapshot] = []
    @State private var isLoading = true

    private let analyticsService = AnalyticsService()

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(height: 40)
            } else if snapshots.count >= 2 {
                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    sparkline
                    HStack {
                        Text(formatWeight(snapshots.first?.bestWeight ?? 0))
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(RQColors.textTertiary)
                        Spacer()
                        Text(formatWeight(snapshots.last?.bestWeight ?? 0))
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(trendColor)
                    }
                }
            } else {
                Text("Not enough data")
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
                    .frame(height: 40)
            }
        }
        .task {
            await loadData()
        }
    }

    private var sparkline: some View {
        GeometryReader { geo in
            let weights = snapshots.map(\.bestWeight)
            let minW = weights.min() ?? 0
            let maxW = weights.max() ?? 1
            let range = max(maxW - minW, 1)

            Path { path in
                for (index, snapshot) in snapshots.enumerated() {
                    let x = geo.size.width * CGFloat(index) / CGFloat(max(snapshots.count - 1, 1))
                    let y = geo.size.height * (1 - CGFloat((snapshot.bestWeight - minW) / range))

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(trendColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            // Dot on most recent point
            if let last = snapshots.last {
                let x = geo.size.width
                let y = geo.size.height * (1 - CGFloat((last.bestWeight - minW) / range))
                Circle()
                    .fill(trendColor)
                    .frame(width: 5, height: 5)
                    .position(x: x, y: y)
            }
        }
        .frame(height: 32)
    }

    private var trendColor: Color {
        guard snapshots.count >= 2 else { return RQColors.accent }
        let first = snapshots.first?.bestWeight ?? 0
        let last = snapshots.last?.bestWeight ?? 0
        if last > first { return RQColors.success }
        if last < first { return RQColors.error }
        return RQColors.accent
    }

    private func loadData() async {
        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            snapshots = try await analyticsService.fetchExerciseHistory(userId: userId, exerciseId: exerciseId)
            // Take last 8 sessions
            if snapshots.count > 8 {
                snapshots = Array(snapshots.suffix(8))
            }
        } catch {}
        isLoading = false
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }
}

/// Inline mini-chart for template detail or exercise log views.
/// Shows a compact sparkline with a label.
struct ExerciseHistoryMiniCard: View {
    let exerciseId: UUID
    let exerciseName: String

    var body: some View {
        VStack(alignment: .leading, spacing: RQSpacing.xs) {
            Text("Recent Trend")
                .font(.system(size: 10, weight: .medium))
                .textCase(.uppercase)
                .foregroundColor(RQColors.textTertiary)

            ExerciseHistoryChart(exerciseId: exerciseId)
        }
        .padding(RQSpacing.sm)
        .background(RQColors.surfaceTertiary.opacity(0.5))
        .cornerRadius(RQRadius.small)
    }
}
