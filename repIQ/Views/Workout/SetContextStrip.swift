import SwiftUI

/// A bordered strip above a set's input row that tells the progression story
/// as a rail with two stops: the LAST session on the left, the TARGET on the
/// right, with a delta chip pinned to the rail between them.
///
/// Five render states:
///   1. Previous + target                     → full rail (dot ──[delta]── ring)
///   2. Previous + target + hypertrophy note  → full rail + helper line below
///   3. Target only (first session)           → half rail (scope ──── ring)
///   4. Previous only (warmup / no target)    → single dot + numbers
///   5. Completed                             → "✓ DONE ... vs last" recap
struct SetContextStrip: View {
    let previousSet: WorkoutSet?
    let targetWeight: Double?
    let targetReps: Int?
    let isBodyweightOnly: Bool
    let isCompleted: Bool
    let completedWeight: Double
    let completedReps: Int
    let completedRPE: Double?
    let showHypertrophyDropNote: Bool
    let setTypeColor: Color
    let onTargetTap: () -> Void

    var body: some View {
        Group {
            if isCompleted {
                completedView
            } else if let tW = targetWeight, let tR = targetReps {
                if let prev = previousSet {
                    fullRail(prev: prev, targetW: tW, targetR: tR)
                } else {
                    baselineRail(targetW: tW, targetR: tR)
                }
            } else if let prev = previousSet {
                lastOnlyView(prev: prev)
            } else {
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isCompleted)
    }

    // MARK: - State 1 / 2: previous + target (full rail)

    @ViewBuilder
    private func fullRail(prev: WorkoutSet, targetW: Double, targetR: Int) -> some View {
        VStack(spacing: 3) {
            railRow(showLast: true, showTarget: true, deltaChip: AnyView(deltaChip(
                prevWeight: prev.weight, prevReps: prev.reps,
                curWeight: targetW, curReps: targetR
            )))

            stopLabels(lastLabel: "LAST", targetLabel: "TARGET")

            HStack(spacing: 0) {
                lastNumbers(prev: prev)
                Spacer()
                Button(action: onTargetTap) {
                    targetNumbers(targetW: targetW, targetR: targetR)
                }
                .buttonStyle(.plain)
            }

            if showHypertrophyDropNote {
                Text("drop 1-2 reps is normal")
                    .font(.system(size: 9))
                    .foregroundColor(RQColors.textTertiary.opacity(0.6))
            }
        }
        .padding(.horizontal, RQSpacing.md)
        .padding(.vertical, RQSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(stripBackground)
    }

    /// Tiny uppercase labels sitting directly under each rail stop, just above
    /// the numbers row. Distinguishes "what is the past" from "what is today."
    @ViewBuilder
    private func stopLabels(lastLabel: String?, targetLabel: String?) -> some View {
        HStack(spacing: 0) {
            if let lastLabel {
                Text(lastLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.9)
                    .foregroundColor(RQColors.textPrimary.opacity(0.85))
            }
            Spacer()
            if let targetLabel {
                Text(targetLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.9)
                    .foregroundColor(RQColors.textPrimary.opacity(0.85))
            }
        }
    }

    // MARK: - State 3: target only (first session)

    @ViewBuilder
    private func baselineRail(targetW: Double, targetR: Int) -> some View {
        VStack(spacing: 3) {
            railRow(showLast: false, showTarget: true, deltaChip: nil)

            stopLabels(lastLabel: "FIRST TIME", targetLabel: "TARGET")

            HStack(spacing: 0) {
                HStack(spacing: 3) {
                    Image(systemName: "scope")
                        .font(.system(size: 9, weight: .semibold))
                    Text("no prior data")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(RQColors.accent.opacity(0.55))

                Spacer()

                Button(action: onTargetTap) {
                    targetNumbers(targetW: targetW, targetR: targetR)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, RQSpacing.md)
        .padding(.vertical, RQSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(stripBackground)
    }

    // MARK: - State 4: previous only (warmup / no progression target)

    @ViewBuilder
    private func lastOnlyView(prev: WorkoutSet) -> some View {
        HStack(spacing: RQSpacing.sm) {
            Circle()
                .fill(RQColors.textTertiary)
                .frame(width: 7, height: 7)
            Text("LAST")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.9)
                .foregroundColor(RQColors.textPrimary.opacity(0.85))
            lastNumbers(prev: prev)
            Spacer()
        }
        .padding(.horizontal, RQSpacing.md)
        .padding(.vertical, RQSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(stripBackground)
    }

    // MARK: - State 5: completed

    @ViewBuilder
    private var completedView: some View {
        HStack(alignment: .center, spacing: RQSpacing.sm) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(setTypeColor)
                Text("DONE")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(setTypeColor.opacity(0.85))

                if isBodyweightOnly {
                    Text("\(completedReps) reps")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(RQColors.textSecondary)
                } else {
                    Text(numbersLine(weight: completedWeight, reps: completedReps, rpe: completedRPE))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(RQColors.textSecondary)
                }
            }

            Spacer()

            if let prev = previousSet {
                deltaChip(
                    prevWeight: prev.weight, prevReps: prev.reps,
                    curWeight: completedWeight, curReps: completedReps,
                    suffix: "vs last"
                )
            }
        }
        .padding(.horizontal, RQSpacing.md)
        .padding(.vertical, RQSpacing.xs)
        .frame(maxWidth: .infinity)
        .background(stripBackground)
    }

    // MARK: - Rail

    /// The horizontal rail with optional dots at each end and an optional
    /// delta chip pinned in the middle. The chip's opaque background covers
    /// the rail behind it so it reads as "pinned" rather than overlapping.
    @ViewBuilder
    private func railRow(showLast: Bool, showTarget: Bool, deltaChip: AnyView?) -> some View {
        ZStack {
            // Rail line (full width, behind dots/chip)
            Rectangle()
                .fill(RQColors.textTertiary.opacity(0.35))
                .frame(height: 1)
                .padding(.horizontal, 5)

            HStack(spacing: 0) {
                // LAST stop (filled gray dot)
                if showLast {
                    Circle()
                        .fill(RQColors.textTertiary)
                        .frame(width: 8, height: 8)
                } else {
                    // No-history placeholder: small dotted-ring vibe via low-opacity ring
                    Circle()
                        .strokeBorder(RQColors.textTertiary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [1.5, 1.5]))
                        .frame(width: 8, height: 8)
                }

                Spacer(minLength: 6)

                if let deltaChip {
                    deltaChip
                }

                Spacer(minLength: 6)

                // TARGET stop (accent ring with a tiny inner dot)
                if showTarget {
                    ZStack {
                        Circle()
                            .strokeBorder(RQColors.accent.opacity(0.9), lineWidth: 1.5)
                            .frame(width: 10, height: 10)
                        Circle()
                            .fill(RQColors.accent)
                            .frame(width: 3, height: 3)
                    }
                } else {
                    // Should never hit (we always have a target if rail is shown), but render
                    // a placeholder for symmetry.
                    Spacer().frame(width: 10, height: 10)
                }
            }
        }
        .frame(height: 12)
    }

    // MARK: - Number rows (one line per stop, weight × reps @ rpe)

    @ViewBuilder
    private func lastNumbers(prev: WorkoutSet) -> some View {
        Text(numbersLine(
            weight: isBodyweightOnly ? nil : prev.weight,
            reps: prev.reps,
            rpe: prev.rpe
        ))
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .foregroundColor(RQColors.textPrimary.opacity(0.9))
    }

    @ViewBuilder
    private func targetNumbers(targetW: Double, targetR: Int) -> some View {
        Text(numbersLine(
            weight: isBodyweightOnly ? nil : targetW,
            reps: targetR,
            rpe: nil
        ))
        .font(.system(size: 13, weight: .semibold, design: .monospaced))
        .foregroundColor(RQColors.textPrimary)
        .contentShape(Rectangle())
    }

    /// "135 × 12 @ 4", or "12 reps @ 8" for bodyweight (weight=nil), or
    /// "135 × 12" when there's no RPE.
    private func numbersLine(weight: Double?, reps: Int, rpe: Double?) -> String {
        let core: String
        if let w = weight {
            core = "\(formatWeight(w)) × \(reps)"
        } else {
            core = "\(reps) reps"
        }
        if let rpe, rpe > 0 {
            return "\(core) @ \(formatRPE(rpe))"
        }
        return core
    }

    // MARK: - Strip background

    private var stripBackground: some View {
        RoundedRectangle(cornerRadius: RQRadius.medium, style: .continuous)
            .fill(RQColors.surfaceTertiary.opacity(0.4))
            .overlay(
                RoundedRectangle(cornerRadius: RQRadius.medium, style: .continuous)
                    .stroke(RQColors.accent.opacity(0.15), lineWidth: 0.5)
            )
    }

    // MARK: - Delta chip

    /// Chip pinned to the rail. Opaque background covers the rail line behind it.
    @ViewBuilder
    private func deltaChip(prevWeight: Double, prevReps: Int, curWeight: Double, curReps: Int) -> some View {
        deltaChip(prevWeight: prevWeight, prevReps: prevReps, curWeight: curWeight, curReps: curReps, suffix: nil)
    }

    @ViewBuilder
    private func deltaChip(
        prevWeight: Double, prevReps: Int,
        curWeight: Double, curReps: Int,
        suffix: String?
    ) -> some View {
        let weightDelta = curWeight - prevWeight
        let repsDelta = curReps - prevReps

        if weightDelta > 0.001 {
            chipBody(icon: "arrow.up", text: "+\(formatWeight(weightDelta)) lb", color: RQColors.success, suffix: suffix)
        } else if weightDelta < -0.001 {
            chipBody(icon: "arrow.down", text: "-\(formatWeight(abs(weightDelta))) lb", color: RQColors.warning, suffix: suffix)
        } else if repsDelta > 0 {
            chipBody(icon: "arrow.up", text: "+\(repsDelta) rep\(repsDelta == 1 ? "" : "s")", color: RQColors.success, suffix: suffix)
        } else if repsDelta < 0 {
            chipBody(icon: "arrow.down", text: "-\(abs(repsDelta)) rep\(abs(repsDelta) == 1 ? "" : "s")", color: RQColors.warning, suffix: suffix)
        } else {
            // Identical
            HStack(spacing: 3) {
                Text("=")
                    .font(.system(size: 10, weight: .bold))
                Text(suffix ?? "match")
                    .font(.system(size: 9))
                    .foregroundColor(RQColors.textTertiary.opacity(0.7))
            }
            .foregroundColor(RQColors.textTertiary.opacity(0.85))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(chipBackground(tint: RQColors.textTertiary))
        }
    }

    @ViewBuilder
    private func chipBody(icon: String, text: String, color: Color, suffix: String?) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 7, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
            if let suffix {
                Text(suffix)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(color.opacity(0.75))
            }
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(chipBackground(tint: color))
    }

    /// Opaque pill that covers the rail behind the chip + a tinted overlay
    /// matching the delta direction.
    @ViewBuilder
    private func chipBackground(tint: Color) -> some View {
        ZStack {
            // Solid layer to break the rail visually behind the chip.
            Capsule()
                .fill(RQColors.background)
            Capsule()
                .fill(tint.opacity(0.18))
            Capsule()
                .strokeBorder(tint.opacity(0.35), lineWidth: 0.5)
        }
    }

    // MARK: - Formatters

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }

    private func formatRPE(_ value: Double) -> String {
        String(format: "%.0f", value)
    }
}
