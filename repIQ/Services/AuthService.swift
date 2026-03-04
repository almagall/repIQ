import Foundation
import Supabase
import AuthenticationServices

struct AuthService: Sendable {
    func signUp(email: String, password: String, displayName: String?) async throws {
        let response = try await supabase.auth.signUp(
            email: email,
            password: password,
            data: displayName.map { ["display_name": .string($0)] } ?? [:]
        )
        // Profile is auto-created by the database trigger.
        // Update display_name if provided.
        if let displayName, let userId = response.session?.user.id {
            try await supabase.from("profiles")
                .update(["display_name": displayName])
                .eq("id", value: userId.uuidString)
                .execute()
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
