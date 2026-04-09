import SwiftUI

/// A compact 12-week GitHub-style activity heatmap showing daily workout presence.
/// Designed to be small enough to not require scrolling — 12 weeks wide × 7 days tall
/// with week labels at the bottom.
struct ConsistencyHeatmap: View {
    let dailyData: [(date: Date, count: Int)]

    // Number of weeks shown — matches fetchTrainingFrequency(weeks: 12)
    private let weekCount = 12
    private let cellSize: CGFloat = 10
    private let cellSpacing: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: RQSpacing.xs) {
            // Grid
            HStack(alignment: .top, spacing: cellSpacing) {
                // Day-of-week labels on the left
                VStack(alignment: .trailing, spacing: cellSpacing) {
                    Text("M")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(RQColors.textTertiary)
                        .frame(width: 10, height: cellSize)
                    Spacer().frame(height: cellSize)
                    Text("W")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(RQColors.textTertiary)
                        .frame(width: 10, height: cellSize)
                    Spacer().frame(height: cellSize)
                    Text("F")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(RQColors.textTertiary)
                        .frame(width: 10, height: cellSize)
                    Spacer().frame(height: cellSize * 2 + cellSpacing)
                }

                // Heatmap grid + week labels
                VStack(alignment: .leading, spacing: cellSpacing) {
                    // Rows: Mon - Sun (7 rows)
                    ForEach(0..<7, id: \.self) { dayOfWeek in
                        HStack(spacing: cellSpacing) {
                            ForEach(0..<weekCount, id: \.self) { weekIdx in
                                dayCell(weekIdx: weekIdx, dayOfWeek: dayOfWeek)
                            }
                        }
                    }

                    // Week labels row (shows every 4 weeks)
                    HStack(spacing: cellSpacing) {
                        ForEach(0..<weekCount, id: \.self) { weekIdx in
                            Group {
                                if weekIdx % 4 == 0 {
                                    Text(weekLabel(weekIdx: weekIdx))
                                        .font(.system(size: 7, weight: .medium))
                                        .foregroundColor(RQColors.textTertiary)
                                } else {
                                    Text("")
                                }
                            }
                            .frame(width: cellSize, alignment: .leading)
                        }
                    }
                    .padding(.top, 1)
                }
            }

            // Legend
            HStack(spacing: RQSpacing.xs) {
                Text("Less")
                    .font(.system(size: 8))
                    .foregroundColor(RQColors.textTertiary)
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(colorForLevel(level))
                        .frame(width: cellSize, height: cellSize)
                }
                Text("More")
                    .font(.system(size: 8))
                    .foregroundColor(RQColors.textTertiary)
            }
        }
    }

    // MARK: - Cell Rendering

    private func dayCell(weekIdx: Int, dayOfWeek: Int) -> some View {
        let date = dateFor(weekIdx: weekIdx, dayOfWeek: dayOfWeek)
        let count = countFor(date: date)
        let level = intensityLevel(count: count)

        return RoundedRectangle(cornerRadius: 1.5)
            .fill(colorForLevel(level))
            .frame(width: cellSize, height: cellSize)
    }

    // MARK: - Date Math

    /// Computes the date at the given (weekIdx, dayOfWeek) position in the grid.
    /// Week 0 is the oldest (12 weeks ago), dayOfWeek 0 is Monday.
    private func dateFor(weekIdx: Int, dayOfWeek: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find the start of the current week (Monday)
        guard let thisWeekMonday = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let startMonday = calendar.date(byAdding: .weekOfYear, value: -(weekCount - 1), to: thisWeekMonday) else {
            return today
        }

        return calendar.date(byAdding: .day, value: weekIdx * 7 + dayOfWeek, to: startMonday) ?? today
    }

    private func countFor(date: Date) -> Int {
        let calendar = Calendar.current
        return dailyData.first { calendar.isDate($0.date, inSameDayAs: date) }?.count ?? 0
    }

    private func weekLabel(weekIdx: Int) -> String {
        let date = dateFor(weekIdx: weekIdx, dayOfWeek: 0)
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    // MARK: - Color Mapping

    private func intensityLevel(count: Int) -> Int {
        if count == 0 { return 0 }
        if count == 1 { return 2 }
        if count == 2 { return 3 }
        return 4
    }

    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 0: return RQColors.surfaceTertiary
        case 1: return RQColors.accent.opacity(0.2)
        case 2: return RQColors.accent.opacity(0.45)
        case 3: return RQColors.accent.opacity(0.7)
        default: return RQColors.accent
        }
    }
}
