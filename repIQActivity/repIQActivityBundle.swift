import WidgetKit
import SwiftUI

@main
struct repIQActivityBundle: WidgetBundle {
    var body: some Widget {
        repIQActivityLiveActivity()
        repIQHomeWidget()
    }
}

// MARK: - Home Screen Widget
//
// Reads a snapshot of the user's training state from the App Group's shared
// `UserDefaults` and renders a glanceable summary. Data is push-based —
// `WidgetService.sync(_:)` in the main app refreshes the timeline whenever
// dashboard or workout state changes.

private enum WidgetKeys {
    static let appGroupSuite = "group.com.repiq.shared"
    static let currentStreak = "widget_currentStreak"
    static let weeklyWorkingSetCount = "widget_weeklyWorkingSetCount"
    static let lastWorkoutDate = "widget_lastWorkoutDate"
    static let lastPRSummary = "widget_lastPRSummary"
}

private struct WidgetEntry: TimelineEntry {
    let date: Date
    let currentStreak: Int
    let weeklyWorkingSetCount: Int
    let lastWorkoutDate: Date?
    let lastPRSummary: String?

    static let placeholder = WidgetEntry(
        date: Date(),
        currentStreak: 7,
        weeklyWorkingSetCount: 42,
        lastWorkoutDate: Date().addingTimeInterval(-86_400),
        lastPRSummary: "Bench Press 225×8"
    )
}

private struct WidgetProvider: TimelineProvider {
    private static let defaults = UserDefaults(suiteName: WidgetKeys.appGroupSuite)

    private func currentEntry() -> WidgetEntry {
        let d = Self.defaults
        return WidgetEntry(
            date: Date(),
            currentStreak: d?.integer(forKey: WidgetKeys.currentStreak) ?? 0,
            weeklyWorkingSetCount: d?.integer(forKey: WidgetKeys.weeklyWorkingSetCount) ?? 0,
            lastWorkoutDate: d?.object(forKey: WidgetKeys.lastWorkoutDate) as? Date,
            lastPRSummary: d?.string(forKey: WidgetKeys.lastPRSummary)
        )
    }

    func placeholder(in context: Context) -> WidgetEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(context.isPreview ? .placeholder : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        // The main app calls `WidgetCenter.shared.reloadAllTimelines()` whenever
        // anything changes, so we can keep this static. The 1-hour refresh is
        // a safety net for ambient relative-date strings ("2 hours ago") that
        // would otherwise drift if the user never opens the app.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [currentEntry()], policy: .after(next)))
    }
}

struct repIQHomeWidget: Widget {
    let kind: String = "repIQHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetProvider()) { entry in
            WidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color.black, Color(white: 0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("repIQ")
        .description("Streak, weekly volume, and your last PR at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct WidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(entry: entry)
        case .systemMedium: MediumWidgetView(entry: entry)
        default:            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Layouts

private let widgetAccent = Color(red: 0.0, green: 0.667, blue: 1.0) // #00AAFF — RQColors.accent
private let widgetTextPrimary = Color.white
private let widgetTextSecondary = Color.white.opacity(0.7)
private let widgetTextTertiary = Color.white.opacity(0.45)

private struct SmallWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(widgetAccent)
                Text("STREAK")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(widgetTextTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(entry.currentStreak)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(widgetTextPrimary)
                    .minimumScaleFactor(0.6)
                Text(entry.currentStreak == 1 ? "day" : "days")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(widgetTextSecondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.weeklyWorkingSetCount) working sets")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(widgetTextPrimary)
                Text("this week")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(widgetTextTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct MediumWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(widgetAccent)
                    Text("STREAK")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(widgetTextTertiary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(entry.currentStreak)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(widgetTextPrimary)
                        .minimumScaleFactor(0.6)
                    Text(entry.currentStreak == 1 ? "day" : "days")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(widgetTextSecondary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.weeklyWorkingSetCount) sets")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(widgetTextPrimary)
                    Text("this week")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(widgetTextTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(widgetAccent)
                    Text("LAST PR")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(widgetTextTertiary)
                }

                if let pr = entry.lastPRSummary {
                    Text(pr)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(widgetTextPrimary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)
                } else {
                    Text("No PRs yet")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(widgetTextSecondary)
                }

                Spacer(minLength: 0)

                if let date = entry.lastWorkoutDate {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last trained")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(widgetTextTertiary)
                        Text(date, style: .relative)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(widgetTextSecondary)
                    }
                } else {
                    Text("Tap to start your first workout")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(widgetTextTertiary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview(as: .systemSmall) {
    repIQHomeWidget()
} timeline: {
    WidgetEntry.placeholder
    WidgetEntry(date: Date(), currentStreak: 0, weeklyWorkingSetCount: 0, lastWorkoutDate: nil, lastPRSummary: nil)
}

#Preview(as: .systemMedium) {
    repIQHomeWidget()
} timeline: {
    WidgetEntry.placeholder
}
