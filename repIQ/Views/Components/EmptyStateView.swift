import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String?
    var buttonTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: RQSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(RQColors.textTertiary)

            Text(title)
                .font(RQTypography.title3)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(RQColors.textPrimary)

            if let message {
                Text(message)
                    .font(RQTypography.subheadline)
                    .foregroundColor(RQColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let buttonTitle, let action {
                RQButton(title: buttonTitle, action: action)
                    .padding(.horizontal, RQSpacing.xxxl)
                    .padding(.top, RQSpacing.sm)
            }
        }
        .padding(RQSpacing.xxl)
    }
}
