import SwiftUI

/// A compact barbell plate breakdown showing plates per side.
/// Plates are ordered heaviest (inside, near collar) to lightest (outside),
/// matching how gym-goers load a barbell.
struct PlateBreakdownView: View {
    let weight: Double
    let barWeight: Double

    init(weight: Double, barWeight: Double = AppConstants.Defaults.barWeight) {
        self.weight = weight
        self.barWeight = barWeight
    }

    private var result: PlateCalculator.PlateResult? {
        PlateCalculator.calculate(totalWeight: weight, barWeight: barWeight)
    }

    var body: some View {
        guard let result, !result.plates.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            HStack(spacing: 0) {
                // Bar shaft (left side extending out)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 16, height: 6)

                // Bar collar
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 5, height: 14)

                // Plates — heaviest on inside (near collar), lightest on outside
                HStack(spacing: 1.5) {
                    ForEach(Array(result.plates.enumerated()), id: \.offset) { _, plate in
                        platePill(plate)
                    }
                }

                // Bar shaft (right side extending out)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 24, height: 6)

                Spacer()

                // Per-side label
                Text("\(formatWeight(result.perSideWeight))/side")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(RQColors.textTertiary)
            }
            .padding(.horizontal, RQSpacing.sm)
            .padding(.vertical, 4)
        )
    }

    @ViewBuilder
    private func platePill(_ weight: Double) -> some View {
        let config = plateConfig(weight)
        Text(formatPlateWeight(weight))
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundColor(config.textColor)
            .frame(width: config.width, height: config.height)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(config.color)
            )
    }

    private struct PlateConfig {
        let color: Color
        let textColor: Color
        let width: CGFloat
        let height: CGFloat
    }

    /// Olympic plate color coding (lbs) with proportional sizing.
    /// Heights are proportional to plate weight for a realistic barbell silhouette.
    private func plateConfig(_ weight: Double) -> PlateConfig {
        switch weight {
        case 45:
            return PlateConfig(
                color: Color(red: 0.2, green: 0.35, blue: 0.7),  // blue
                textColor: .white,
                width: 20, height: 34
            )
        case 35:
            return PlateConfig(
                color: Color(red: 0.75, green: 0.65, blue: 0.15), // yellow
                textColor: .black,
                width: 18, height: 30
            )
        case 25:
            return PlateConfig(
                color: Color(red: 0.2, green: 0.55, blue: 0.3),  // green
                textColor: .white,
                width: 18, height: 26
            )
        case 10:
            return PlateConfig(
                color: Color(red: 0.85, green: 0.85, blue: 0.85), // white/silver
                textColor: .black,
                width: 16, height: 22
            )
        case 5:
            return PlateConfig(
                color: Color(red: 0.7, green: 0.2, blue: 0.2),   // red
                textColor: .white,
                width: 14, height: 18
            )
        case 2.5:
            return PlateConfig(
                color: Color(red: 0.5, green: 0.5, blue: 0.5),   // gray
                textColor: .white,
                width: 14, height: 16
            )
        default:
            return PlateConfig(
                color: Color.gray,
                textColor: .white,
                width: 14, height: 18
            )
        }
    }

    private func formatPlateWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }
}
