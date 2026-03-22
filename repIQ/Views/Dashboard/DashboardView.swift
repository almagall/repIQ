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

                    // Workout History
                    NavigationLink {
                        WorkoutHistoryView()
                    } label: {
                        RQCard {
                            HStack {
                                VStack(alignment: .leading, spacing: RQSpacing.xs) {
                                    Text("Workout History")
                                        .font(RQTypography.label)
                                        .textCase(.uppercase)
                                        .tracking(1.5)
                                        .foregroundColor(RQColors.textSecondary)

                                    if viewModel.totalSessionCount > 0 {
                                        Text("\(viewModel.totalSessionCount) workout\(viewModel.totalSessionCount == 1 ? "" : "s") logged")
                                            .font(RQTypography.numbers)
                                            .foregroundColor(RQColors.textPrimary)

                                        if let session = viewModel.recentSession {
                                            Text("Last trained \(session.completedAt?.relativeDisplay ?? "")")
                                                .font(RQTypography.caption)
                                                .foregroundColor(RQColors.textTertiary)
                                        }
                                    } else {
                                        Text("No workouts yet")
                                            .font(RQTypography.numbers)
                                            .foregroundColor(RQColors.textPrimary)
                                        Text("Complete your first workout")
                                            .font(RQTypography.caption)
                                            .foregroundColor(RQColors.textTertiary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 24))
                                    .foregroundColor(RQColors.accent)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(RQColors.textTertiary)
                            }
                        }
                    }

                    // Active Goals
                    if !goalViewModel.activeGoals.isEmpty {
                        NavigationLink {
                            GoalSettingView()
                        } label: {
                            RQCard {
                                VStack(alignment: .leading, spacing: RQSpacing.md) {
                                    HStack {
                                        Text("Goals")
                                            .font(RQTypography.label)
                                            .textCase(.uppercase)
                                            .tracking(1.5)
                                            .foregroundColor(RQColors.textSecondary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(RQColors.textTertiary)
                                    }

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

                    // Weekly Activity
                    weeklyActivityCard
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

    // MARK: - Weekly Activity Card

    private var weeklyActivityCard: some View {
        // Days ordered Mon-Sun for display
        let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
        // Calendar weekday indices for Mon(1)-Sun(0) mapped to Calendar's Sun=1..Sat=7
        // Display order: Mon=2, Tue=3, Wed=4, Thu=5, Fri=6, Sat=7, Sun=1
        // weeklyTrainingDays uses 0=Sun..6=Sat
        let calendarIndices = [1, 2, 3, 4, 5, 6, 0] // Mon..Sun mapped to our 0-based

        let today = Calendar.current.component(.weekday, from: Date()) - 1 // 0=Sun..6=Sat
        let trainedCount = viewModel.weeklyTrainingDays.count

        return RQCard {
            VStack(spacing: RQSpacing.md) {
                HStack {
                    Text("This Week")
                        .font(RQTypography.label)
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .foregroundColor(RQColors.textSecondary)
                    Spacer()
                    Text("\(trainedCount) day\(trainedCount == 1 ? "" : "s") trained")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }

                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        let dayIndex = calendarIndices[i]
                        let trained = viewModel.weeklyTrainingDays.contains(dayIndex)
                        let isToday = dayIndex == today

                        VStack(spacing: RQSpacing.xs) {
                            Text(dayLabels[i])
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(isToday ? RQColors.textPrimary : RQColors.textTertiary)

                            Circle()
                                .fill(trained ? RQColors.accent : RQColors.surfaceTertiary)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(isToday ? RQColors.accent : Color.clear, lineWidth: 2)
                                )
                        }
                        .frame(maxWidth: .infinity)
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
