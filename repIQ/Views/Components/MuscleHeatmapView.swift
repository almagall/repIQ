import SwiftUI

/// Displays a simplified body silhouette with muscle groups highlighted
/// based on training volume (sets completed per muscle group).
struct MuscleHeatmapView: View {
    /// Maps muscle group name (lowercase) → sets completed this session
    let muscleVolume: [String: Int]

    @State private var showFront = true

    var body: some View {
        VStack(spacing: RQSpacing.md) {
            // Front / Back toggle
            HStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showFront = true }
                } label: {
                    Text("Front")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(showFront ? .black : RQColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(showFront ? RQColors.accent : Color.clear)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showFront = false }
                } label: {
                    Text("Back")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(!showFront ? .black : RQColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(!showFront ? RQColors.accent : Color.clear)
                }
            }
            .background(RQColors.surfaceTertiary)
            .cornerRadius(RQRadius.medium)

            // Body silhouette
            GeometryReader { geo in
                let scale = geo.size.width / 100
                ZStack {
                    if showFront {
                        FrontBodyView(muscleVolume: muscleVolume, scale: scale)
                    } else {
                        BackBodyView(muscleVolume: muscleVolume, scale: scale)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(height: 240)

            // Legend
            muscleLegend
        }
    }

    // MARK: - Legend

    private var activeMuscles: [(name: String, sets: Int)] {
        muscleVolume.filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .map { (name: $0.key.capitalized, sets: $0.value) }
    }

    private var muscleLegend: some View {
        if activeMuscles.isEmpty {
            return AnyView(EmptyView())
        }

        return AnyView(
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
        )
    }

    private func colorForMuscle(_ name: String) -> Color {
        RQColors.muscleGroupColors[name] ?? RQColors.accent
    }
}

// MARK: - Front Body

private struct FrontBodyView: View {
    let muscleVolume: [String: Int]
    let scale: CGFloat

