import SwiftUI

/// Target adherence by workout day.
///
/// One panel rather than a card per day: sharing a container is what lets the
/// bars share a left edge and a scale, and relative bar length is the whole
/// reason the section is scannable. Separate cards quietly prevent the one
/// comparison the section exists to make.
///
/// Days expand in place rather than pushing a screen. The workout day is a real
/// unit here — it owns the targets and the progression history — but it isn't a
/// destination, and a third navigation level would be one nobody opens.
struct DayTargetsPanel: View {
    let days: [DayAdherence]
    let expandedIds: Set<String>
    let onToggle: (String) -> Void
    let onSelectExercise: (ExerciseAdherence) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                if index > 0 {
                    Rectangle()
                        .fill(RQColors.hairline)
                        .frame(height: 1)
                }
                DayRow(
                    day: day,
                    isExpanded: expandedIds.contains(day.id),
                    onToggle: { onToggle(day.id) },
                    onSelectExercise: onSelectExercise
                )
            }
        }
        .rqSheet()
    }
}

// MARK: - Day row

private struct DayRow: View {
    let day: DayAdherence
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSelectExercise: (ExerciseAdherence) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: RQSpacing.md) {
                    heading
                    if day.hasTargets {
                        meter
                        Text(adherenceLine)
                            .font(RQTypography.sheetBody)
                            .foregroundColor(RQColors.textSecondary)
                        if let progressionLine {
                            Text(progressionLine)
                                .font(RQTypography.sheetBody)
                                .foregroundColor(RQColors.textSecondary)
                        }
                    } else {
                        Text("Logged outside a plan — no targets to measure against.")
                            .font(RQTypography.sheetBody)
                            .foregroundColor(RQColors.textTertiary)
                    }
                }
                .padding(RQSpacing.cardPadding - 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                exerciseList
            }
        }
    }

    private var heading: some View {
        HStack(alignment: .center, spacing: RQSpacing.md) {
            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                Text(day.dayName)
                    .font(RQTypography.sheetTitle)
                    .foregroundColor(RQColors.textPrimary)
                Text(recency)
                    .font(RQTypography.sheetCaption)
                    .foregroundColor(RQColors.textTertiary)
            }
            Spacer(minLength: 0)
            if day.hasTargets {
                Text("\(day.ratio.adherencePercent)%")
                    .rqFigure(RQTypography.figureM)
                    .foregroundColor(ratioColor)
            }
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(RQColors.textTertiary)
        }
    }

    private var meter: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(RQColors.surfaceTertiary)
                Capsule()
                    .fill(ratioColor)
                    .frame(width: max(geo.size.width * day.ratio, day.ratio > 0 ? 8 : 0))
            }
        }
        .frame(height: 9)
    }

    private var exerciseList: some View {
        VStack(spacing: 0) {
            ForEach(day.exercises) { exercise in
                Rectangle()
                    .fill(RQColors.hairline)
                    .frame(height: 1)
                Button {
                    onSelectExercise(exercise)
                } label: {
                    ExerciseTargetRow(exercise: exercise)
                }
                .buttonStyle(.plain)
            }
        }
        .background(RQColors.background.opacity(0.5))
    }

    // MARK: - Copy
    //
    // Every figure states its own fraction. "71%" alone is unreadable; "59 of
    // 83 sets hit" defines both the number and the bar without a legend.

    private var adherenceLine: String {
        var line = "\(day.setsHit) of \(day.setsGraded) sets hit"
        if let change = day.change, abs(change) >= 1, let previous = day.previousRatio {
            let direction = change > 0 ? "up" : "down"
            line += " · \(direction) from \(previous.adherencePercent)%"
        }
        return line
    }

    /// Written for the *next* session, because that's what a progression
    /// decision describes — it's recorded at the end of one workout and applies
    /// to the following one.
    ///
    /// Counted over lifts with enough history only, so these numbers sum across
    /// days to the fraction in the hero. Nil when no lift on the day qualifies
    /// yet — silence beats a line that quietly counts something else.
    private var progressionLine: String? {
        let total = day.trackedExercises.count
        guard total > 0 else { return nil }

        let going = day.targetsGoingUp
        if going == 0 {
            return total == 1
                ? "No target goes up next session"
                : "No targets go up next session — all \(total) holding"
        }
        if going == total {
            return "All \(total) targets go up next session"
        }
        return "\(going) of \(total) targets go up next session"
    }

    private var recency: String {
        guard let lastTrained = day.lastTrained else { return "Not trained yet" }
        let days = Calendar.current.dateComponents([.day], from: lastTrained, to: Date()).day ?? 0
        switch days {
        case ...0: return "Trained today"
        case 1: return "Trained yesterday"
        default: return "Trained \(days) days ago"
        }
    }

    /// Colour marks the one day that needs attention and nothing else. A
    /// threshold per band would force an argument nobody can win — is 69%
    /// amber and 71% green? — so there is exactly one.
    private var ratioColor: Color {
        day.ratio < 0.5 ? RQColors.stateBacking : RQColors.accent
    }
}

