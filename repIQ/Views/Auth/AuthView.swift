import SwiftUI

struct AuthView: View {
    @State private var viewModel = AuthViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xxxl) {
                // Logo / Brand
                VStack(spacing: RQSpacing.md) {
                    Text("repIQ")
                        .font(RQTypography.largeTitle)
                        .tracking(4)
                        .foregroundColor(RQColors.accent)

                    Text("Intelligent Workout Planning")
                        .font(RQTypography.label)
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundColor(RQColors.textSecondary)
                }
                .padding(.top, RQSpacing.xxxl)

                // Auth Form
                if viewModel.isSignUp {
                    SignUpView(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    SignInView(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .background(RQColors.background)
        .scrollDismissesKeyboard(.interactively)
    }
}