    var body: some View {
        Canvas { ctx, _ in
            // Body outline — simplified silhouette shapes
            drawBodyOutline(ctx: ctx, scale: scale)

            // Muscle highlights
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 29, y: 31, width: 42, height: 32),
                             muscle: "chest", cornerRadius: 6)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 15, y: 28, width: 18, height: 18),
                             muscle: "shoulders", cornerRadius: 9)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 67, y: 28, width: 18, height: 18),
                             muscle: "shoulders", cornerRadius: 9)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 11, y: 48, width: 16, height: 30),
                             muscle: "biceps", cornerRadius: 5)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 73, y: 48, width: 16, height: 30),
                             muscle: "biceps", cornerRadius: 5)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 12, y: 79, width: 14, height: 26),
                             muscle: "forearms", cornerRadius: 4)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 74, y: 79, width: 14, height: 26),
                             muscle: "forearms", cornerRadius: 4)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 31, y: 63, width: 38, height: 40),
                             muscle: "abs", cornerRadius: 5)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 22, y: 118, width: 25, height: 55),
                             muscle: "quads", cornerRadius: 7)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 53, y: 118, width: 25, height: 55),
                             muscle: "quads", cornerRadius: 7)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 23, y: 177, width: 23, height: 42),
                             muscle: "calves", cornerRadius: 5)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 54, y: 177, width: 23, height: 42),
                             muscle: "calves", cornerRadius: 5)
        }
    }

    private func drawBodyOutline(ctx: GraphicsContext, scale: CGFloat) {
        let fillColor = Color(hex: "1A1A1A")
        let strokeColor = Color(hex: "333333")

        // Head
        let head = Path(ellipseIn: CGRect(x: 38, y: 2, width: 24, height: 24).scaled(by: scale))
        ctx.fill(head, with: .color(fillColor))
        ctx.stroke(head, with: .color(strokeColor), lineWidth: 0.8)

        // Neck
        let neck = Path(CGRect(x: 46, y: 25, width: 8, height: 8).scaled(by: scale))
        ctx.fill(neck, with: .color(fillColor))

        // Left upper arm
        let leftUArm = roundedRectPath(rect: CGRect(x: 10, y: 28, width: 20, height: 52).scaled(by: scale), radius: 8 * scale)
        ctx.fill(leftUArm, with: .color(fillColor))
        ctx.stroke(leftUArm, with: .color(strokeColor), lineWidth: 0.8)

        // Right upper arm
        let rightUArm = roundedRectPath(rect: CGRect(x: 70, y: 28, width: 20, height: 52).scaled(by: scale), radius: 8 * scale)
        ctx.fill(rightUArm, with: .color(fillColor))
        ctx.stroke(rightUArm, with: .color(strokeColor), lineWidth: 0.8)

        // Left forearm
        let leftFArm = roundedRectPath(rect: CGRect(x: 11, y: 79, width: 17, height: 30).scaled(by: scale), radius: 6 * scale)
        ctx.fill(leftFArm, with: .color(fillColor))
        ctx.stroke(leftFArm, with: .color(strokeColor), lineWidth: 0.8)

        // Right forearm
        let rightFArm = roundedRectPath(rect: CGRect(x: 72, y: 79, width: 17, height: 30).scaled(by: scale), radius: 6 * scale)
        ctx.fill(rightFArm, with: .color(fillColor))
        ctx.stroke(rightFArm, with: .color(strokeColor), lineWidth: 0.8)

        // Torso
        let torso = roundedRectPath(rect: CGRect(x: 27, y: 27, width: 46, height: 78).scaled(by: scale), radius: 10 * scale)
        ctx.fill(torso, with: .color(fillColor))
        ctx.stroke(torso, with: .color(strokeColor), lineWidth: 0.8)

        // Hips
        let hips = roundedRectPath(rect: CGRect(x: 22, y: 103, width: 56, height: 18).scaled(by: scale), radius: 6 * scale)
        ctx.fill(hips, with: .color(fillColor))

        // Left thigh
        let leftThigh = roundedRectPath(rect: CGRect(x: 22, y: 115, width: 26, height: 62).scaled(by: scale), radius: 8 * scale)
        ctx.fill(leftThigh, with: .color(fillColor))
        ctx.stroke(leftThigh, with: .color(strokeColor), lineWidth: 0.8)

        // Right thigh
        let rightThigh = roundedRectPath(rect: CGRect(x: 52, y: 115, width: 26, height: 62).scaled(by: scale), radius: 8 * scale)
        ctx.fill(rightThigh, with: .color(fillColor))
        ctx.stroke(rightThigh, with: .color(strokeColor), lineWidth: 0.8)

        // Left calf
        let leftCalf = roundedRectPath(rect: CGRect(x: 23, y: 174, width: 24, height: 46).scaled(by: scale), radius: 6 * scale)
        ctx.fill(leftCalf, with: .color(fillColor))
        ctx.stroke(leftCalf, with: .color(strokeColor), lineWidth: 0.8)

        // Right calf
        let rightCalf = roundedRectPath(rect: CGRect(x: 53, y: 174, width: 24, height: 46).scaled(by: scale), radius: 6 * scale)
        ctx.fill(rightCalf, with: .color(fillColor))
        ctx.stroke(rightCalf, with: .color(strokeColor), lineWidth: 0.8)
    }

    private func drawMuscleRegion(ctx: GraphicsContext, scale: CGFloat, rect: CGRect, muscle: String, cornerRadius: CGFloat) {
        let sets = muscleVolume[muscle] ?? 0
        guard sets > 0 else { return }
        let baseColor = RQColors.muscleGroupColors[muscle] ?? RQColors.accent
        let opacity = min(0.25 + Double(sets) * 0.15, 0.85)
        let path = roundedRectPath(rect: rect.scaled(by: scale), radius: cornerRadius * scale)
        ctx.fill(path, with: .color(baseColor.opacity(opacity)))
    }
}

// MARK: - Back Body

private struct BackBodyView: View {
    let muscleVolume: [String: Int]
    let scale: CGFloat

