import SwiftUI

/// A 12-week activity heatmap showing daily workout presence.
/// Uses a binary trained / didn't-train color scheme — for lifting, you
/// almost always do exactly one workout per day, so an intensity scale
/// would just be visual noise.
struct ConsistencyHeatmap: View {
    let dailyData: [(date: Date, count: Int)]

    private let weekCount = 12
    private let dayCount = 7
    private let cellSize: CGFloat = 18
    private let cellSpacing: CGFloat = 3
    private let dayLabelWidth: CGFloat = 14
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: RQSpacing.xs) {
            HStack(alignment: .top, spacing: cellSpacing) {
                // Day-of-week labels
                VStack(spacing: cellSpacing) {
                    ForEach(0..<dayCount, id: \.self) { dayIdx in
                        Text(dayLabels[dayIdx])
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(RQColors.textTertiary)
                            .frame(width: dayLabelWidth, height: cellSize)
                    }
                }

                // Heatmap grid
                VStack(alignment: .leading, spacing: cellSpacing) {
                    ForEach(0..<dayCount, id: \.self) { dayOfWeek in
                        HStack(spacing: cellSpacing) {
                            ForEach(0..<weekCount, id: \.self) { weekIdx in
                                dayCell(weekIdx: weekIdx, dayOfWeek: dayOfWeek)
                            }
                        }
                    }
                }
            }

            // Week date labels (every 4 weeks)
            HStack(spacing: 0) {
                Spacer().frame(width: dayLabelWidth + cellSpacing)
                ForEach(0..<weekCount, id: \.self) { weekIdx in
                    if weekIdx % 4 == 0 {
                        Text(weekLabel(weekIdx: weekIdx))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(RQColors.textTertiary)
                            .lineLimit(1)
                            .fixedSize()
                            .frame(width: (cellSize + cellSpacing) * 4, alignment: .leading)
                    }
                }
            }
            .padding(.top, 2)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Cell Rendering

    private func dayCell(weekIdx: Int, dayOfWeek: Int) -> some View {
        let date = dateFor(weekIdx: weekIdx, dayOfWeek: dayOfWeek)
        let trained = countFor(date: date) > 0

        return RoundedRectangle(cornerRadius: 2)
            .fill(trained ? RQColors.accent : RQColors.surfaceTertiary)
            .frame(width: cellSize, height: cellSize)
    }

    // MARK: - Date Math

    /// Calendar configured to start weeks on Monday so the heatmap rows
    /// (M T W T F S S) align with the actual day boundaries — independent
    /// of the user's locale, which would otherwise default to Sunday in the US.
    private var mondayCalendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }

    /// Computes the date at the given (weekIdx, dayOfWeek) position.
    /// Week 0 is the oldest (12 weeks ago), dayOfWeek 0 is Monday.
    private func dateFor(weekIdx: Int, dayOfWeek: Int) -> Date {
        let calendar = mondayCalendar
        let today = calendar.startOfDay(for: Date())

        guard let thisWeekMonday = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let startMonday = calendar.date(byAdding: .weekOfYear, value: -(weekCount - 1), to: thisWeekMonday) else {
            return today
        }

        return calendar.date(byAdding: .day, value: weekIdx * 7 + dayOfWeek, to: startMonday) ?? today
    }

    private func countFor(date: Date) -> Int {
        return dailyData.first { mondayCalendar.isDate($0.date, inSameDayAs: date) }?.count ?? 0
    }

    private func weekLabel(weekIdx: Int) -> String {
        let date = dateFor(weekIdx: weekIdx, dayOfWeek: 0)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
