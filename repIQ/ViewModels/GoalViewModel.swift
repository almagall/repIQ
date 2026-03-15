import Foundation
import Supabase

@Observable
final class GoalViewModel {
    var activeGoals: [Goal] = []
    var completedGoals: [Goal] = []
    var isLoading = false
    var errorMessage: String?

    private let goalService = GoalService()

    func loadGoals() async {
        isLoading = true
        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            let allGoals = try await goalService.fetchGoals(userId: userId)
            activeGoals = allGoals.filter { $0.status == .active }
            completedGoals = allGoals.filter { $0.status == .completed }

            // Auto-sync progress for active goals
            for goal in activeGoals {
                await syncGoalProgress(goal)
            }
        } catch {
            errorMessage = "Failed to load goals."
        }
        isLoading = false
    }

    func syncGoalProgress(_ goal: Goal) async {
        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            let currentValue = try await goalService.syncGoalProgress(goal: goal, userId: userId)

            // Update locally
            if let index = activeGoals.firstIndex(where: { $0.id == goal.id }) {
                activeGoals[index].currentValue = currentValue

                // Auto-complete if target reached
                if currentValue >= goal.targetValue {
                    try await goalService.completeGoal(goalId: goal.id)
                    let completed = activeGoals.remove(at: index)
                    var updated = completed
                    updated.currentValue = currentValue
                    completedGoals.insert(updated, at: 0)
                } else {
                    try await goalService.updateGoalProgress(goalId: goal.id, currentValue: currentValue)
                }
            }
        } catch {}
    }

    func abandonGoal(_ goal: Goal) async {
        do {
            try await goalService.abandonGoal(goalId: goal.id)
            activeGoals.removeAll { $0.id == goal.id }
        } catch {
            errorMessage = "Failed to abandon goal."
        }
    }

    func deleteGoal(_ goal: Goal) async {
        do {
            try await goalService.deleteGoal(goalId: goal.id)
            activeGoals.removeAll { $0.id == goal.id }
            completedGoals.removeAll { $0.id == goal.id }
        } catch {
            errorMessage = "Failed to delete goal."
        }
    }
}
