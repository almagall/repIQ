import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var goalViewModel = GoalViewModel()
    @State private var templateListViewModel = TemplateListViewModel()
    @State private var showTemplatePicker = false
    @State private var showCreateTemplate = false
    @State private var showProgramBrowser = false
    @State private var showNewTemplateOptions = false
    @State private var showCalendarView = false
    @State private var calendarMonth = Date()
    @State private var socialViewModel = SocialViewModel()
    @State private var showMonthlyWrapped = false
    @AppStorage("hasSeenWelcomeCard") private var hasSeenWelcomeCard = false

    @Environment(WorkoutCoordinator.self) private var workoutCoordinator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RQSpacing.lg) {
                    // Welcome card for new users
                    if !hasSeenWelcomeCard && !templateListViewModel.templates.isEmpty && viewModel.totalSessionCount == 0 {
                        welcomeCard
                    }

                    // Monthly Wrapped banner (1st–14th of month, prior month ready & unviewed)
                    if viewModel.shouldShowWrappedBanner, let wrapped = viewModel.priorMonthWrapped {
                        WrappedBannerCard(wrapped: wrapped) {
                            showMonthlyWrapped = true
                        }
                    }

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

                    // Activity (Week / Calendar toggle)
                    activityCard

                    // Social Pulse — league snippet + a peek at the latest
                    // friend activity. Renders nothing until the social VM has
                    // at least one signal to show (league tier, friend item),
                    // so users with no friends don't see an empty card.
                    if shouldShowSocialPulse {
                        socialPulseCard
                    }

                    // Goals
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
                                    Image(systemName: "target")
                                        .font(.system(size: 24))
                                        .foregroundColor(RQColors.accent)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(RQColors.textTertiary)
                                }

                                if goalViewModel.activeGoals.isEmpty {
                                    Text("No goals yet")
                                        .font(RQTypography.numbers)
                                        .foregroundColor(RQColors.textPrimary)
                                    Text("Set a goal to track your progress")
                                        .font(RQTypography.caption)
                                        .foregroundColor(RQColors.textTertiary)
                                } else {
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

                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text("\(Int(goal.progress * 100))%")
                                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                    .foregroundColor(RQColors.accent)

                                                if let days = goal.daysRemaining {
                                                    Text(days < 0 ? "Overdue" : "\(days)d left")
                                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                                        .foregroundColor(days < 0 ? .red : RQColors.textTertiary)
                                                }
                                            }
                                        }
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
                await socialViewModel.loadSocialData()
            }
            .refreshable {
                await viewModel.loadDashboard()
                await goalViewModel.loadGoals()
                await templateListViewModel.loadTemplates()
                await socialViewModel.loadSocialData()
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
            .navigationDestination(isPresented: $showMonthlyWrapped) {
                MonthlyWrappedView(viewModel: socialViewModel)
                    .onDisappear {
                        // Banner clears once viewed_at is persisted server-side; refresh
                        // the dashboard state so it disappears immediately on return.
                        Task { await viewModel.loadDashboard() }
                    }
            }
            // Mirror SocialTabView's destination wiring so the Social Pulse
            // card can push directly into the league/feed screens from Home.
            .navigationDestination(for: SocialDestination.self) { destination in
                switch destination {
                case .league:
                    LeagueView(viewModel: socialViewModel)
                        .navigationTitle("Leagues")
                        .navigationBarTitleDisplayMode(.inline)
                case .challenges:
                    ChallengesView(viewModel: socialViewModel)
                        .navigationTitle("Challenges")
                        .navigationBarTitleDisplayMode(.inline)
                case .achievements:
                    AchievementsView(viewModel: socialViewModel)
                case .weeklyDigest:
                    WeeklyDigestView(viewModel: socialViewModel)
                case .matchmaking:
                    MatchmakingView(viewModel: socialViewModel)
                case .socialProfile:
                    SocialProfileView(viewModel: socialViewModel)
                case .friendProfile(let friendship):
                    FriendProfileView(viewModel: socialViewModel, friendship: friendship)
                case .progressionRace(let friendship):
                    ProgressionRaceView(viewModel: socialViewModel, friend: friendship)
                }
            }
        }
    }

    // MARK: - Social Pulse Card

    private var shouldShowSocialPulse: Bool {
        // Show once we have any signed-in social data (currentUserId is
        // resolved during loadSocialData). `currentTier` always returns a
        // value, so the league strip never renders an empty state.
        socialViewModel.currentUserId != nil
    }

    private var friendFeedItems: [FeedItem] {
        socialViewModel.feedItems.filter { $0.userId != socialViewModel.currentUserId }
    }

    private var socialPulseCard: some View {
        VStack(spacing: RQSpacing.md) {
            // League block — taps into LeagueView.
            NavigationLink(value: SocialDestination.league) {
                HStack(spacing: RQSpacing.md) {
                    Image(systemName: socialViewModel.currentTier.icon)
                        .font(.system(size: 22))
                        .foregroundColor(RQColors.accent)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                        Text(socialViewModel.currentTier.displayName.uppercased() + " LEAGUE")
                            .font(RQTypography.label)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)
                        Text("\(socialViewModel.totalIQ) IQ points")
                            .font(RQTypography.numbersSmall)
                            .foregroundColor(RQColors.textPrimary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(RQColors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            // Latest friend activity — peek at the top item if any.
            if let item = friendFeedItems.first {
                Divider().overlay(RQColors.surfaceTertiary)

                NavigationLink(value: SocialDestination.socialProfile) {
                    HStack(spacing: RQSpacing.md) {
                        Circle()
                            .fill(RQColors.accent.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String((item.userProfile?.username ?? "?").prefix(1)).uppercased())
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(RQColors.accent)
                            )

                        VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                            Text(item.userProfile?.username ?? "A friend")
                                .font(RQTypography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(RQColors.textPrimary)
                            Text(socialPulseSubtitle(for: item))
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(RQColors.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(RQSpacing.cardPadding)
        .background(RQColors.surfacePrimary)
        .cornerRadius(RQRadius.medium)
    }

    private func socialPulseSubtitle(for item: FeedItem) -> String {
        switch item.itemType {
        case .workoutCompleted:
            return "Just completed a workout"
        case .prAchieved:
            let n = item.data.prCount ?? 1
            return n > 1 ? "Hit \(n) new PRs" : "Hit a new PR"
        case .streakMilestone:
            if let d = item.data.streakDays { return "\(d)-day streak!" }
            return "On a streak"
        case .badgeEarned:
            if let b = item.data.badgeName { return "Earned the \"\(b)\" badge" }
            return "Earned a badge"
        case .leaguePromoted:
            if let t = item.data.leagueTier { return "Promoted to \(t.capitalized)" }
            return "League promoted"
        case .challengeWon:
            return "Won a challenge"
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

    // MARK: - Activity Card (Week / Calendar toggle)

    private var activityCard: some View {
        RQCard {
            VStack(spacing: RQSpacing.md) {
                HStack {
                    Text("Activity")
                        .font(RQTypography.label)
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .foregroundColor(RQColors.textSecondary)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCalendarView.toggle()
                            if showCalendarView { calendarMonth = Date() }
                        }
                    } label: {
                        Image(systemName: showCalendarView ? "list.bullet" : "calendar")
                            .font(.system(size: 14))
                            .foregroundColor(RQColors.accent)
                    }
                }

                if showCalendarView {
                    calendarView
                } else {
                    weekView
                }
            }
        }
    }

    // MARK: - Week View

    private var weekView: some View {
        let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
        let calendarIndices = [0, 1, 2, 3, 4, 5, 6]
        let today = Calendar.current.component(.weekday, from: Date()) - 1
        let trainedCount = viewModel.weeklyTrainingDays.count

        return VStack(spacing: RQSpacing.md) {
            HStack {
                Text("\(trainedCount) day\(trainedCount == 1 ? "" : "s") trained this week")
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
                Spacer()
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

    // MARK: - Calendar View

    private var calendarView: some View {
        let calendar = Calendar.current
        let monthFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MMMM yyyy"
            return f
        }()

        return VStack(spacing: RQSpacing.md) {
            // Month navigation
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        calendarMonth = calendar.date(byAdding: .month, value: -1, to: calendarMonth) ?? calendarMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(RQColors.accent)
                }

                Spacer()

                Text(monthFormatter.string(from: calendarMonth))
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)

                Spacer()

                // Only allow forward if not current month
                let isCurrentMonth = calendar.isDate(calendarMonth, equalTo: Date(), toGranularity: .month)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        calendarMonth = calendar.date(byAdding: .month, value: 1, to: calendarMonth) ?? calendarMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isCurrentMonth ? RQColors.textTertiary.opacity(0.3) : RQColors.accent)
                }
                .disabled(isCurrentMonth)
            }

            // Day headers
            let dayHeaders = ["S", "M", "T", "W", "T", "F", "S"]
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(dayHeaders[i])
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(RQColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            let days = calendarDays(for: calendarMonth)
            let today = calendar.startOfDay(for: Date())

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: RQSpacing.xs) {
                ForEach(days, id: \.self) { date in
                    if let date {
                        let isTrainingDay = viewModel.allTrainingDates.contains(calendar.startOfDay(for: date))
                        let isToday = calendar.startOfDay(for: date) == today
                        let dayNum = calendar.component(.day, from: date)

                        Text("\(dayNum)")
                            .font(.system(size: 12, weight: isToday ? .bold : .regular, design: .rounded))
                            .foregroundColor(isToday ? .white : (isTrainingDay ? RQColors.accent : RQColors.textTertiary))
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(isToday ? RQColors.accent : (isTrainingDay ? RQColors.accent.opacity(0.15) : Color.clear))
                            )
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("")
                            .frame(width: 28, height: 28)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            // Monthly summary
            let monthDates = viewModel.allTrainingDates.filter {
                calendar.isDate($0, equalTo: calendarMonth, toGranularity: .month)
            }
            Text("\(monthDates.count) workout\(monthDates.count == 1 ? "" : "s") this month")
                .font(RQTypography.caption)
                .foregroundColor(RQColors.textTertiary)
        }
    }

    /// Returns an array of optional dates for the calendar grid.
    /// `nil` entries represent empty cells before the first day of the month.
    private func calendarDays(for month: Date) -> [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1 // 0=Sun
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }

        return days
    }

    // MARK: - Welcome Card

    private var welcomeCard: some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.md) {
                HStack {
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 20))
                        .foregroundColor(RQColors.accent)

                    Text("Your program is ready")
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)

                    Spacer()

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            hasSeenWelcomeCard = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(RQColors.textTertiary)
                            .frame(width: 24, height: 24)
                            .background(RQColors.surfaceTertiary)
                            .clipShape(Circle())
                    }
                }

                Text("Tap Start Workout to begin your first session. Your first few workouts help the app learn your strength levels — after that, you will get personalized targets.")
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textSecondary)

                Button {
                    hasSeenWelcomeCard = true
                    if !viewModel.templates.isEmpty {
                        showTemplatePicker = true
                    }
                } label: {
                    Text("Start First Workout")
                        .font(RQTypography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RQSpacing.sm)
                        .background(RQColors.accent)
                        .cornerRadius(RQRadius.medium)
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
