import Foundation
import Supabase
import AuthenticationServices

struct AuthService: Sendable {
    func signUp(email: String, password: String, displayName: String?, username: String?) async throws {
        // Pass both fields in auth metadata so the DB trigger can pick them up.
        var metadata: [String: AnyJSON] = [:]
        if let displayName { metadata["display_name"] = .string(displayName) }
        if let username { metadata["username"] = .string(username.lowercased()) }

        let response = try await supabase.auth.signUp(
            email: email,
            password: password,
            data: metadata
        )
        // Profile is auto-created by the database trigger.
        // If email confirmation is disabled and we have an immediate session, also patch directly.
        if let userId = response.session?.user.id {
            var updates: [String: String] = [:]
            if let displayName { updates["display_name"] = displayName }
            if let username { updates["username"] = username.lowercased() }
            if !updates.isEmpty {
                try await supabase.from("profiles")
                    .update(updates)
                    .eq("id", value: userId.uuidString)
                    .execute()
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    func signInWithGoogle(idToken: String, accessToken: String) async throws {
        try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken
            )
        )
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    var currentUserId: UUID? {
        get async {
            try? await supabase.auth.session.user.id
        }
    }
}
