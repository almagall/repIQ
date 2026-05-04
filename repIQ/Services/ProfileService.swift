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

    func updateOnboarding(
        userId: UUID,
        experienceLevel: String?,
        trainingGoal: String?,
        sex: String? = nil,
        birthDate: Date? = nil,
        heightCm: Double? = nil,
        bodyWeightKg: Double? = nil,
        injuries: [String]? = nil
    ) async throws {
        struct Payload: Encodable {
            let has_completed_onboarding: Bool
            let experience_level: String?
            let training_goal: String?
            let sex: String?
            let birth_date: String?
            let height_cm: Double?
            let body_weight_kg: Double?
            let injuries: [String]?
        }
        let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f
        }()
        try await supabase.from("profiles")
            .update(Payload(
                has_completed_onboarding: true,
                experience_level: experienceLevel,
                training_goal: trainingGoal,
                sex: sex,
                birth_date: birthDate.map { dateFormatter.string(from: $0) },
                height_cm: heightCm,
                body_weight_kg: bodyWeightKg,
                injuries: (injuries?.isEmpty ?? true) ? nil : injuries
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
