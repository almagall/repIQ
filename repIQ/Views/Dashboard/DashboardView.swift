import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RQSpacing.lg) {
                    // Quick Start
                    QuickStartCard()

                    // Recent Workout
                    RQCard {
                        HStack {
                            VStack(alignment: .leading, spacing: RQSpacing.xs) {
                                Text("Recent Workout")
                                    .font(RQTypography.footnote)
                                    .foregroundColor(RQColors.textSecondary)
                                if let session = viewModel.recentSession {
                                    Text(session.completedAt?.relativeDisplay ?? "Completed")
                                        .font(RQTypography.headline)
                                        .foregroundColor(RQColors.textPrimary)
                                    if let duration = session.durationSeconds {
                                        Text("\(duration / 60) min")
                                            .font(RQTypography.caption)
                                            .foregroundColor(RQColors.textTertiary)
                                    }
                                } else {
                                    Text("No workouts yet")
                                        .font(RQTypography.headline)
                                        .foregroundColor(RQColors.textPrimary)
                                }
                            }
                            Spacer()
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 24))
                                .foregroundColor(RQColors.textTertiary)
                        }
                    }

                    // Weekly Volume
                    RQCard {
                        HStack {
                            VStack(alignment: .leading, spacing: RQSpacing.xs) {
                                Text("This Week")
                                    .font(RQTypography.footnote)
                                    .foregroundColor(RQColors.textSecondary)
                                Text("\(viewModel.weeklySetCount) sets")
                                    .font(RQTypography.numbers)
                                    .foregroundColor(RQColors.textPrimary)
                                Text(viewModel.weeklySetCount > 0
                                    ? "Keep up the great work"
                                    : "Start your first workout")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                            }
                            Spacer()
                            Image(systemName: "flame.fill")
                                .font(.system(size: 24))
                                .foregroundColor(RQColors.accent)
                        }
                    }

                    // Templates count
                    RQCard {
                        HStack {
                            VStack(alignment: .leading, spacing: RQSpacing.xs) {
                                Text("Templates")
                                    .font(RQTypography.footnote)
                                    .foregroundColor(RQColors.textSecondary)
                                Text("\(viewModel.templateCount)")
                                    .font(RQTypography.numbers)
                                    .foregroundColor(RQColors.textPrimary)
                                Text(viewModel.templateCount > 0
                                    ? "Workout programs ready"
                                    : "Create your first template")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                            }
                            Spacer()
                            Image(systemName: "rectangle.stack.fill")
                                .font(.system(size: 24))
                                .foregroundColor(RQColors.accent)
                        }
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.top, RQSpacing.lg)
                .padding(.bottom, RQSpacing.xxxl)
            }
            .background(RQColors.background)
            .navigationTitle("Dashboard")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await viewModel.loadDashboard()
            }
            .refreshable {
                await viewModel.loadDashboard()
            }
        }
    }
}
