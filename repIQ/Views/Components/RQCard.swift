import SwiftUI

struct RQCard<Content: View>: View {
    var padding: CGFloat = RQSpacing.cardPadding
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: RQSpacing.cardSpacing) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
        .cornerRadius(RQSpacing.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: RQSpacing.cardCornerRadius)
                .stroke(RQColors.textTertiary, lineWidth: 1)
        )
    }
}
