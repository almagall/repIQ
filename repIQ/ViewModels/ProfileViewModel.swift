import Foundation
import Supabase

@Observable
final class ProfileViewModel {
    var profile: Profile?
    var isLoading = false
    var errorMessage: String?

    private let profileService = ProfileService()
    private let authService = AuthService()

    func loadProfile() async {
        isLoading = true
        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            profile = try await profileService.fetchProfile(userId: userId)
        } catch {
            errorMessage = "Failed to load profile."
        }
        isLoading = false
    }

    func updateWeightUnit(_ unit: WeightUnit) async {
        guard let profile else { return }
        do {
            try await profileService.updateWeightUnit(userId: profile.id, unit: unit)
            self.profile?.weightUnit = unit
        } catch {
            errorMessage = "Failed to update weight unit."
        }
    }

    func updateRestTimer(_ seconds: Int) async {
        guard let profile else { return }
        do {
            try await profileService.updateRestTimer(userId: profile.id, seconds: seconds)
            self.profile?.restTimerDefault = seconds
        } catch {
            errorMessage = "Failed to update rest timer."
        }
    }

    func updateUsernameAndBio(username: String?, bio: String?) async {
        guard let profile else { return }
        do {
            try await profileService.updateUsernameAndBio(userId: profile.id, username: username, bio: bio)
            self.profile?.username = username
            self.profile?.bio = bio
        } catch {
            errorMessage = "Failed to update username."
        }
    }

    /// Persists body/injury profile data and reflects it on the in-memory
    /// profile so dependent views update without an extra fetch.
    func updateBodyProfile(
        sex: String?,
        birthDate: Date?,
        heightCm: Double?,
        bodyWeightKg: Double?,
        injuries: [String]?
    ) async throws {
        guard let profile else { return }
        try await profileService.updateBodyProfile(
            userId: profile.id,
            sex: sex,
            birthDate: birthDate,
            heightCm: heightCm,
            bodyWeightKg: bodyWeightKg,
            injuries: injuries
        )
        self.profile?.sex = sex
        self.profile?.birthDate = birthDate
        self.profile?.heightCm = heightCm
        self.profile?.bodyWeightKg = bodyWeightKg
        self.profile?.injuries = injuries
    }

    func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            errorMessage = "Failed to sign out."
        }
    }
}
