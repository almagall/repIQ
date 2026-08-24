import SwiftUI

/// The single lift worth acting on.
///
/// Capped at one by design. A "fix this" card that fires every session stops
/// being read within a week, so `TargetsOverviewViewModel` only produces one
/// when a lift is genuinely worse than the rest — and produces none at all when
/// nothing is wrong, which is the common case for a well-calibrated account.
struct TargetFocusCard: View {
    let focus: TargetsOverviewViewModel.FocusItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: RQSpacing.lg) {
                HStack(spacing: RQSpacing.lg) {
                    icon
                    VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                        Text(focus.exercise.exerciseName)
                            .font(RQTypography.sheetTitle)
                            .foregroundColor(RQColors.textPrimary)
                        Text("\(focus.dayName) · \(focus.exercise.setsHit) of \(focus.exercise.setsGraded) sets hit")
                            .font(RQTypography.sheetCaption)
                            .foregroundColor(RQColors.textTertiary)
                    }
                    Spacer(minLength: 0)
                }

                Text(diagnosis)
                    .font(RQTypography.sheetBody)
                    .foregroundColor(RQColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("See what's wrong")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(RQColors.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RQSpacing.lg - 2)
                    .background(RQColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: RQRadius.sheetInner, style: .continuous))
            }
            .padding(RQSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .rqSheet(fill: RQColors.surfaceSecondary, elevated: true)
        }
        .buttonStyle(.plain)
    }

    private var icon: some View {
        Image(systemName: "scope")
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(RQColors.background)
            .frame(width: 36, height: 36)
            .background(RQColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: RQRadius.sheetInner, style: .continuous))
    }

    /// Names the pattern rather than restating the number the row above already
    /// gave. Which set position fails is the difference between a load problem
    /// and a volume problem, and they have opposite fixes.
    private var diagnosis: String {
        let mode = focus.exercise.trainingMode
        if mode == .strength {
            return "You're missing the top set more often than not — the weight is ahead of you right now."
        }
        // Sessions where nothing at all landed point at the load; sessions where
        // most sets landed and one didn't point at running out of room.
        let sessions = focus.exercise.sessions
        let totalMisses = sessions.filter { $0.setsHit == 0 }.count
        if totalMisses >= max(sessions.count / 2, 1) {
            return "You're missing from the first set, which means the weight is too heavy — not that you ran out of gas."
        }
        return "The early sets land and the last ones don't. That's session fatigue, so the load is probably right and the volume isn't."
    }
}
