import SwiftUI

/// A Google-styled sign-in button.
/// Requires GoogleSignIn SDK to be configured in the project.
/// Add via SPM: https://github.com/google/GoogleSignIn-iOS
struct GoogleSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: RQSpacing.md) {
                // Google "G" logo approximation
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                    Text("G")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.26, green: 0.52, blue: 0.96))
                }

                Text("Sign in with Google")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white)
            .cornerRadius(RQRadius.medium)
        }
    }
}
