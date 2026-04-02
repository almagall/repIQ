import SwiftUI

/// Displays an anatomically-shaped body silhouette with muscle groups highlighted
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
            drawSilhouette(ctx: ctx)
            drawMuscles(ctx: ctx)
        }
    }

    // MARK: Silhouette

    private func drawSilhouette(ctx: GraphicsContext) {
        // Torso first (background layer)
        let torso = torsoPath()
        ctx.fill(torso, with: .color(kBodyFill))
        ctx.stroke(torso, with: .color(kBodyStroke), lineWidth: 0.8)

        // Head
        bodyEllipse(ctx, x: 38, y: 2, w: 24, h: 26)
        // Neck
        bodyEllipse(ctx, x: 46, y: 26, w: 8, h: 8)

        // Deltoid caps (overlap torso shoulders)
        bodyEllipse(ctx, x: 12, y: 28, w: 20, h: 17)
        bodyEllipse(ctx, x: 68, y: 28, w: 20, h: 17)

        // Upper arms
        bodyEllipse(ctx, x: 9, y: 40, w: 18, h: 44)
        bodyEllipse(ctx, x: 73, y: 40, w: 18, h: 44)

        // Forearms
        bodyEllipse(ctx, x: 10, y: 82, w: 16, h: 28)
        bodyEllipse(ctx, x: 74, y: 82, w: 16, h: 28)

        // Hands
        bodyEllipse(ctx, x: 12, y: 108, w: 13, h: 9)
        bodyEllipse(ctx, x: 75, y: 108, w: 13, h: 9)

        // Hip bridge
        bodyEllipse(ctx, x: 21, y: 103, w: 58, h: 16)

        // Thighs
        bodyEllipse(ctx, x: 21, y: 113, w: 26, h: 60)
        bodyEllipse(ctx, x: 53, y: 113, w: 26, h: 60)

        // Knees
        bodyEllipse(ctx, x: 22, y: 169, w: 24, h: 11)
        bodyEllipse(ctx, x: 54, y: 169, w: 24, h: 11)

        // Calves
        bodyEllipse(ctx, x: 22, y: 178, w: 23, h: 40)
        bodyEllipse(ctx, x: 55, y: 178, w: 23, h: 40)

        // Feet
        bodyEllipse(ctx, x: 21, y: 215, w: 24, h: 8)
        bodyEllipse(ctx, x: 55, y: 215, w: 24, h: 8)
    }

    // MARK: Muscles

    private func drawMuscles(ctx: GraphicsContext) {
        // Chest (two pecs)
        muscleEllipse(ctx, x: 29, y: 34, w: 20, h: 22, muscle: "chest")
        muscleEllipse(ctx, x: 51, y: 34, w: 20, h: 22, muscle: "chest")

        // Shoulders (front deltoids)
        muscleEllipse(ctx, x: 13, y: 29, w: 17, h: 15, muscle: "shoulders")
        muscleEllipse(ctx, x: 70, y: 29, w: 17, h: 15, muscle: "shoulders")

        // Biceps
        muscleEllipse(ctx, x: 10, y: 47, w: 13, h: 28, muscle: "biceps")
        muscleEllipse(ctx, x: 77, y: 47, w: 13, h: 28, muscle: "biceps")

        // Forearms
        muscleEllipse(ctx, x: 11, y: 84, w: 11, h: 22, muscle: "forearms")
        muscleEllipse(ctx, x: 78, y: 84, w: 11, h: 22, muscle: "forearms")

        // Abs (6-pack segments)
        absSegments(ctx)

        // Quads
        muscleEllipse(ctx, x: 23, y: 118, w: 22, h: 50, muscle: "quads")
        muscleEllipse(ctx, x: 55, y: 118, w: 22, h: 50, muscle: "quads")

        // Calves
        muscleEllipse(ctx, x: 24, y: 180, w: 17, h: 34, muscle: "calves")
        muscleEllipse(ctx, x: 59, y: 180, w: 17, h: 34, muscle: "calves")
    }

    // 6-pack style abs: 3 rows of 2 oval segments
    private func absSegments(_ ctx: GraphicsContext) {
        let sets = muscleVolume["abs"] ?? 0
        guard sets > 0 else { return }
        let opacity = muscleOpacity(sets)
        let color = (RQColors.muscleGroupColors["abs"] ?? RQColors.accent).opacity(opacity)
        for row in 0..<3 {
            let y: CGFloat = 60 + CGFloat(row) * 14
            let leftPath = Path(ellipseIn: CGRect(x: sc(35), y: sc(y), width: sc(12), height: sc(11)))
            let rightPath = Path(ellipseIn: CGRect(x: sc(53), y: sc(y), width: sc(12), height: sc(11)))
            ctx.fill(leftPath, with: .color(color))
            ctx.fill(rightPath, with: .color(color))
        }
    }

    // MARK: Torso path — V-taper: broad shoulders, narrow waist, slight hip flare

    private func torsoPath() -> Path {
        var p = Path()
        p.move(to: sp(55, 30))
        // Right shoulder
        p.addQuadCurve(to: sp(73, 40), control: sp(70, 30))
        // Right armpit
        p.addQuadCurve(to: sp(73, 58), control: sp(78, 50))
        // Right side to waist
        p.addQuadCurve(to: sp(68, 88), control: sp(73, 72))
        // Right hip flare
        p.addQuadCurve(to: sp(72, 106), control: sp(68, 98))
        // Bottom
        p.addLine(to: sp(28, 106))
        // Left hip
        p.addQuadCurve(to: sp(32, 88), control: sp(32, 98))
        // Left waist
        p.addQuadCurve(to: sp(27, 58), control: sp(27, 72))
        // Left armpit
        p.addQuadCurve(to: sp(27, 40), control: sp(22, 50))
        // Left shoulder back to neck
        p.addQuadCurve(to: sp(45, 30), control: sp(30, 30))
        p.closeSubpath()
        return p
    }

    // MARK: Helpers

    private func sc(_ v: CGFloat) -> CGFloat { v * scale }
    private func sp(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * scale, y: y * scale) }

    private func bodyEllipse(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        let path = Path(ellipseIn: CGRect(x: sc(x), y: sc(y), width: sc(w), height: sc(h)))
        ctx.fill(path, with: .color(kBodyFill))
        ctx.stroke(path, with: .color(kBodyStroke), lineWidth: 0.8)
    }

    private func muscleEllipse(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, muscle: String) {
        let sets = muscleVolume[muscle] ?? 0
        guard sets > 0 else { return }
        let color = (RQColors.muscleGroupColors[muscle] ?? RQColors.accent).opacity(muscleOpacity(sets))
        ctx.fill(Path(ellipseIn: CGRect(x: sc(x), y: sc(y), width: sc(w), height: sc(h))), with: .color(color))
    }
}

