import SwiftUI

struct RPESelector: View {
    @Binding var selectedRPE: Double?
    var trainingMode: TrainingMode = .hypertrophy
    var compact: Bool = false

    private let rpeValues: [Double] = [6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: compact ? RQSpacing.xs : RQSpacing.sm) {
                ForEach(rpeValues, id: \.self) { value in
                    Button {
                        if selectedRPE == value {
                            selectedRPE = nil
                        } else {
                            selectedRPE = value
                        }
                    } label: {
                        Text(formatRPE(value))
                            .font(compact ? RQTypography.caption : RQTypography.numbersSmall)
                            .foregroundColor(selectedRPE == value ? RQColors.background : RQColors.textSecondary)
                            .frame(width: compact ? 32 : 40, height: compact ? 32 : 40)
                            .background(selectedRPE == value ? modeColor : Color.clear)
                            .cornerRadius(RQRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: RQRadius.small)
                                    .stroke(selectedRPE == value ? modeColor : RQColors.textTertiary, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    private var modeColor: Color {
        switch trainingMode {
        case .hypertrophy: return RQColors.hypertrophy
        case .strength: return RQColors.strength
        }
    }

    private func formatRPE(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
