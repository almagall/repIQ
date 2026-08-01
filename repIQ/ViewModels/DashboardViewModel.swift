import Foundation
import Supabase

@Observable
final class DashboardViewModel {
    var recentSession: WorkoutSession?
    var weeklySetCount: Int = 0
    var totalSessionCount: Int = 0
    /// Which weekdays (0=Sun, 1=Mon, ..., 6=Sat) had a completed workout this week
    var weeklyTrainingDays: Set<Int> = []
    /// All dates (start of day) that had a completed workout
    var allTrainingDates: Set<Date> = []
    var isLoading = false
    var templateCount: Int = 0
    var templates: [Template] = []
    /// The prior month's wrapped, if it's been generated and not yet viewed.
    /// Drives the dashboard banner that appears on the 1st–14th of a new month.
    var priorMonthWrapped: RepSheet?
    /// Same verdict the Progress tab leads with. Both screens read it from
    /// `fetchProgressionRate` so the headline number can't drift between them.
    var progressionVerdict: ProgressionVerdict?

    private let workoutService = WorkoutService()
    private let templateService = TemplateService()
    private let digestService = DigestService()
    private let analyticsService = AnalyticsService()

    /// Whether the dashboard should surface the "Your X Wrapped is ready"
    /// banner card. True only on the 1st–14th of a month, when the prior
    /// month's wrapped exists, and the user hasn't viewed it yet.
    var shouldShowWrappedBanner: Bool {
        guard let wrapped = priorMonthWrapped, wrapped.viewedAt == nil else { return false }
        let day = Calendar.current.component(.day, from: Date())
        return (1...14).contains(day)
    }

    func loadDashboard() async {
        isLoading = true
        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }

            async let sessions = workoutService.fetchRecentSessions(userId: userId, limit: 1)
            async let setCount = workoutService.fetchWeeklySetCount(userId: userId)
            async let allSessions = workoutService.fetchAllSessions(userId: userId)
            async let templates = templateService.fetchTemplates(userId: userId)
            async let lastPR = fetchLastPRSummary(userId: userId)
            async let verdict = analyticsService.fetchProgressionRate(userId: userId)

            progressionVerdict = try? await verdict

            recentSession = try await sessions.first
            weeklySetCount = try await setCount
            let loadedSessions = try await allSessions
            totalSessionCount = loadedSessions.filter { $0.status == .completed }.count

            // Compute which days this week had workouts
            let calendar = Calendar.current
            let completedDates = loadedSessions
                .filter { $0.status == .completed }
                .compactMap(\.completedAt)

            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) {
                weeklyTrainingDays = Set(
                    completedDates
                        .filter { weekInterval.contains($0) }
                        .map { calendar.component(.weekday, from: $0) - 1 } // 0=Sun..6=Sat
                )
            }

            // All training dates (day granularity) for calendar view
            allTrainingDates = Set(completedDates.map { calendar.startOfDay(for: $0) })

            let loadedTemplates = try await templates
            self.templates = loadedTemplates
            templateCount = loadedTemplates.count

            let resolvedLastPR = try? await lastPR

            WidgetService.sync(WidgetService.Snapshot(
                weeklyWorkingSetCount: weeklySetCount,
                lastWorkoutDate: recentSession?.completedAt,
                lastPRSummary: resolvedLastPR
            ))

            await refreshPriorMonthWrapped(userId: userId)
        } catch {
            // Silently handle - dashboard is non-critical
        }
        isLoading = false
    }

    // MARK: - Monthly Wrapped

    /// Auto-generates the prior month's wrapped on the 1st–7th of any new
    /// month if it doesn't yet exist, then loads it for banner display.
    /// Generation is idempotent (UNIQUE constraint on user_id + month_start),
    /// so calling on later days is safe — the eq-check returns the existing row.
    private func refreshPriorMonthWrapped(userId: UUID) async {
        let day = Calendar.current.component(.day, from: Date())
        do {
            let existing = try await digestService.fetchPriorMonthWrapped(userId: userId)
            if let existing {
                priorMonthWrapped = existing
                return
            }
            // Generate during the first week of a new month so the banner has
            // something to show. After day 7 we wait for the user to navigate
            // into the wrapped flow themselves rather than running the heavy
            // aggregation on a cold dashboard load.
            if (1...7).contains(day) {
                priorMonthWrapped = try await digestService.generateRepSheet(userId: userId)
            }
        } catch {
            // Banner is non-critical; failing silently is fine here, the user
            // can still navigate to RepSheetView directly which surfaces
            // any error in its own UI.
        }
    }

    // MARK: - Widget Sync Helpers

    /// Fetches the most recent PR with the exercise name, formatted as a
    /// glanceable string for the home screen widget. Returns `nil` if the
    /// user has no PRs yet or the join can't resolve.
    private func fetchLastPRSummary(userId: UUID) async throws -> String? {
        struct PRRow: Decodable {
            let value: Double
            let reps_at_weight: Int?
            let record_type: String
            let exercises: ExerciseName?
        }
        struct ExerciseName: Decodable { let name: String }

        let rows: [PRRow] = try await supabase.from("personal_records")
            .select("value, reps_at_weight, record_type, exercises(name)")
            .eq("user_id", value: userId.uuidString)
            .order("achieved_at", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first, let exerciseName = row.exercises?.name else {
            return nil
        }
        let value = row.value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", row.value)
            : String(format: "%.1f", row.value)
        if row.record_type == "weight", let reps = row.reps_at_weight, reps > 0 {
            return "\(exerciseName) \(value)×\(reps)"
        }
        return "\(exerciseName) \(value)"
    }
}
