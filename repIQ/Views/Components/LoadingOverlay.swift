import SwiftUI

struct LoadingOverlay: View {
    var message: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: RQSpacing.lg) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                    .scaleEffect(1.2)

                if let message {
                    Text(message)
                        .font(RQTypography.subheadline)
                        .foregroundColor(RQColors.textSecondary)
                }
            }
            .padding(RQSpacing.xxl)
            .background(Color.clear)
            .cornerRadius(RQRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: RQRadius.large)
                    .stroke(RQColors.textTertiary, lineWidth: 1)
            )
        }
    }
}
