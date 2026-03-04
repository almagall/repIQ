import SwiftUI

enum RQButtonStyle {
    case primary
    case secondary
    case destructive
}

struct RQButton: View {
    let title: String
    var style: RQButtonStyle = .primary
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: RQSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .scaleEffect(0.8)
                }
                Text(title)
                    .font(RQTypography.headline)
                    .foregroundColor(textColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(backgroundColor)
            .cornerRadius(RQRadius.medium)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .disabled(isDisabled || isLoading)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return RQColors.accent
        case .secondary: return RQColors.surfaceTertiary
        case .destructive: return RQColors.error.opacity(0.15)
        }
    }

    private var textColor: Color {
        switch style {
        case .primary: return RQColors.background
        case .secondary: return RQColors.textPrimary
        case .destructive: return RQColors.error
        }
    }
}