// MARK: - Exercise row

private struct ExerciseTargetRow: View {
    let exercise: ExerciseAdherence

    var body: some View {
        VStack(alignment: .leading, spacing: RQSpacing.sm) {
            HStack(alignment: .center, spacing: RQSpacing.md) {
                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    HStack(spacing: RQSpacing.sm) {
                        Text(exercise.exerciseName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(RQColors.textPrimary)
                        modeChip
                    }
                    Text(scopeLine)
                        .font(RQTypography.sheetCaption)
                        .foregroundColor(RQColors.textTertiary)
                }
                Spacer(minLength: 0)
                SessionCapsules(sessions: exercise.sessions)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(exercise.ratio.adherencePercent)%")
                        .rqFigure(.system(size: 14, weight: .heavy))
                        .foregroundColor(RQColors.textPrimary)
                    Text("\(exercise.setsHit)/\(exercise.setsGraded)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(RQColors.textTertiary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, RQSpacing.cardPadding - 1)
        .padding(.vertical, RQSpacing.lg - 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var modeChip: some View {
        Text(exercise.trainingMode == .strength ? "STR" : "HYP")
            .font(.system(size: 8, weight: .bold))
            .tracking(0.6)
            .foregroundColor(modeColor)
            .padding(.horizontal, RQSpacing.sm)
            .padding(.vertical, 2)
            .background(modeColor.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: RQRadius.medium, style: .continuous))
    }

    private var modeColor: Color {
        exercise.trainingMode == .strength ? RQColors.strength : RQColors.hypertrophy
    }

    /// Says what the percentage counted, which differs by mode — every working
    /// set for hypertrophy, the top set only for strength.
    private var scopeLine: String {
        exercise.trainingMode == .strength ? "Top set only" : "Every set"
    }
}

// MARK: - Session capsules

/// One capsule per session, filled by the share of that session's targets hit.
///
/// Green only at 100% — finishing everything is the thing worth spotting, and
/// under a single colour a two-of-three session looked almost identical to a
/// three-of-three one. A skipped session draws as a stub rather than an empty
/// capsule so it can't be confused with a session where nothing landed, and
/// it stays out of the maths entirely.
private struct SessionCapsules: View {
    let sessions: [SessionAdherence]

    /// Eight is what fits beside a name and a percentage at this width, and is
    /// about a month for a twice-weekly lift.
    private let maxShown = 8

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(sessions.suffix(maxShown)) { session in
                ZStack(alignment: .bottom) {
                    Capsule().fill(RQColors.surfaceTertiary)
                    Capsule()
                        .fill(session.isComplete ? RQColors.stateAdvancing : RQColors.accent)
                        .frame(height: 22 * session.ratio)
                }
                .frame(width: 8, height: 22)
            }
        }
    }
}
