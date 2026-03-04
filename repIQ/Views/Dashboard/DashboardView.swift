import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var showTemplatePicker = false
    @State private var showDayPicker = false
    @State private var selectedTemplate: Template?

    @Environment(WorkoutCoordinator.self) private var workoutCoordinator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RQSpacing.lg) {
                    // Quick Start
                    QuickStartCard {
                        if viewModel.templates.count == 1, let template = viewModel.templates.first {
                            // Single template — skip template picker
                            selectedTemplate = template
                            if let days = template.workoutDays, days.count == 1, let day = days.first {
                                workoutCoordinator.startWorkout(template: template, day: day)
                            } else {
                                showDayPicker = true
                            }
                        } else if !viewModel.templates.isEmpty {
                            showTemplatePicker = true
                        }
                    }

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
            .sheet(isPresented: $showTemplatePicker) {
                templatePickerSheet
            }
            .sheet(isPresented: $showDayPicker) {
                if let template = selectedTemplate {
                    WorkoutDayPickerView(template: template) { day in
                        workoutCoordinator.startWorkout(template: template, day: day)
                    }
                }
            }
        }
    }

    // MARK: - Template Picker Sheet

    @ViewBuilder
    private var templatePickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RQSpacing.md) {
                    ForEach(viewModel.templates) { template in
                        Button {
                            selectedTemplate = template
                            showTemplatePicker = false

                            if let days = template.workoutDays, days.count == 1, let day = days.first {
                                workoutCoordinator.startWorkout(template: template, day: day)
                            } else {
                                // Slight delay so the sheet dismiss animation completes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showDayPicker = true
                                }
                            }
                        } label: {
                            RQCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: RQSpacing.xs) {
                                        Text(template.name)
                                            .font(RQTypography.headline)
                                            .foregroundColor(RQColors.textPrimary)
                                        Text("\(template.workoutDays?.count ?? 0) days")
                                            .font(RQTypography.caption)
                                            .foregroundColor(RQColors.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(RQColors.textTertiary)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.top, RQSpacing.lg)
            }
            .background(RQColors.background)
            .navigationTitle("Select Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showTemplatePicker = false
                    }
                    .foregroundColor(RQColors.textSecondary)
                }
            }
        }
    }
}
