import SwiftUI

/// A dismissible tooltip that shows once per feature, stored in AppStorage.
struct FirstTimeTooltip: View {
    let key: String
    let icon: String
    let message: String

    @AppStorage private var hasSeen: Bool

    init(key: String, icon: String, message: String) {
        self.key = key
        self.icon = icon
        self.message = message
        self._hasSeen = AppStorage(wrappedValue: false, "tooltip_\(key)")
    }

    var body: some View {
        if !hasSeen {
            HStack(alignment: .top, spacing: RQSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(RQColors.accent)
                    .frame(width: 20)

                Text(message)
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        hasSeen = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(RQColors.textTertiary)
                        .frame(width: 18, height: 18)
                        .background(RQColors.surfaceTertiary)
                        .clipShape(Circle())
                }
            }
            .padding(RQSpacing.md)
            .background(RQColors.accent.opacity(0.06))
            .cornerRadius(RQRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: RQRadius.medium)
                    .stroke(RQColors.accent.opacity(0.15), lineWidth: 1)
            )
        }
    }
}
