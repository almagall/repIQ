import SwiftUI

struct ProgressTabView: View {
    @State private var viewModel = ProgressViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if viewModel.sessions.isEmpty {
                    EmptyStateView(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "No Progress Data",
                        message: "Complete your first workout to start tracking your progress and PRs."
                    )
                } else {
                    VStack(spacing: RQSpacing.lg) {
                        // Stats row
                        statsRow

                        // Workout History header
                        HStack {
                            Text("Workout History")
                                .font(RQTypography.label)
                                .textCase(.uppercase)
                                .tracking(1.5)
                                .foregroundColor(RQColors.textSecondary)
                            Spacer()
                        }
                        .padding(.top, RQSpacing.sm)

                        // Session list
                        LazyVStack(spacing: RQSpacing.md) {
                            ForEach(viewModel.sessions) { session in
                                NavigationLink(value: session.id) {
                                    sessionRow(session)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, RQSpacing.screenHorizontal)
                    .padding(.top, RQSpacing.lg)
                    .padding(.bottom, RQSpacing.xxxl)
                }
            }
            .background(RQColors.background)
            .navigationTitle("Progress")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: UUID.self) { sessionId in
                SessionDetailView(viewModel: viewModel, sessionId: sessionId)
            }
            .task {
                await viewModel.loadHistory()
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: RQSpacing.md) {
            statCard(
                label: "This Week",
                value: "\(viewModel.weeklySessionCount)",
                icon: "calendar"
            )
            statCard(
                label: "This Month",
                value: "\(viewModel.monthlySessionCount)",
                icon: "calendar.badge.clock"
            )
            statCard(
                label: "Total",
                value: "\(viewModel.totalSessionCount)",
                icon: "flame.fill"
            )
        }
    }

    private func statCard(label: String, value: String, icon: String) -> some View {
        RQCard {
            VStack(spacing: RQSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(RQColors.accent)

                Text(value)
                    .font(RQTypography.numbers)
                    .foregroundColor(RQColors.textPrimary)

                Text(label)
                    .font(RQTypography.label)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(RQColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Session Row

    private func sessionRow(_ session: WorkoutSession) -> some View {
        let date = session.completedAt ?? session.startedAt
        let workout = viewModel.dayName(for: session)
        let template = viewModel.templateName(for: session)

        return RQCard {
            HStack(spacing: RQSpacing.md) {
                // Date badge
                VStack(spacing: 2) {
                    Text(dayOfMonth(date))
                        .font(RQTypography.title3)
                        .foregroundColor(RQColors.textPrimary)
                    Text(monthAbbrev(date))
                        .font(RQTypography.label)
                        .textCase(.uppercase)
                        .foregroundColor(RQColors.textSecondary)
                }
                .frame(width: 44)

                // Divider
                RoundedRectangle(cornerRadius: 1)
                    .fill(RQColors.surfaceTertiary)
                    .frame(width: 1, height: 44)

                // Session info
                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    // Workout day name (primary)
                    Text(workout ?? dayOfWeek(date))
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)
                        .lineLimit(1)

                    // Template name + metadata
                    HStack(spacing: RQSpacing.sm) {
                        if let template {
                            Text(template)
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.accent)
                                .lineLimit(1)
                        }

                        if template != nil, session.durationSeconds != nil {
                            Text("·")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }

                        if let duration = session.durationSeconds {
                            Label(formatDuration(duration), systemImage: "clock")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(RQColors.textTertiary)
            }
        }
    }

    // MARK: - Formatting

    private func dayOfMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func monthAbbrev(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
