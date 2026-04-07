import SwiftUI

/// Compact coaching feedback chip shown below a completed working set.
struct SetFeedbackChipView: View {
    let feedback: SetFeedback
    @Binding var isExpanded: Bool
    @Binding var isMinimized: Bool

    var body: some View {
        if isMinimized { return AnyView(EmptyView()) }

        return AnyView(
            Button {
                if !feedback.isBaseline {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack(spacing: RQSpacing.sm) {
                    // Color accent bar
                    RoundedRectangle(cornerRadius: 1)
                        .fill(feedback.outcome.color)
                        .frame(width: 2.5)

                    // Icon
                    Image(systemName: feedback.isBaseline ? "chart.line.uptrend.xyaxis" : feedback.outcome.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(feedback.outcome.color)

                    // Text content
                    VStack(alignment: .leading, spacing: isExpanded ? RQSpacing.xs : 0) {
                        HStack(spacing: RQSpacing.xs) {
                            Text(feedback.outcome.label)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(feedback.outcome.color)

                            Text("—")
                                .font(.system(size: 10))
                                .foregroundColor(RQColors.textTertiary)

                            Text(feedback.headline)
                                .font(.system(size: 11))
                                .foregroundColor(RQColors.textSecondary)
                                .lineLimit(1)
                        }

                        if isExpanded {
                            Text(feedback.detail)
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                                .transition(.opacity)
                        }
                    }

                    Spacer()

                    if !feedback.isBaseline {
                        // Expand/collapse chevron
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(RQColors.textTertiary)
                    }

                    // Minimize button
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isMinimized = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(RQColors.textTertiary)
                            .padding(4)
                    }
                }
                .padding(.horizontal, RQSpacing.sm)
                .padding(.vertical, RQSpacing.xs)
                .background(feedback.outcome.color.opacity(0.08))
                .cornerRadius(RQRadius.small)
            }
            .buttonStyle(.plain)
        )
    }
}
