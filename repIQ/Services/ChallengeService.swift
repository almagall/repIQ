import Foundation
import Supabase

/// Manages head-to-head challenges and clubs (training groups).
struct ChallengeService: Sendable {

    // MARK: - Challenges

    /// Creates a new challenge between two users.
    func createChallenge(
        challengerId: UUID,
        challengedId: UUID,
        challengeType: ChallengeType,
        exerciseId: UUID? = nil,
        durationDays: Int = 7
    ) async throws {
        struct CreatePayload: Encodable {
            let challenger_id: String
            let challenged_id: String
            let challenge_type: String
            let exercise_id: String?
            let duration_days: Int
            let start_date: String
            let end_date: String
            let status: String
        }

        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: durationDays, to: startDate) ?? startDate

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        try await supabase.from("challenges")
            .insert(CreatePayload(
                challenger_id: challengerId.uuidString,
                challenged_id: challengedId.uuidString,
                challenge_type: challengeType.rawValue,
                exercise_id: exerciseId?.uuidString,
                duration_days: durationDays,
                start_date: dateFormatter.string(from: startDate),
                end_date: dateFormatter.string(from: endDate),
                status: "pending"
            ))
            .execute()
    }

    /// Accepts a challenge.
    func acceptChallenge(challengeId: UUID) async throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())

        // Re-calculate end date from today
        struct ChallengeRow: Decodable { let duration_days: Int }
        let row: ChallengeRow = try await supabase.from("challenges")
            .select("duration_days")
            .eq("id", value: challengeId.uuidString)
            .single()
            .execute()
            .value

        let endDate = Calendar.current.date(byAdding: .day, value: row.duration_days, to: Date()) ?? Date()

        try await supabase.from("challenges")
            .update([
                "status": "active",
                "start_date": today,
                "end_date": dateFormatter.string(from: endDate)
            ])
            .eq("id", value: challengeId.uuidString)
            .execute()
    }

    /// Declines a challenge.
    func declineChallenge(challengeId: UUID) async throws {
        try await supabase.from("challenges")
            .update(["status": "declined"])
            .eq("id", value: challengeId.uuidString)
            .execute()
    }

    /// Fetches active and pending challenges for a user.
    func fetchChallenges(userId: UUID) async throws -> [Challenge] {
        let asChallenger: [Challenge] = try await supabase.from("challenges")
            .select("*, challenger_profiles:profiles!challenges_challenger_id_fkey(*), challenged_profiles:profiles!challenges_challenged_id_fkey(*)")
            .eq("challenger_id", value: userId.uuidString)
            .in("status", values: ["pending", "active"])
            .order("created_at", ascending: false)
            .execute()
            .value

        let asChallenged: [Challenge] = try await supabase.from("challenges")
            .select("*, challenger_profiles:profiles!challenges_challenger_id_fkey(*), challenged_profiles:profiles!challenges_challenged_id_fkey(*)")
            .eq("challenged_id", value: userId.uuidString)
            .in("status", values: ["pending", "active"])
            .order("created_at", ascending: false)
            .execute()
            .value

        return asChallenger + asChallenged
    }

    /// Fetches completed challenges for a user.
    func fetchCompletedChallenges(userId: UUID, limit: Int = 20) async throws -> [Challenge] {
        let asChallenger: [Challenge] = try await supabase.from("challenges")
            .select("*, challenger_profiles:profiles!challenges_challenger_id_fkey(*), challenged_profiles:profiles!challenges_challenged_id_fkey(*)")
            .eq("challenger_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        let asChallenged: [Challenge] = try await supabase.from("challenges")
            .select("*, challenger_profiles:profiles!challenges_challenger_id_fkey(*), challenged_profiles:profiles!challenges_challenged_id_fkey(*)")
            .eq("challenged_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return (asChallenger + asChallenged).sorted { ($0.createdAt) > ($1.createdAt) }
    }

    /// Updates challenge scores.
    func updateChallengeScore(challengeId: UUID, challengerScore: Double, challengedScore: Double) async throws {
        struct ScorePayload: Encodable {
            let challenger_score: Double
            let challenged_score: Double
        }

        try await supabase.from("challenges")
            .update(ScorePayload(
                challenger_score: challengerScore,
                challenged_score: challengedScore
            ))
            .eq("id", value: challengeId.uuidString)
            .execute()
    }

    /// Completes a challenge and sets the winner.
    func completeChallenge(challengeId: UUID, winnerId: UUID?) async throws {
        struct CompletePayload: Encodable {
            let status: String
            let winner_id: String?
        }

        try await supabase.from("challenges")
            .update(CompletePayload(
                status: "completed",
                winner_id: winnerId?.uuidString
            ))
            .eq("id", value: challengeId.uuidString)
            .execute()
    }

    // MARK: - Clubs

    /// Creates a new club.
    func createClub(ownerId: UUID, name: String, description: String, isPublic: Bool) async throws -> Club {
        struct CreatePayload: Encodable {
            let owner_id: String
            let name: String
            let description: String
            let is_public: Bool
        }

        let club: Club = try await supabase.from("clubs")
            .insert(CreatePayload(
                owner_id: ownerId.uuidString,
                name: name,
                description: description,
                is_public: isPublic
            ))
            .select()
            .single()
            .execute()
            .value

        // Add owner as member with owner role
        struct MemberPayload: Encodable {
            let club_id: String
            let user_id: String
            let role: String
        }

        try await supabase.from("club_members")
            .insert(MemberPayload(
                club_id: club.id.uuidString,
                user_id: ownerId.uuidString,
                role: "owner"
            ))
            .execute()

        return club
    }

    /// Fetches clubs a user belongs to.
    func fetchUserClubs(userId: UUID) async throws -> [Club] {
        struct MemberClub: Decodable {
            let clubs: Club
        }

        let memberships: [MemberClub] = try await supabase.from("club_members")
            .select("clubs(*)")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        return memberships.map(\.clubs)
    }

    /// Fetches public clubs for discovery.
    func fetchPublicClubs(limit: Int = 20) async throws -> [Club] {
        try await supabase.from("clubs")
            .select()
            .eq("is_public", value: true)
            .order("member_count", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Joins a club.
    func joinClub(clubId: UUID, userId: UUID) async throws {
        struct JoinPayload: Encodable {
            let club_id: String
            let user_id: String
            let role: String
        }

        try await supabase.from("club_members")
            .insert(JoinPayload(
                club_id: clubId.uuidString,
                user_id: userId.uuidString,
                role: "member"
            ))
            .execute()

        // Increment member count
        struct CountRow: Decodable { let member_count: Int }
        let row: CountRow = try await supabase.from("clubs")
            .select("member_count")
            .eq("id", value: clubId.uuidString)
            .single()
            .execute()
            .value

        try await supabase.from("clubs")
            .update(["member_count": row.member_count + 1])
            .eq("id", value: clubId.uuidString)
            .execute()
    }

    /// Leaves a club.
    func leaveClub(clubId: UUID, userId: UUID) async throws {
        try await supabase.from("club_members")
            .delete()
            .eq("club_id", value: clubId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()

        // Decrement member count
        struct CountRow: Decodable { let member_count: Int }
        let row: CountRow = try await supabase.from("clubs")
            .select("member_count")
            .eq("id", value: clubId.uuidString)
            .single()
            .execute()
            .value

        try await supabase.from("clubs")
            .update(["member_count": max(0, row.member_count - 1)])
            .eq("id", value: clubId.uuidString)
            .execute()
    }

    /// Fetches members of a club.
    func fetchClubMembers(clubId: UUID) async throws -> [ClubMember] {
        try await supabase.from("club_members")
            .select("*, profiles(*)")
            .eq("club_id", value: clubId.uuidString)
            .order("joined_at")
            .execute()
            .value
    }
}
