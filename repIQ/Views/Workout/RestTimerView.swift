import SwiftUI

struct RestTimerView: View {
    @Bindable var viewModel: ActiveWorkoutViewModel

    var body: some View {
        VStack(spacing: RQSpacing.xl) {
            // Circular progress
            ZStack {
                // Background circle
                Circle()
                    .stroke(RQColors.surfaceTertiary, lineWidth: 6)
                    .frame(width: 160, height: 160)

                // Progress arc
                Circle()
                    .trim(from: 0, to: 1.0 - viewModel.restTimerProgress)
                    .stroke(
                        RQColors.accent,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: viewModel.restTimerProgress)

                // Time display
                VStack(spacing: RQSpacing.xs) {
                    Text(viewModel.restTimerDisplay)
                        .font(RQTypography.targetWeight)
                        .foregroundColor(RQColors.textPrimary)
                    Text("Rest")
                        .font(RQTypography.subheadline)
                        .foregroundColor(RQColors.textSecondary)
                }
            }

            // Skip button
            Button {
                viewModel.cancelRestTimer()
            } label: {
                Text("Skip")
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.accent)
                    .padding(.horizontal, RQSpacing.xxl)
                    .padding(.vertical, RQSpacing.md)
                    .background(RQColors.accent.opacity(0.15))
                    .cornerRadius(RQRadius.medium)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RQColors.background.opacity(0.92))
    }
}
