import WidgetKit
import SwiftUI

// MARK: - Widget Data

struct WorkoutWidgetEntry: TimelineEntry {
    let date: Date
    let currentStreak: Int
    let weeklySessionCount: Int
    let lastWorkoutDate: Date?
    let nextWorkoutName: String?
}

// MARK: - Timeline Provider

struct WorkoutWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WorkoutWidgetEntry {
        WorkoutWidgetEntry(
            date: Date(),
            currentStreak: 5,
            weeklySessionCount: 3,
            lastWorkoutDate: Date().addingTimeInterval(-86400),
            nextWorkoutName: "Push Day"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WorkoutWidgetEntry) -> Void) {
        let entry = WorkoutWidgetEntry(
            date: Date(),
            currentStreak: loadStreak(),
            weeklySessionCount: loadWeeklyCount(),
            lastWorkoutDate: loadLastWorkoutDate(),
            nextWorkoutName: loadNextWorkoutName()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkoutWidgetEntry>) -> Void) {
        let entry = WorkoutWidgetEntry(
            date: Date(),
            currentStreak: loadStreak(),
            weeklySessionCount: loadWeeklyCount(),
            lastWorkoutDate: loadLastWorkoutDate(),
            nextWorkoutName: loadNextWorkoutName()
        )
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    // MARK: - UserDefaults (shared via App Group)

    private let defaults = UserDefaults(suiteName: "group.com.repiq.shared")

    private func loadStreak() -> Int {
        defaults?.integer(forKey: "widget_currentStreak") ?? 0
    }

    private func loadWeeklyCount() -> Int {
        defaults?.integer(forKey: "widget_weeklySessionCount") ?? 0
    }

    private func loadLastWorkoutDate() -> Date? {
        defaults?.object(forKey: "widget_lastWorkoutDate") as? Date
    }

    private func loadNextWorkoutName() -> String? {
        defaults?.string(forKey: "widget_nextWorkoutName")
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: WorkoutWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("repIQ")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                Spacer()
            }

            Spacer()

            // Streak
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                Text("\(entry.currentStreak)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Text(entry.currentStreak == 1 ? "day streak" : "day streak")
                .font(.system(size: 11))
                .foregroundColor(.gray)

            // Weekly progress
            HStack(spacing: 4) {
                Text("\(entry.weeklySessionCount)/week")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .containerBackground(Color.black, for: .widget)
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: WorkoutWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: Streak
            VStack(alignment: .leading, spacing: 4) {
                Text("repIQ")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                    Text("\(entry.currentStreak)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Text("day streak")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            // Right: Quick info
            VStack(alignment: .leading, spacing: 8) {
                Spacer()

                // This week
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text("\(entry.weeklySessionCount) sessions this week")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }

                // Last workout
                if let lastDate = entry.lastWorkoutDate {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text("Last: \(lastDate, style: .relative) ago")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }

                // Next workout
                if let nextName = entry.nextWorkoutName {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        Text("Next: \(nextName)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }

                Spacer()
            }
        }
        .padding()
        .containerBackground(Color.black, for: .widget)
    }
}

// MARK: - Widget Configuration

struct RepIQWidget: Widget {
    let kind: String = "RepIQWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WorkoutWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                WidgetView(entry: entry)
            }
        }
        .configurationDisplayName("repIQ")
        .description("Track your workout streak and weekly progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: WorkoutWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle

@main
struct RepIQWidgetBundle: WidgetBundle {
    var body: some Widget {
        RepIQWidget()
    }
}
