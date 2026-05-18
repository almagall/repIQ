import SwiftUI

/// Section header used across the Progress tab and elsewhere. Renders an
/// uppercase, letter-spaced label with an optional trailing info button.
struct RQSectionHeader: View {
    let title: String
    var infoTopic: ProgressExplainer.Topic? = nil
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: RQSpacing.xs) {
            Text(title)
                .font(RQTypography.label)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(RQColors.textSecondary)

            if let infoTopic {
                InfoButton(topic: infoTopic)
            }

            Spacer()

            if let trailing {
                trailing
            }
        }
    }
}
