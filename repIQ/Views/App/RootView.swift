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
                await checkOnboarding()
            case .signedOut:
                isAuthenticated = false
                needsOnboarding = false
            default:
                break
            }
        }
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
