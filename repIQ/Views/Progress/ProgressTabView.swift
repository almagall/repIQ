import SwiftUI

/// The Progress tab.
///
/// Answers one question — are your targets going up, and are you hitting them —
/// and then stops. The history and totals that used to live below (last-workout
/// recap, PR list, training heatmap, monthly and lifetime stats, volume trend,
/// muscle balance, vs-past-you) were removed: they described what happened
/// rather than what to do about it, and every one of them competed with the
/// answer above. Long-range history now lives in the monthly Rep Sheet.
struct ProgressTabView: View {
    @State private var viewModel = TargetsOverviewViewModel()
    @State private var showRepSheet = false
    /// Carries the workout day as well as the exercise — the same lift on two
    /// days has independent targets, so the drill-in has to know which one it
    /// is looking at.
    @State private var selectedLift: LiftSelection?

    struct LiftSelection: Identifiable, Hashable {
        let exerciseId: UUID
        let workoutDayId: UUID?
        var id: String { "\(exerciseId)-\(workoutDayId?.uuidString ?? "unplanned")" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(.horizontal, RQSpacing.screenHorizontal)
                    .padding(.top, RQSpacing.lg)
                    .padding(.bottom, RQSpacing.xxxl)
            }
            .background(RQColors.background)
            .navigationTitle("Progress")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(isPresented: $showRepSheet) {
                RepSheetView()
            }
            .navigationDestination(item: $selectedLift) { lift in
                ExerciseTargetView(
                    exerciseId: lift.exerciseId,
                    workoutDayId: lift.workoutDayId
                )
            }
            .task { await viewModel.load() }
            .refreshable {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                await viewModel.load()
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading, viewModel.verdict.isBaseline, viewModel.report.isEmpty {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                .frame(maxWidth: .infinity, minHeight: 300)
        } else {
            VStack(spacing: RQSpacing.xl) {
                // 1. The outcome — how many lifts get a harder target next time.
                TargetsHeroCard(
                    verdict: viewModel.verdict,
                    presentation: viewModel.presentation,
                    coaching: viewModel.coachingLine
                )

                // 2. Last month's recap, while it's still news.
                if viewModel.hasUnreadRepSheet {
                    unreadRepSheetBanner
                }

                // 3. The one lift worth acting on, when there is one.
                if let focus = viewModel.focus {
                    TargetFocusCard(focus: focus) {
                        selectedLift = LiftSelection(
                            exerciseId: focus.exercise.exerciseId,
                            workoutDayId: focus.exercise.workoutDayId
                        )
                    }
                }

                // 4. The mechanism behind the headline: what was prescribed,
                //    and how much of it landed.
                if !viewModel.days.isEmpty {
                    targetsSectionHeader
                    DayTargetsPanel(
                        days: viewModel.days,
                        expandedIds: viewModel.expandedDayIds,
                        onToggle: { viewModel.toggleExpansion($0) },
                        onSelectExercise: { exercise in
                            selectedLift = LiftSelection(
                                exerciseId: exercise.exerciseId,
                                workoutDayId: exercise.workoutDayId
                            )
                        }
                    )
                }

                // 5. Footer link, once the recap is no longer news.
                if !viewModel.hasUnreadRepSheet {
                    repSheetLink
                }
            }
        }
    }

    // MARK: - Section header

    /// States the window and the session count. 82% across three sessions is a
    /// much thinner claim than 82% across fourteen, and the percentage on its
    /// own can't say which it is.
    private var targetsSectionHeader: some View {
        HStack {
            Text("Targets hit · \(viewModel.report.windowDays / 7) weeks · \(viewModel.report.sessionCount) sessions")
                .rqSheetLabel()
                .foregroundColor(RQColors.textTertiary)
            Spacer()
            InfoButton(topic: ProgressExplainer.targetsHit)
        }
        .padding(.horizontal, RQSpacing.xs)
    }

    // MARK: - Rep Sheet

    private var unreadRepSheetBanner: some View {
        Button { showRepSheet = true } label: {
            HStack(spacing: RQSpacing.md) {
                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text("\(priorMonthName) Rep Sheet")
                        .font(RQTypography.sheetTitle)
                        .foregroundColor(RQColors.textPrimary)
                    Text("Your monthly recap is ready")
                        .font(RQTypography.sheetCaption)
                        .foregroundColor(RQColors.textTertiary)
                }
                Spacer(minLength: 0)
                Text("NEW")
                    .font(RQTypography.sheetLabel)
                    .tracking(RQTypography.sheetLabelTracking)
                    .foregroundColor(RQColors.accent)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(RQColors.textTertiary)
            }
            .padding(RQSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .rqSheet(fill: RQColors.surfacePrimary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var repSheetLink: some View {
        Button { showRepSheet = true } label: {
            HStack(spacing: RQSpacing.md) {
                Text("\(priorMonthName) Rep Sheet")
                    .font(RQTypography.sheetBody)
                    .foregroundColor(RQColors.textSecondary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(RQColors.textTertiary)
            }
            .padding(.vertical, RQSpacing.lg)
            .padding(.horizontal, RQSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var priorMonthName: String {
        let calendar = Calendar.current
        let priorMonth = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: priorMonth)
    }
}
