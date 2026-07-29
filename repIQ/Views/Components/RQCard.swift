import SwiftUI

struct RQCard<Content: View>: View {
    var padding: CGFloat = RQSpacing.cardPadding
    /// When false the card drops its border and inset so the content sits
    /// directly on the page. Used by the Progress tab's flow layout, where the
    /// hero is the only bordered element and everything else is separated by
    /// whitespace and hairline rules instead.
    var bordered: Bool = true
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: RQSpacing.cardSpacing) {
            content
        }
        .padding(bordered ? padding : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
        .cornerRadius(bordered ? RQSpacing.cardCornerRadius : 0)
        .overlay {
            if bordered {
                RoundedRectangle(cornerRadius: RQSpacing.cardCornerRadius)
                    .stroke(RQColors.textTertiary, lineWidth: 1)
            }
        }
    }
}
