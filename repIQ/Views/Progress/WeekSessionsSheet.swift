import SwiftUI

/// Bottom sheet that appears when the user taps a bar in the volume chart.
/// Lists every completed session that fell inside that calendar week with
/// a tap-through to the full session detail view.
struct WeekSessionsSheet: View {
    let weekStart: Date
    let sessions: [WorkoutSession]
    let templateName: (WorkoutSession) -> String?
    let dayName: (WorkoutSession) -> String?
    let onSelectSession: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    private var weekRangeLabel: String {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: weekStart)) – \(formatter.string(from: end))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RQSpacing.lg) {
                    if sessions.isEmpty {
                        EmptyStateView(
                            icon: "calendar.badge.exclamationmark",
                            title: "No Sessions",
                            message: "No completed workouts logged in this week."
                        )
                        .padding(.top, RQSpacing.xxl)
                    } else {
                        RQCard {
                            VStack(spacing: 0) {
                                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                                    Button {
                                        dismiss()
                                        onSelectSession(session.id)
                                    } label: {
                                        sessionRow(session)
                                    }
                                    .buttonStyle(.plain)

                                    if index < sessions.count - 1 {
                                        Divider().background(RQColors.surfaceTertiary)
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
            .navigationTitle(weekRangeLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(RQColors.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        HStack(alignment: .center, spacing: RQSpacing.md) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 14))
                .foregroundColor(RQColors.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(sessionTitle(session))
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)
                    .lineLimit(1)
                Text(dayLabel(session))
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(RQColors.textTertiary)
        }
        .padding(.vertical, RQSpacing.sm)
    }

    private func sessionTitle(_ session: WorkoutSession) -> String {
        switch (templateName(session), dayName(session)) {
        case let (template?, day?): return "\(template) · \(day)"
        case let (template?, nil): return template
        case let (nil, day?): return day
        default: return "Workout"
        }
    }

    private func dayLabel(_ session: WorkoutSession) -> String {
        let date = session.completedAt ?? session.startedAt
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE · h:mm a"
        return formatter.string(from: date)
    }
}
