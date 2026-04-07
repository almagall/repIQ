import SwiftUI
import Supabase

@Observable
final class AppState {
    var isAuthenticated = false
    var isLoading = true
    var needsOnboarding = false

    func listenToAuthChanges() async {
        for await (event, _) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession:
                let session = try? await supabase.auth.session
                isAuthenticated = session != nil
                if isAuthenticated {
                    await checkOnboarding()
                }
                isLoading = false
            case .signedIn:
                isAuthenticated = true
                await syncUsernameFromMetadata()
                await checkOnboarding()
            case .signedOut:
                isAuthenticated = false
                needsOnboarding = false
            default:
                break
            }
        }
    }

    /// If the user signed up with a username in metadata but the profile
    /// doesn't have it yet (e.g. email confirmation delayed the UPDATE),
    /// patch it now on first sign-in.
    private func syncUsernameFromMetadata() async {
        guard let session = try? await supabase.auth.session else { return }
        let userId = session.user.id
        guard let metaUsername = session.user.userMetadata["username"]?.stringValue,
              !metaUsername.isEmpty else { return }

        struct Row: Decodable { let username: String? }
        guard let row: Row = try? await supabase.from("profiles")
            .select("username")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value,
              row.username == nil || row.username?.isEmpty == true
        else { return }

        try? await supabase.from("profiles")
            .update(["username": metaUsername])
            .eq("id", value: userId.uuidString)
            .execute()
    }

    private func checkOnboarding() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        let completed = (try? await ProfileService().hasCompletedOnboarding(userId: userId)) ?? true
        needsOnboarding = !completed
    }

    func completeOnboarding() {
        needsOnboarding = false
    }
}

struct RootView: View {
    @State private var appState = AppState()

    var body: some View {
        Group {
            if appState.isLoading {
                splashView
            } else if appState.isAuthenticated {
                if appState.needsOnboarding {
                    OnboardingView {
                        appState.completeOnboarding()
                    }
                } else {
                    MainTabView()
                }
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: appState.isLoading)
        .animation(.easeInOut(duration: 0.3), value: appState.needsOnboarding)
        .task {
            await appState.listenToAuthChanges()
        }
    }

    private var splashView: some View {
        ZStack {
            RQColors.background.ignoresSafeArea()
            VStack(spacing: RQSpacing.lg) {
                Text("repIQ")
                    .font(RQTypography.largeTitle)
                    .foregroundColor(RQColors.accent)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
            }
        }
    }
}
