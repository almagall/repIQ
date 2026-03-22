import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var goalViewModel = GoalViewModel()
    @State private var templateListViewModel = TemplateListViewModel()
    @State private var showTemplatePicker = false
    @State private var showCreateTemplate = false
    @State private var showProgramBrowser = false
    @State private var showNewTemplateOptions = false

    @Environment(WorkoutCoordinator.self) private var workoutCoordinator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RQSpacing.lg) {
                    // Quick Start
                    QuickStartCard {
                        if !viewModel.templates.isEmpty {
                            showTemplatePicker = true
                        }
                    }

                    // My Templates
                    templatesSection

                    // Recent Workout
                    RQCard {
                        HStack {
                            VStack(alignment: .leading, spacing: RQSpacing.xs) {
                                Text("Recent Workout")
                                    .font(RQTypography.label)
                                    .textCase(.uppercase)
                                    .tracking(1.5)
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
                                    .font(RQTypography.label)
                                    .textCase(.uppercase)
                                    .tracking(1.5)
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

                    // Active Goals
                    if !goalViewModel.activeGoals.isEmpty {
                        RQCard {
                            VStack(alignment: .leading, spacing: RQSpacing.md) {
                                Text("Goals")
                                    .font(RQTypography.label)
                                    .textCase(.uppercase)
                                    .tracking(1.5)
                                    .foregroundColor(RQColors.textSecondary)

                                ForEach(goalViewModel.activeGoals.prefix(3)) { goal in
                                    HStack(spacing: RQSpacing.md) {
                                        Image(systemName: goal.goalType.icon)
                                            .font(.system(size: 14))
                                            .foregroundColor(RQColors.accent)
                                            .frame(width: 20)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(goal.exerciseName ?? goal.goalType.displayName)
                                                .font(RQTypography.caption)
                                                .foregroundColor(RQColors.textPrimary)
                                                .lineLimit(1)

                                            GeometryReader { geo in
                                                ZStack(alignment: .leading) {
                                                    Capsule()
                                                        .fill(RQColors.surfaceTertiary)
                                                        .frame(height: 4)
                                                    Capsule()
                                                        .fill(RQColors.accent)
                                                        .frame(width: geo.size.width * goal.progress, height: 4)
                                                }
                                            }
                                            .frame(height: 4)
                                        }

                                        Text("\(Int(goal.progress * 100))%")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundColor(RQColors.accent)
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
            .navigationTitle("Home")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await viewModel.loadDashboard()
                await goalViewModel.loadGoals()
                await templateListViewModel.loadTemplates()
            }
            .refreshable {
                await viewModel.loadDashboard()
                await goalViewModel.loadGoals()
                await templateListViewModel.loadTemplates()
            }
            .sheet(isPresented: $showTemplatePicker) {
                templatePickerSheet
            }
            .confirmationDialog("New Template", isPresented: $showNewTemplateOptions, titleVisibility: .visible) {
                Button("Custom Template") {
                    showCreateTemplate = true
                }
                Button("Browse Programs") {
                    showProgramBrowser = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Create your own template or choose from proven workout programs.")
            }
            .navigationDestination(isPresented: $showCreateTemplate) {
                TemplateEditorView(viewModel: TemplateEditorViewModel())
            }
            .navigationDestination(isPresented: $showProgramBrowser) {
                ProgramBrowserView(onProgramCreated: {
                    showProgramBrowser = false
                    Task { await templateListViewModel.loadTemplates() }
                })
            }
        }
    }

    // MARK: - My Templates Section

    @ViewBuilder
    private var templatesSection: some View {
        if templateListViewModel.templates.isEmpty && !templateListViewModel.isLoading {
            // Empty state — no templates yet
            RQCard {
                VStack(spacing: RQSpacing.md) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 28))
                        .foregroundColor(RQColors.textTertiary)

                    Text("No templates yet")
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)

                    Text("Create a custom template or browse proven programs")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                        .multilineTextAlignment(.center)

                    Button {
                        showNewTemplateOptions = true
                    } label: {
                        Text("Get Started")
                            .font(RQTypography.caption)
                            .fontWeight(.bold)
                            .foregroundColor(RQColors.background)
                            .padding(.horizontal, RQSpacing.xl)
                            .padding(.vertical, RQSpacing.sm)
                            .background(RQColors.accent)
                            .cornerRadius(RQRadius.medium)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, RQSpacing.md)
            }
        } else {
            // Single card linking to full template management
            NavigationLink {
                TemplateManagementView(viewModel: templateListViewModel)
            } label: {
                RQCard {
                    HStack {
                        VStack(alignment: .leading, spacing: RQSpacing.xs) {
                            Text("Templates")
                                .font(RQTypography.label)
                                .textCase(.uppercase)
                                .tracking(1.5)
                                .foregroundColor(RQColors.textSecondary)

                            let count = templateListViewModel.templates.count
                            Text("\(count) template\(count == 1 ? "" : "s")")
                                .font(RQTypography.numbers)
                                .foregroundColor(RQColors.textPrimary)

                            Text("View & manage your templates")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 24))
                            .foregroundColor(RQColors.accent)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(RQColors.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Template Picker Sheet (with inline day selection via NavigationStack push)

    @ViewBuilder
    private var templatePickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RQSpacing.md) {
                    ForEach(viewModel.templates) { template in
                        NavigationLink(value: template) {
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
            .navigationDestination(for: Template.self) { template in
                WorkoutDayPickerView(template: template) { day, date in
                    showTemplatePicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        workoutCoordinator.startWorkout(template: template, day: day, date: date)
                    }
                }
            }
        }
    }
}
