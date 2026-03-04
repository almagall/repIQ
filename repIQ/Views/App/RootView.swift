import SwiftUI
import Supabase

@Observable
final class AppState {
    var isAuthenticated = false
    var isLoading = true

    func listenToAuthChanges() async {
        for await (event, _) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession:
                let session = try? await supabase.auth.session
                isAuthenticated = session != nil
                isLoading = false
            case .signedIn:
                isAuthenticated = true
            case .signedOut:
                isAuthenticated = false
            default:
                break
            }
        }
    }
}

struct RootView: View {
    @State private var appState = AppState()

    var body: some View {
        Group {
            if appState.isLoading {
                splashView
            } else if appState.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: appState.isLoading)
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
