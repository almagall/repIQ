import SwiftUI

struct RQTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
                    .focused($isFocused)
            } else {
                TextField(placeholder, text: $text)
                    .focused($isFocused)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
            }
        }
        .font(RQTypography.body)
        .foregroundColor(RQColors.textPrimary)
        .padding(.horizontal, RQSpacing.lg)
        .frame(height: 50)
        .background(RQColors.surfaceTertiary)
        .cornerRadius(RQRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: RQRadius.medium)
                .stroke(isFocused ? RQColors.accent : Color.clear, lineWidth: 1)
        )
    }
}