    var body: some View {
        Canvas { ctx, _ in
            drawBodyOutline(ctx: ctx, scale: scale)

            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 30, y: 28, width: 40, height: 26),
                             muscle: "back", cornerRadius: 6)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 20, y: 52, width: 22, height: 42),
                             muscle: "back", cornerRadius: 6)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 58, y: 52, width: 22, height: 42),
                             muscle: "back", cornerRadius: 6)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 11, y: 48, width: 16, height: 30),
                             muscle: "triceps", cornerRadius: 5)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 73, y: 48, width: 16, height: 30),
                             muscle: "triceps", cornerRadius: 5)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 12, y: 79, width: 14, height: 26),
                             muscle: "forearms", cornerRadius: 4)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 74, y: 79, width: 14, height: 26),
                             muscle: "forearms", cornerRadius: 4)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 22, y: 103, width: 27, height: 20),
                             muscle: "glutes", cornerRadius: 5)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 51, y: 103, width: 27, height: 20),
                             muscle: "glutes", cornerRadius: 5)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 22, y: 118, width: 25, height: 55),
                             muscle: "hamstrings", cornerRadius: 7)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 53, y: 118, width: 25, height: 55),
                             muscle: "hamstrings", cornerRadius: 7)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 23, y: 177, width: 23, height: 42),
                             muscle: "calves", cornerRadius: 5)
            drawMuscleRegion(ctx: ctx, scale: scale, rect: CGRect(x: 54, y: 177, width: 23, height: 42),
                             muscle: "calves", cornerRadius: 5)
        }
    }

    private func drawBodyOutline(ctx: GraphicsContext, scale: CGFloat) {
        let fillColor = Color(hex: "1A1A1A")
        let strokeColor = Color(hex: "333333")

        let head = Path(ellipseIn: CGRect(x: 38, y: 2, width: 24, height: 24).scaled(by: scale))
        ctx.fill(head, with: .color(fillColor))
        ctx.stroke(head, with: .color(strokeColor), lineWidth: 0.8)

        let neck = Path(CGRect(x: 46, y: 25, width: 8, height: 8).scaled(by: scale))
        ctx.fill(neck, with: .color(fillColor))

        let leftUArm = roundedRectPath(rect: CGRect(x: 10, y: 28, width: 20, height: 52).scaled(by: scale), radius: 8 * scale)
        ctx.fill(leftUArm, with: .color(fillColor))
        ctx.stroke(leftUArm, with: .color(strokeColor), lineWidth: 0.8)

        let rightUArm = roundedRectPath(rect: CGRect(x: 70, y: 28, width: 20, height: 52).scaled(by: scale), radius: 8 * scale)
        ctx.fill(rightUArm, with: .color(fillColor))
        ctx.stroke(rightUArm, with: .color(strokeColor), lineWidth: 0.8)

        let leftFArm = roundedRectPath(rect: CGRect(x: 11, y: 79, width: 17, height: 30).scaled(by: scale), radius: 6 * scale)
        ctx.fill(leftFArm, with: .color(fillColor))
        ctx.stroke(leftFArm, with: .color(strokeColor), lineWidth: 0.8)

        let rightFArm = roundedRectPath(rect: CGRect(x: 72, y: 79, width: 17, height: 30).scaled(by: scale), radius: 6 * scale)
        ctx.fill(rightFArm, with: .color(fillColor))
        ctx.stroke(rightFArm, with: .color(strokeColor), lineWidth: 0.8)

        let torso = roundedRectPath(rect: CGRect(x: 27, y: 27, width: 46, height: 78).scaled(by: scale), radius: 10 * scale)
        ctx.fill(torso, with: .color(fillColor))
        ctx.stroke(torso, with: .color(strokeColor), lineWidth: 0.8)

        let hips = roundedRectPath(rect: CGRect(x: 22, y: 103, width: 56, height: 20).scaled(by: scale), radius: 6 * scale)
        ctx.fill(hips, with: .color(fillColor))

        let leftThigh = roundedRectPath(rect: CGRect(x: 22, y: 115, width: 26, height: 62).scaled(by: scale), radius: 8 * scale)
        ctx.fill(leftThigh, with: .color(fillColor))
        ctx.stroke(leftThigh, with: .color(strokeColor), lineWidth: 0.8)

        let rightThigh = roundedRectPath(rect: CGRect(x: 52, y: 115, width: 26, height: 62).scaled(by: scale), radius: 8 * scale)
        ctx.fill(rightThigh, with: .color(fillColor))
        ctx.stroke(rightThigh, with: .color(strokeColor), lineWidth: 0.8)

        let leftCalf = roundedRectPath(rect: CGRect(x: 23, y: 174, width: 24, height: 46).scaled(by: scale), radius: 6 * scale)
        ctx.fill(leftCalf, with: .color(fillColor))
        ctx.stroke(leftCalf, with: .color(strokeColor), lineWidth: 0.8)

        let rightCalf = roundedRectPath(rect: CGRect(x: 53, y: 174, width: 24, height: 46).scaled(by: scale), radius: 6 * scale)
        ctx.fill(rightCalf, with: .color(fillColor))
        ctx.stroke(rightCalf, with: .color(strokeColor), lineWidth: 0.8)
    }

    private func drawMuscleRegion(ctx: GraphicsContext, scale: CGFloat, rect: CGRect, muscle: String, cornerRadius: CGFloat) {
        let sets = muscleVolume[muscle] ?? 0
        guard sets > 0 else { return }
        let baseColor = RQColors.muscleGroupColors[muscle] ?? RQColors.accent
        let opacity = min(0.25 + Double(sets) * 0.15, 0.85)
        let path = roundedRectPath(rect: rect.scaled(by: scale), radius: cornerRadius * scale)
        ctx.fill(path, with: .color(baseColor.opacity(opacity)))
    }
}

// MARK: - Shared Drawing Helpers

private func roundedRectPath(rect: CGRect, radius: CGFloat) -> Path {
    Path(roundedRect: rect, cornerRadius: radius)
}

private extension CGRect {
    func scaled(by factor: CGFloat) -> CGRect {
        CGRect(x: minX * factor, y: minY * factor, width: width * factor, height: height * factor)
    }
}

// MARK: - Flow Layout (wrapping HStack)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxY: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxY = y + rowHeight
        }
        return CGSize(width: width, height: maxY)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
