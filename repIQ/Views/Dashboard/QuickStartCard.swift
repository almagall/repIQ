import SwiftUI

struct QuickStartCard: View {
    var onStartWorkout: () -> Void

    var body: some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: RQSpacing.xs) {
                        Text("Ready to train?")
                            .font(RQTypography.title3)
                            .foregroundColor(RQColors.textPrimary)
                        Text("Start a workout from your templates")
                            .font(RQTypography.subheadline)
                            .foregroundColor(RQColors.textSecondary)
                    }
                    Spacer()
                }

                RQButton(title: "Start Workout") {
                    onStartWorkout()
                }
            }
        }
    }
}