// MARK: - Back Body

private struct BackBodyView: View {
    let muscleVolume: [String: Int]
    let scale: CGFloat

    var body: some View {
        Canvas { ctx, _ in
            drawSilhouette(ctx: ctx)
            drawMuscles(ctx: ctx)
        }
    }

    // MARK: Silhouette (mirrors front)

    private func drawSilhouette(ctx: GraphicsContext) {
        let torso = torsoPath()
        ctx.fill(torso, with: .color(kBodyFill))
        ctx.stroke(torso, with: .color(kBodyStroke), lineWidth: 0.8)

        bodyEllipse(ctx, x: 38, y: 2, w: 24, h: 26)
        bodyEllipse(ctx, x: 46, y: 26, w: 8, h: 8)

        bodyEllipse(ctx, x: 12, y: 28, w: 20, h: 17)
        bodyEllipse(ctx, x: 68, y: 28, w: 20, h: 17)

        bodyEllipse(ctx, x: 9, y: 40, w: 18, h: 44)
        bodyEllipse(ctx, x: 73, y: 40, w: 18, h: 44)

        bodyEllipse(ctx, x: 10, y: 82, w: 16, h: 28)
        bodyEllipse(ctx, x: 74, y: 82, w: 16, h: 28)

        bodyEllipse(ctx, x: 12, y: 108, w: 13, h: 9)
        bodyEllipse(ctx, x: 75, y: 108, w: 13, h: 9)

        bodyEllipse(ctx, x: 21, y: 103, w: 58, h: 16)

        bodyEllipse(ctx, x: 21, y: 113, w: 26, h: 60)
        bodyEllipse(ctx, x: 53, y: 113, w: 26, h: 60)

        bodyEllipse(ctx, x: 22, y: 169, w: 24, h: 11)
        bodyEllipse(ctx, x: 54, y: 169, w: 24, h: 11)

        bodyEllipse(ctx, x: 22, y: 178, w: 23, h: 40)
        bodyEllipse(ctx, x: 55, y: 178, w: 23, h: 40)

        bodyEllipse(ctx, x: 21, y: 215, w: 24, h: 8)
        bodyEllipse(ctx, x: 55, y: 215, w: 24, h: 8)
    }

