import SwiftUI
import MuscleMap

/// Displays an anatomically accurate body diagram with muscle groups highlighted
/// based on training volume (sets completed per muscle group).
struct MuscleHeatmapView: View {
    /// Maps muscle group name (lowercase) → sets completed this session
    let muscleVolume: [String: Int]
    var gender: BodyGender = .male

    var body: some View {
        VStack(spacing: RQSpacing.md) {
            // Front + Back diagrams side by side
            HStack(spacing: RQSpacing.sm) {
                VStack(spacing: RQSpacing.xxs) {
                    BodyView(gender: gender, side: .front)
                        .heatmap(heatmapData, colorScale: .workout)
                        .bodyStyle(.neon)
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                    Text("Front")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }

                VStack(spacing: RQSpacing.xxs) {
                    BodyView(gender: gender, side: .back)
                        .heatmap(heatmapData, colorScale: .workout)
                        .bodyStyle(.neon)
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                    Text("Back")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }
            }

            // Legend
            muscleLegend
        }
    }

    // MARK: - Heatmap Data

    private var heatmapData: [MuscleIntensity] {
        var result: [MuscleIntensity] = []
        for (key, sets) in muscleVolume where sets > 0 {
            let intensity = min(Double(sets) / 6.0, 1.0)
            let muscles = muscleMappings[key] ?? []
            for muscle in muscles {
                result.append(MuscleIntensity(muscle: muscle, intensity: intensity))
            }
        }
        return result
    }

    /// Maps repIQ muscle group keys to MuscleMap Muscle cases.
    private let muscleMappings: [String: [Muscle]] = [
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

    // MARK: - Legend

    private var activeMuscles: [(name: String, sets: Int)] {
        muscleVolume.filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .map { (name: $0.key.capitalized, sets: $0.value) }
    }

    private var muscleLegend: some View {
        Group {
            if !activeMuscles.isEmpty {
                VStack(alignment: .leading, spacing: RQSpacing.xs) {
                    Text("Muscles Trained")
                        .font(RQTypography.label)
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .foregroundColor(RQColors.textSecondary)

                    FlowLayout(spacing: RQSpacing.xs) {
                        ForEach(activeMuscles, id: \.name) { item in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(colorForMuscle(item.name.lowercased()))
                                    .frame(width: 8, height: 8)
                                Text("\(item.name) (\(item.sets))")
                                    .font(.system(size: 11))
                                    .foregroundColor(RQColors.textSecondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(colorForMuscle(item.name.lowercased()).opacity(0.12))
                            .cornerRadius(RQRadius.small)
                        }
                    }
                }
            }
        }
    }

    private func colorForMuscle(_ name: String) -> Color {
        RQColors.muscleGroupColors[name] ?? RQColors.accent
    }
}
