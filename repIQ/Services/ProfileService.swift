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
                "weight_unit": profile.weightUnit.rawValue,
                "rest_timer_default": "\(profile.restTimerDefault)"
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
}
