import Foundation
import Supabase
import AuthenticationServices
import CryptoKit

@Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    var displayName = ""
    var username = ""
    var isSignUp = false
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?

    // Apple Sign-In nonce
    private var currentNonce: String?

    private let authService = AuthService()

    var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6
        if isSignUp {
            return emailValid && passwordValid && !displayName.isEmpty && isUsernameValid
        }
        return emailValid && passwordValid
    }

    var isUsernameValid: Bool {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.count <= 20 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    func signIn() async {
        guard isFormValid else {
            errorMessage = "Please fill in all fields correctly."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signIn(email: email, password: password)
        } catch {
            errorMessage = mapAuthError(error)
        }
        isLoading = false
    }

    func signUp() async {
        guard isFormValid else {
            errorMessage = "Please fill in all fields correctly."
            return
        }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            try await authService.signUp(
                email: email,
                password: password,
                displayName: displayName,
                username: username.isEmpty ? nil : username
            )
            // If email confirmation is enabled, session won't be set yet.
            // Check if we got a session — if not, the user needs to confirm email.
            let session = try? await supabase.auth.session
            if session == nil {
                successMessage = "Account created! Check your email to confirm, then sign in."
            }
        } catch {
            errorMessage = mapAuthError(error)
        }
        isLoading = false
    }

    func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            errorMessage = mapAuthError(error)
        }
    }

    // MARK: - Apple Sign-In

    func handleAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil
        do {
            guard let authorization = try? result.get(),
                  let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let idTokenString = String(data: identityToken, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Apple Sign-In failed. Please try again."
                isLoading = false
                return
            }
            try await authService.signInWithApple(idToken: idTokenString, nonce: nonce)
        } catch {
            errorMessage = mapAuthError(error)
        }
        isLoading = false
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        // Google Sign-In requires the GoogleSignIn SDK.
        // Once configured, this method will:
        // 1. Present the Google Sign-In UI
        // 2. Get the ID token and access token
        // 3. Call authService.signInWithGoogle(idToken:accessToken:)
        //
        // For now, show a configuration message.
        // To enable: Add GoogleSignIn SDK via SPM and configure your
        // Google Cloud Console OAuth client ID.
        errorMessage = "Google Sign-In requires SDK configuration. Use Apple Sign-In or email."
        isLoading = false
    }

    // MARK: - Helpers

    private func mapAuthError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("invalid login") || message.contains("invalid credentials") {
            return "Invalid email or password."
        } else if message.contains("already registered") || message.contains("already been registered") {
            return "An account with this email already exists."
        } else if message.contains("username") && (message.contains("unique") || message.contains("duplicate") || message.contains("already")) {
            return "That username is already taken. Please choose another."
        } else if message.contains("network") || message.contains("connection") {
            return "Network error. Please check your connection."
        } else if message.contains("weak password") {
            return "Password must be at least 6 characters."
        }
        return "Something went wrong. Please try again."
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce.")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
