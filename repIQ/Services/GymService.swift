import Foundation
import Supabase

struct GymService: Sendable {

    /// Saves the user's gym selection to their profile.
    func updateGym(userId: UUID, name: String, address: String, placeId: String, latitude: Double, longitude: Double) async throws {
        try await supabase.from("profiles")
            .update([
                "gym_name": name,
                "gym_address": address,
                "gym_place_id": placeId,
                "gym_latitude": "\(latitude)",
                "gym_longitude": "\(longitude)"
            ])
            .eq("id", value: userId.uuidString)
            .execute()
    }

    /// Removes the user's gym from their profile.
    func removeGym(userId: UUID) async throws {
        struct NullPayload: Encodable {
            let gym_name: String? = nil
            let gym_address: String? = nil
            let gym_place_id: String? = nil
            let gym_latitude: String? = nil
            let gym_longitude: String? = nil

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeNil(forKey: .gym_name)
                try container.encodeNil(forKey: .gym_address)
                try container.encodeNil(forKey: .gym_place_id)
                try container.encodeNil(forKey: .gym_latitude)
                try container.encodeNil(forKey: .gym_longitude)
            }

            enum CodingKeys: String, CodingKey {
                case gym_name, gym_address, gym_place_id, gym_latitude, gym_longitude
            }
        }

        try await supabase.from("profiles")
            .update(NullPayload())
            .eq("id", value: userId.uuidString)
            .execute()
    }

    /// Lightweight model for gym member display — avoids full SocialProfile decode issues.
    struct GymMember: Codable, Identifiable, Sendable {
        let id: UUID
        var username: String?
        var last_workout_date: String?

        /// Parsed date for display.
        var lastWorkoutDate: Date? {
            guard let raw = last_workout_date else { return nil }
            // Try ISO 8601 with time first, then plain date
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = iso.date(from: raw) { return d }
            iso.formatOptions = [.withInternetDateTime]
            if let d = iso.date(from: raw) { return d }
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            return df.date(from: raw)
        }
    }

    /// Fetches public users at the same gym (by place ID), excluding the current user.
    func fetchGymMembers(placeId: String, excludeUserId: UUID) async throws -> [GymMember] {
        try await supabase.from("profiles")
            .select("id, username, last_workout_date")
            .eq("gym_place_id", value: placeId)
            .neq("id", value: excludeUserId.uuidString)
            .eq("privacy_level", value: "public")
            .execute()
            .value
    }
}
