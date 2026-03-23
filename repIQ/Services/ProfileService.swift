import Foundation
import Supabase

struct ProfileService: Sendable {
    func fetchProfile(userId: UUID) async throws -> Profile {
        try await supabase.from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
    }

    func updateProfile(_ profile: Profile) async throws {
        try await supabase.from("profiles")
            .update([
                "display_name": profile.displayName ?? "",
                "weight_unit": profile.safeWeightUnit.rawValue,
                "rest_timer_default": "\(profile.safeRestTimer)"
            ])
            .eq("id", value: profile.id.uuidString)
            .execute()
    }

    func updateWeightUnit(userId: UUID, unit: WeightUnit) async throws {
        try await supabase.from("profiles")
            .update(["weight_unit": unit.rawValue])
            .eq("id", value: userId.uuidString)
            .execute()
    }

    func updateRestTimer(userId: UUID, seconds: Int) async throws {
        try await supabase.from("profiles")
            .update(["rest_timer_default": "\(seconds)"])
            .eq("id", value: userId.uuidString)
            .execute()
    }

    func updateUsernameAndBio(userId: UUID, username: String?, bio: String?) async throws {
        struct Payload: Encodable {
            let username: String?
            let bio: String?
        }
        try await supabase.from("profiles")
            .update(Payload(username: username, bio: bio))
            .eq("id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Onboarding

    func updateOnboarding(userId: UUID, experienceLevel: String?, trainingGoal: String?) async throws {
        struct Payload: Encodable {
            let has_completed_onboarding: Bool
            let experience_level: String?
            let training_goal: String?
        }
        try await supabase.from("profiles")
            .update(Payload(
                has_completed_onboarding: true,
                experience_level: experienceLevel,
                training_goal: trainingGoal
            ))
            .eq("id", value: userId.uuidString)
            .execute()
    }

    func hasCompletedOnboarding(userId: UUID) async throws -> Bool {
        let profile: Profile = try await supabase.from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
        return profile.safeHasCompletedOnboarding
    }
}
