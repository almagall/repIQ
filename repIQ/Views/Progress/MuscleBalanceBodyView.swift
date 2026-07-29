import SwiftUI
import MuscleMap

/// Anatomical body diagram visualization for the Progress tab's Muscle Balance
/// section. Renders front + back silhouettes with muscles colored by training
/// volume, plus a "needs attention" watch list highlighting under-trained
/// groups. Replaces the donut chart + legend grid with a single coherent view.
///
/// Tapping a muscle on either silhouette opens a detail sheet for that group.
struct MuscleBalanceBodyView: View {
    let distribution: [MuscleGroupVolume]
    var gender: BodyGender = .male
    @State private var selectedGroup: MuscleGroupVolume?

    // MARK: - Data derivations

    /// Total sets across all muscle groups. Balance is measured in sets, not
    /// tonnage — see `MuscleGroupVolume`.
    private var totalSets: Double {
        distribution.reduce(0) { $0 + $1.setCount }
    }

    /// Active groups sorted by set count descending.
    private var sortedGroups: [MuscleGroupVolume] {
        distribution.filter { $0.setCount > 0 }.sorted { $0.setCount > $1.setCount }
    }

    /// Groups genuinely light on volume, so the user can see what's sliding.
    ///
    /// Thresholded on absolute weekly sets rather than simply taking the bottom
    /// two: a plain bottom-N always finds something to flag, which is how a
    /// well-trained muscle ends up listed as "lowest" while the diagram paints
    /// it hot. Below roughly four sets a week is where the number is actually
    /// worth acting on.
    private var watchList: [MuscleGroupVolume] {
        let untrained = distribution.filter { $0.setCount == 0 }
        let light = distribution
            .filter { $0.setCount > 0 && $0.weeklySets < 4 }
            .sorted { $0.weeklySets < $1.weeklySets }
        return (untrained + light).prefix(3).map { $0 }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: RQSpacing.lg) {
            bodyDiagramSection

            if !watchList.isEmpty {
                Divider().background(RQColors.surfaceTertiary)
                watchListSection
            }
        }
        .sheet(item: $selectedGroup) { group in
            MuscleDetailSheet(group: group, totalSets: totalSets)
        }
    }

    // MARK: - Body Diagram

    private var bodyDiagramSection: some View {
        HStack(alignment: .top, spacing: RQSpacing.sm) {
            VStack(spacing: RQSpacing.xs) {
                BodyView(gender: gender, side: .front)
                    .heatmap(heatmapData, colorScale: .workout)
                    .bodyStyle(.neon)
                    .onMuscleSelected { muscle, _ in
                        handleMuscleTap(muscle)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                Text("FRONT")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(RQColors.textTertiary)
            }

            VStack(spacing: RQSpacing.xs) {
                BodyView(gender: gender, side: .back)
                    .heatmap(heatmapData, colorScale: .workout)
                    .bodyStyle(.neon)
                    .onMuscleSelected { muscle, _ in
                        handleMuscleTap(muscle)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                Text("BACK")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(RQColors.textTertiary)
            }
        }
    }

    // MARK: - Watch List

    private var watchListSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.sm) {
            Text("LOWEST")
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundColor(RQColors.textTertiary)

            ForEach(watchList) { group in
                Button {
                    selectedGroup = group
                } label: {
                    HStack(spacing: RQSpacing.sm) {
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(RQColors.warning)
                            .frame(width: 16)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(group.color)
                            .frame(width: 10, height: 10)

                        Text(group.displayName)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textPrimary)

                        Spacer()

                        Text("\(group.weeklySetsDisplay) sets/wk")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(RQColors.textTertiary)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(RQColors.textTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Tap handling

    private func handleMuscleTap(_ muscle: Muscle) {
        // MuscleMap returns fine-grained cases (e.g., .upperBack) but our
        // distribution is keyed by coarse repIQ groups (e.g., "back"). Map
        // the tapped muscle back to our group key and find the matching row.
        guard let key = Self.repIQGroupKey(for: muscle) else { return }
        if let match = distribution.first(where: { $0.muscleGroup == key }) {
            selectedGroup = match
        }
    }

    // MARK: - Heatmap data

    /// Converts the distribution into per-muscle intensities for MuscleMap.
    /// Each repIQ group maps to one or more MuscleMap muscles, all painted at
    /// the same intensity proportional to the group's share of total sets.
    private var heatmapData: [MuscleIntensity] {
        guard totalSets > 0 else { return [] }

        // Find the highest-share group so the heatmap scales to the user's
        // own distribution — not an absolute floor. The biggest muscle always
        // reads as full intensity and the rest scale down from there.
        let maxShare = distribution.map { $0.setCount / totalSets }.max() ?? 1.0
        let effectiveMax = max(maxShare, 0.05)

        var result: [MuscleIntensity] = []
        for group in distribution where group.setCount > 0 {
            let share = group.setCount / totalSets
            let intensity = min(share / effectiveMax, 1.0)
            for muscle in Self.muscleMapping[group.muscleGroup] ?? [] {
                result.append(MuscleIntensity(muscle: muscle, intensity: intensity))
            }
        }
        return result
    }

    // MARK: - Mappings

    /// repIQ muscle group key → list of MuscleMap muscles to paint.
    static let muscleMapping: [String: [Muscle]] = [
        "chest":      [.chest],
        "shoulders":  [.deltoids],
        "biceps":     [.biceps],
        "triceps":    [.triceps],
        "forearms":   [.forearm],
        "abs":        [.abs],
        "back":       [.upperBack, .trapezius, .lowerBack],
        "quads":      [.quadriceps],
        "hamstrings": [.hamstring],
        "glutes":     [.gluteal],
        "calves":     [.calves],
    ]

    /// Reverse lookup: tapped MuscleMap muscle → repIQ group key.
    static func repIQGroupKey(for muscle: Muscle) -> String? {
        // Check parent group first (handles sub-groups like .upperChest → chest)
        let resolvedMuscle = muscle.parentGroup ?? muscle
        for (key, muscles) in muscleMapping where muscles.contains(resolvedMuscle) {
            return key
        }
        return nil
    }
}

// MARK: - Muscle Detail Sheet

/// Bottom sheet that appears when a user taps a muscle on the body diagram
/// or in the watch list. Shows volume context and actionable info.
private struct MuscleDetailSheet: View {
    let group: MuscleGroupVolume
    let totalSets: Double
    @Environment(\.dismiss) private var dismiss

    private var shareLabel: String {
        guard totalSets > 0 else { return "—" }
        return String(format: "%.0f%%", (group.setCount / totalSets) * 100)
    }

    private var volumeLabel: String {
        if group.volume >= 10_000 {
            return String(format: "%.1fK lbs", group.volume / 1000)
        }
        return String(format: "%.0f lbs", group.volume)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RQSpacing.xl) {
                    // Header
                    HStack(spacing: RQSpacing.md) {
                        RoundedRectangle(cornerRadius: RQRadius.small)
                            .fill(group.color)
                            .frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.displayName)
                                .font(RQTypography.title3)
                                .foregroundColor(RQColors.textPrimary)
                            Text("Past 30 days")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }
                    }

                    // Stats
                    HStack(spacing: 0) {
                        statTile(value: group.weeklySetsDisplay, label: "SETS / WEEK")
                        Divider().frame(height: 40).background(RQColors.surfaceTertiary)
                        statTile(value: shareLabel, label: "OF TOTAL")
                        Divider().frame(height: 40).background(RQColors.surfaceTertiary)
                        statTile(value: volumeLabel, label: "VOLUME")
                    }
                    .padding(RQSpacing.md)
                    .background(RQColors.surfaceSecondary)
                    .cornerRadius(RQSpacing.cardCornerRadius)

                    // Guidance
                    VStack(alignment: .leading, spacing: RQSpacing.sm) {
                        Text("GUIDANCE")
                            .font(RQTypography.label)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textTertiary)
                        Text(guidanceMessage)
                            .font(RQTypography.body)
                            .foregroundColor(RQColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: RQSpacing.xl)
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.top, RQSpacing.lg)
            }
            .background(RQColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(RQColors.accent)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(RQTypography.numbersSmall)
                .foregroundColor(RQColors.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(RQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Guidance is keyed off absolute weekly sets rather than share of total.
    /// Share punishes small muscles by construction — biceps take fewer sets
    /// than back at equal quality — whereas weekly set count is the number the
    /// user can actually act on.
    private var guidanceMessage: String {
        guard totalSets > 0 else {
            return "No training data yet for this muscle group."
        }
        let name = group.displayName
        if group.setCount == 0 {
            return "You haven't trained \(name.lowercased()) in this window. A couple of direct sets a week is enough to hold ground."
        }
        let weekly = group.weeklySets
        if weekly < 4 {
            return "\(name) is getting \(group.weeklySetsDisplay) sets a week. If it's a priority, adding two or three more is the simplest lever."
        }
        if weekly < 8 {
            return "\(name) sits at \(group.weeklySetsDisplay) sets a week — enough to maintain. Push higher if you want it growing."
        }
        if weekly > 22 {
            return "\(name) is taking \(group.weeklySetsDisplay) sets a week. That's a lot to recover from; make sure the quality is still there late in the week."
        }
        return "\(name) is getting \(group.weeklySetsDisplay) sets a week — a solid working range."
    }
}
