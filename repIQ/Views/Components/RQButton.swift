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
                Text(title.uppercased())
                    .font(RQTypography.headline)
                    .tracking(1.2)
                    .foregroundColor(textColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(backgroundColor)
            .cornerRadius(RQRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: RQRadius.medium)
                    .stroke(borderColor, lineWidth: 1)
            )
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .disabled(isDisabled || isLoading)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return RQColors.accent
        case .secondary: return Color.clear
        case .destructive: return Color.clear
        }
    }

    private var textColor: Color {
        switch style {
        case .primary: return RQColors.background
        case .secondary: return RQColors.textPrimary
        case .destructive: return RQColors.error
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary: return RQColors.accent
        case .secondary: return RQColors.textTertiary
        case .destructive: return RQColors.error.opacity(0.5)
        }
    }
}
