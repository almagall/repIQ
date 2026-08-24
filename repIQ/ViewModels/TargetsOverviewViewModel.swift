import Foundation
import Supabase

/// Drives the Progress tab's target section: the headline verdict, the single
/// thing worth fixing, and the per-day breakdown.
///
/// Deliberately separate from `ProgressDashboardViewModel`, which owns the
/// history and totals below the fold. Those are slow aggregate queries; this is
/// the answer the tab exists to give, and it shouldn't wait on them.
@Observable
final class TargetsOverviewViewModel {

    // MARK: - State

    /// How the tab should present itself. Every case still renders the same
    /// hero → action → days shape, so the screen never feels like it changed.
    enum Presentation: Equatable {
        /// Nothing logged at all.
        case firstRun
        /// Logging has started but no exercise has the history the engine needs.
        case baseline(liftsReady: Int, liftsTotal: Int)
        /// Real numbers to show.
        case active
        /// Trained too long ago for the window to mean anything.
        case paused(daysSince: Int, lastTrained: Date)
    }

    private(set) var presentation: Presentation = .active
    private(set) var report: AdherenceReport = .empty
    private(set) var verdict: ProgressionVerdict = .empty
    private(set) var isLoading = false

    /// The one lift worth acting on, if there is one.
    private(set) var focus: FocusItem?

    /// Last month's Rep Sheet, while it's generated and still unread. Not
    /// date-gated the way the Dashboard banner is — the Progress tab is where
    /// someone goes looking for a recap, so it stays promoted until opened.
    private(set) var hasUnreadRepSheet = false

    /// Days the user has expanded, kept across visits so the tab doesn't keep
    /// re-collapsing the day they actually care about.
    var expandedDayIds: Set<String> = []

    struct FocusItem: Identifiable, Sendable {
        let exercise: ExerciseAdherence
        let dayName: String
        var id: String { exercise.id }
    }

    // MARK: - Config

    /// Shared with `fetchProgressionRate` so the hero and the day rows measure
    /// the same span. See `AdherenceRules`.
    private let windowDays = AdherenceRules.windowDays

    /// Past this, the window is mostly empty and the percentage would be
    /// describing a version of the user that no longer exists.
    private let pausedAfterDays = 14

    private let adherenceService = TargetAdherenceService()
    private let analyticsService = AnalyticsService()
    private let digestService = DigestService()

    // MARK: - Load

    func load() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        isLoading = true
        defer { isLoading = false }

        async let reportTask = try? adherenceService.fetchReport(userId: userId, windowDays: windowDays)
        async let verdictTask = try? analyticsService.fetchProgressionRate(userId: userId, days: windowDays)
        async let repSheetTask = try? digestService.fetchPriorMonthWrapped(userId: userId)

        let loadedReport = await reportTask ?? .empty
        let loadedVerdict = await verdictTask ?? .empty
        let repSheet = await repSheetTask ?? nil

        report = loadedReport
        verdict = loadedVerdict
        hasUnreadRepSheet = repSheet.map { $0.viewedAt == nil } ?? false
        presentation = resolvePresentation(report: loadedReport, verdict: loadedVerdict)
        focus = resolveFocus(report: loadedReport)

        // Open the day that needs attention, but never fight a choice the user
        // has already made this session.
        if expandedDayIds.isEmpty, let worst = worstDay(in: loadedReport) {
            expandedDayIds.insert(worst.id)
        }
    }

    func toggleExpansion(_ dayId: String) {
        if expandedDayIds.contains(dayId) {
            expandedDayIds.remove(dayId)
        } else {
            expandedDayIds.insert(dayId)
        }
    }

    // MARK: - Derived

    /// Days worst-first, so the one that needs a decision is never below the fold.
    var days: [DayAdherence] { report.daysByAttention }

    /// Ties the two measurements together in one sentence — the only place the
    /// tab says why the headline is what it is.
    var coachingLine: String? {
        guard case .active = presentation else { return nil }

        // The most useful thing to say is when a single day accounts for all the
        // stalled lifts, because that points at recovery or scheduling rather
        // than at any one prescription.
        let stalledDays = report.days.filter { day in
            day.exercises.contains { !$0.targetGoingUp } && day.exercises.allSatisfy { !$0.targetGoingUp }
        }
        if verdict.holding + verdict.deloading > 1,
           let day = stalledDays.first,
           day.exercises.count == verdict.holding + verdict.deloading {
            return "Every lift on the same target is on \(day.dayName). That's where the block is stuck."
        }

        if report.ratio >= 0.95, report.setsGraded > 10 {
            return "You're hitting nearly everything. The targets may be running behind you."
        }
        if report.ratio < 0.55, report.setsGraded > 10 {
            return "The plan is asking for more than you're giving right now. That's why so many lifts are holding."
        }
        return nil
    }

    // MARK: - Resolution

    private func resolvePresentation(
        report: AdherenceReport,
        verdict: ProgressionVerdict
    ) -> Presentation {
        guard let lastTrained = report.lastTrained else {
            // No adherence data isn't proof of a new account — it's also what a
            // failed fetch looks like, and what every account looks like until
            // it logs a session with targets stored. The progression verdict
            // comes from a different table, so if it has anything to say the
            // user plainly isn't on their first workout.
            return verdict.isBaseline ? .firstRun : .active
        }

        let daysSince = Calendar.current.dateComponents(
            [.day], from: lastTrained, to: Date()
        ).day ?? 0

        if daysSince >= pausedAfterDays {
            return .paused(daysSince: daysSince, lastTrained: lastTrained)
        }
        if report.isEmpty || verdict.isBaseline {
            return .baseline(
                liftsReady: verdict.total,
                liftsTotal: verdict.total + verdict.buildingBaseline
            )
        }
        return .active
    }

    /// The single lift to surface. Only one, and only when it's genuinely worse
    /// than the rest — a "fix this" card that fires every session stops being
    /// read within a week.
    private func resolveFocus(report: AdherenceReport) -> FocusItem? {
        var candidates: [(ExerciseAdherence, String)] = []
        for day in report.days {
            for exercise in day.exercises where exercise.setsGraded >= 4 {
                candidates.append((exercise, day.dayName))
            }
        }
        guard let worst = candidates.min(by: { $0.0.ratio < $1.0.ratio }),
              worst.0.ratio < 0.6
        else { return nil }

        return FocusItem(exercise: worst.0, dayName: worst.1)
    }

    private func worstDay(in report: AdherenceReport) -> DayAdherence? {
        report.days
            .filter { $0.hasTargets && $0.ratio < 0.7 }
            .min { $0.ratio < $1.ratio }
    }
}