    // MARK: Muscles

    private func drawMuscles(ctx: GraphicsContext) {
        // Trapezius
        muscleEllipse(ctx, x: 30, y: 28, w: 40, h: 20, muscle: "back")
        // Lats (left + right)
        muscleEllipse(ctx, x: 21, y: 46, w: 22, h: 42, muscle: "back")
        muscleEllipse(ctx, x: 57, y: 46, w: 22, h: 42, muscle: "back")
        // Lower back
        muscleEllipse(ctx, x: 36, y: 85, w: 28, h: 16, muscle: "back")

        // Rear deltoids
        muscleEllipse(ctx, x: 13, y: 29, w: 17, h: 15, muscle: "shoulders")
        muscleEllipse(ctx, x: 70, y: 29, w: 17, h: 15, muscle: "shoulders")

        // Triceps
        muscleEllipse(ctx, x: 10, y: 47, w: 13, h: 28, muscle: "triceps")
        muscleEllipse(ctx, x: 77, y: 47, w: 13, h: 28, muscle: "triceps")

        // Forearms (back)
        muscleEllipse(ctx, x: 11, y: 84, w: 11, h: 22, muscle: "forearms")
        muscleEllipse(ctx, x: 78, y: 84, w: 11, h: 22, muscle: "forearms")

        // Glutes
        muscleEllipse(ctx, x: 22, y: 104, w: 26, h: 20, muscle: "glutes")
        muscleEllipse(ctx, x: 52, y: 104, w: 26, h: 20, muscle: "glutes")

        // Hamstrings
        muscleEllipse(ctx, x: 23, y: 118, w: 22, h: 48, muscle: "hamstrings")
        muscleEllipse(ctx, x: 55, y: 118, w: 22, h: 48, muscle: "hamstrings")

        // Calves (back)
        muscleEllipse(ctx, x: 24, y: 180, w: 17, h: 34, muscle: "calves")
        muscleEllipse(ctx, x: 59, y: 180, w: 17, h: 34, muscle: "calves")
    }

    // MARK: Torso path (same shape as front — symmetric silhouette)

    private func torsoPath() -> Path {
        var p = Path()
        p.move(to: sp(55, 30))
        p.addQuadCurve(to: sp(73, 40), control: sp(70, 30))
        p.addQuadCurve(to: sp(73, 58), control: sp(78, 50))
        p.addQuadCurve(to: sp(68, 88), control: sp(73, 72))
        p.addQuadCurve(to: sp(72, 106), control: sp(68, 98))
        p.addLine(to: sp(28, 106))
        p.addQuadCurve(to: sp(32, 88), control: sp(32, 98))
        p.addQuadCurve(to: sp(27, 58), control: sp(27, 72))
        p.addQuadCurve(to: sp(27, 40), control: sp(22, 50))
        p.addQuadCurve(to: sp(45, 30), control: sp(30, 30))
        p.closeSubpath()
        return p
    }

    // MARK: Helpers

    private func sc(_ v: CGFloat) -> CGFloat { v * scale }
    private func sp(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * scale, y: y * scale) }

    private func bodyEllipse(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        let path = Path(ellipseIn: CGRect(x: sc(x), y: sc(y), width: sc(w), height: sc(h)))
        ctx.fill(path, with: .color(kBodyFill))
        ctx.stroke(path, with: .color(kBodyStroke), lineWidth: 0.8)
    }

    private func muscleEllipse(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, muscle: String) {
        let sets = muscleVolume[muscle] ?? 0
        guard sets > 0 else { return }
        let color = (RQColors.muscleGroupColors[muscle] ?? RQColors.accent).opacity(muscleOpacity(sets))
        ctx.fill(Path(ellipseIn: CGRect(x: sc(x), y: sc(y), width: sc(w), height: sc(h))), with: .color(color))
    }
}

// MARK: - Shared Constants

private let kBodyFill = Color(hex: "1C1C2E")
private let kBodyStroke = Color(hex: "3C3C5C")

/// Intensity from set count: 0.30 at 1 set → 0.85 at 5+ sets
private func muscleOpacity(_ sets: Int) -> Double {
    min(0.30 + Double(sets - 1) * 0.14, 0.85)
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
