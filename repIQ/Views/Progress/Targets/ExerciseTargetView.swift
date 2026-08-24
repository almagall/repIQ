import SwiftUI
import Supabase

/// The exercise drill-in: one lift, on one workout day, against what it was
/// told to do.
///
/// Replaces a chart-first view that led with an e1RM trend line — a metric the
/// engine itself refuses to use for hypertrophy, since it's unreliable in the
/// 10–15 rep band and meaningless for bodyweight work. This leads with the same
/// question the overview asks, then shows the set-level evidence behind it.
struct ExerciseTargetView: View {
    let exerciseId: UUID
    let workoutDayId: UUID?

    @State private var detail: ExerciseTargetDetail?
    @State private var isLoading = true

    private let service = TargetAdherenceService()

    var body: some View {
        ScrollView {
            Group {
                if let detail {
                    loaded(detail)
                } else if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                        .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    EmptyStateView(
                        icon: "scope",
                        title: "No Targets Yet",
                        message: "Log this lift a few more times and repIQ will start prescribing — and tracking how often you hit it."
                    )
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.top, RQSpacing.lg)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .background(RQColors.background)
        .navigationTitle(detail?.exerciseName ?? "Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
    }

    private func load() async {
        defer { isLoading = false }
        guard let userId = try? await supabase.auth.session.user.id else { return }
        detail = try? await service.fetchExerciseDetail(
            userId: userId,
            exerciseId: exerciseId,
            workoutDayId: workoutDayId
        )
    }

    // MARK: - Loaded

    private func loaded(_ detail: ExerciseTargetDetail) -> some View {
        VStack(spacing: RQSpacing.xl) {
            hero(detail)
            if let next = detail.next {
                prescription(next, detail: detail)
            }
            if detail.chartPoints.count >= 2 {
                gapChart(detail)
            }
            if !detail.setPositions.isEmpty {
                setGrid(detail)
            }
            if let diagnosis = detail.diagnosis {
                diagnosisCard(diagnosis, detail: detail)
            }
            ledger(detail)
        }
    }

    // MARK: - Hero

    private func hero(_ detail: ExerciseTargetDetail) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.lg) {
            HStack {
                modeChip(detail.trainingMode)
                if let dayName = detail.dayName {
                    Text(dayName)
                        .rqSheetLabel()
                        .foregroundColor(RQColors.textTertiary)
                }
                Spacer()
            }

            HStack(alignment: .lastTextBaseline, spacing: RQSpacing.md) {
                Text("\(detail.ratio.adherencePercent)")
                    .rqFigure(RQTypography.figureXL)
                    .foregroundColor(RQColors.textPrimary)
                Text("%")
                    .rqFigure(RQTypography.figureM)
                    .foregroundColor(RQColors.textTertiary)
                // Always beside the percentage: a rate with no fraction can't be
                // checked, and "12 of 19" is what makes it legible.
                Text("\(detail.setsHit) of \(detail.setsGraded)\n\(countedLabel(detail.trainingMode))")
                    .font(RQTypography.sheetCaption)
                    .foregroundColor(RQColors.textSecondary)
                    .padding(.bottom, RQSpacing.xs)
                Spacer(minLength: 0)
            }

            SessionCapsuleRow(sessions: detail.sessions)
        }
        .padding(RQSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rqSheet(fill: RQColors.surfaceSecondary, elevated: true)
    }

    /// Names what the percentage counted. The two modes count different things,
    /// so leaving it implicit would make two rows with the same number mean
    /// different things with nothing on screen to say so.
    private func countedLabel(_ mode: TrainingMode) -> String {
        mode == .strength ? "top sets" : "working sets"
    }

    private func modeChip(_ mode: TrainingMode) -> some View {
        let color = mode == .strength ? RQColors.strength : RQColors.hypertrophy
        return Text(mode == .strength ? "Strength" : "Hypertrophy")
            .font(RQTypography.sheetLabel)
            .tracking(RQTypography.sheetLabelTracking)
            .textCase(.uppercase)
            .foregroundColor(color)
            .padding(.horizontal, RQSpacing.md)
            .padding(.vertical, RQSpacing.xs + 1)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: RQRadius.control - 2, style: .continuous))
    }

    // MARK: - Next prescription

    private func prescription(_ next: NextPrescription, detail: ExerciseTargetDetail) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            HStack {
                Text("Next session")
                    .rqSheetLabel()
                    .foregroundColor(RQColors.textTertiary)
                Spacer()
                Text(next.goingUp ? "Going up" : "Same target")
                    .font(RQTypography.sheetLabel)
                    .tracking(RQTypography.sheetLabelTracking)
                    .textCase(.uppercase)
                    .foregroundColor(next.goingUp ? RQColors.stateAdvancing : RQColors.textSecondary)
            }

            Text(prescriptionText(next, detail: detail))
                .rqFigure(RQTypography.figureL)
                .foregroundColor(RQColors.textPrimary)

            Text(decisionExplanation(next))
                .font(RQTypography.sheetBody)
                .foregroundColor(RQColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RQSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rqSheet()
    }

    private func prescriptionText(_ next: NextPrescription, detail: ExerciseTargetDetail) -> String {
        let reps = "× \(next.reps)"
        guard next.weight > 0 else { return "\(next.reps) reps" }
        let weight = next.weight.formatted(.number.precision(.fractionLength(0...1)))
        return next.trainingMode == .strength
            ? "Top set \(weight) \(reps)"
            : "\(weight) \(reps)"
    }

    private func decisionExplanation(_ next: NextPrescription) -> String {
        switch next.decision {
        case .increaseWeight:
            return "You earned more load — the engine moved the weight up."
        case .increaseReps:
            return "Same weight, one more rep to chase before it climbs again."
        case .maintain:
            return next.trainingMode == .strength
                ? "Holding here until the top set lands cleanly."
                : "Holding this weight until every set hits its rep goal."
        case .deload, .deloadVolume:
            return "Eased back on purpose. A lighter week is part of the plan, not a setback."
        case nil:
            return "Prescription carried over from your last session."
        }
    }

    // MARK: - Prescribed vs achieved

    /// The gap between what was asked and what was lifted. Drawn rather than
    /// asserted — where the two lines separate *is* the plateau.
    private func gapChart(_ detail: ExerciseTargetDetail) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.lg) {
            HStack {
                Text("Prescribed vs achieved")
                    .rqSheetLabel()
                    .foregroundColor(RQColors.textTertiary)
                Spacer()
                Text(detail.trainingMode == .strength ? "Top set weight" : "Reps per set")
                    .font(RQTypography.sheetCaption)
                    .foregroundColor(RQColors.textTertiary)
            }

            GapChart(points: detail.chartPoints)
                .frame(height: 132)

            HStack(spacing: RQSpacing.xl) {
                legendKey(color: RQColors.textTertiary, label: "Goal", dashed: true)
                legendKey(color: RQColors.accent, label: "You", dashed: false)
                Spacer()
            }
        }
        .padding(RQSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rqSheet()
    }

    private func legendKey(color: Color, label: String, dashed: Bool) -> some View {
        HStack(spacing: RQSpacing.sm) {
            Rectangle()
                .fill(color)
                .frame(width: 14, height: 2)
                .opacity(dashed ? 0.6 : 1)
            Text(label)
                .font(RQTypography.sheetCaption)
                .foregroundColor(RQColors.textSecondary)
        }
    }

    // MARK: - Set grid

    private func setGrid(_ detail: ExerciseTargetDetail) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.lg) {
            Text("Where you miss")
                .rqSheetLabel()
                .foregroundColor(RQColors.textTertiary)

            VStack(spacing: RQSpacing.sm) {
                ForEach(detail.setPositions) { position in
                    HStack(spacing: RQSpacing.md) {
                        Text("Set \(position.position)")
                            .font(RQTypography.sheetCaption)
                            .foregroundColor(RQColors.textTertiary)
                            .frame(width: 42, alignment: .leading)

                        HStack(spacing: 4) {
                            ForEach(Array(position.outcomes.enumerated()), id: \.offset) { _, outcome in
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(cellColor(outcome))
                                    .frame(height: 20)
                            }
                        }

                        Text(position.attempted > 0 ? "\(position.ratio.adherencePercent)%" : "—")
                            .font(.system(size: 11, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(position.ratio < 0.5 && position.attempted > 0
                                             ? RQColors.textSecondary : RQColors.textPrimary)
                            .frame(width: 38, alignment: .trailing)
                    }
                }
            }

            Text("Oldest to most recent, left to right.")
                .font(RQTypography.sheetCaption)
                .foregroundColor(RQColors.textTertiary)
        }
        .padding(RQSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rqSheet()
    }

    private func cellColor(_ outcome: Bool?) -> Color {
        switch outcome {
        case .some(true): return RQColors.stateAdvancing
        case .some(false): return RQColors.surfaceTertiary
        case nil: return RQColors.surfaceTertiary.opacity(0.35)
        }
    }

    // MARK: - Diagnosis

    private func diagnosisCard(
        _ diagnosis: ExerciseTargetDetail.Diagnosis,
        detail: ExerciseTargetDetail
    ) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            Text(diagnosisTitle(diagnosis))
                .font(RQTypography.sheetTitle)
                .foregroundColor(RQColors.textPrimary)
            Text(diagnosisBody(diagnosis, detail: detail))
                .font(RQTypography.sheetBody)
                .foregroundColor(RQColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RQSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rqSheet(fill: RQColors.surfaceSecondary, elevated: true)
    }

    private func diagnosisTitle(_ diagnosis: ExerciseTargetDetail.Diagnosis) -> String {
        switch diagnosis {
        case .tooHeavy: return "The weight is ahead of you"
        case .tooMuchVolume: return "It's not the weight"
        case .targetTooSoft: return "The target is behind you"
        case .topSetMissed: return "The top set isn't landing"
        }
    }

    private func diagnosisBody(
        _ diagnosis: ExerciseTargetDetail.Diagnosis,
        detail: ExerciseTargetDetail
    ) -> String {
        switch diagnosis {
        case .tooHeavy:
            return "You're missing from the very first set, while you're still fresh. That's a load problem, not fatigue — the engine will hold the weight until it lands."
        case let .tooMuchVolume(firstFailing):
            return "The early sets land and set \(firstFailing) doesn't. That's session fatigue, so the load is right and the volume isn't. Try dropping a set for two weeks, then adding it back."
        case .targetTooSoft:
            return "You're hitting essentially everything asked of you. That usually means there's more in the tank than the prescription is claiming."
        case .topSetMissed:
            return detail.trainingMode == .strength
                ? "The ramp is doing its job but the top set isn't finishing. The engine holds here until it does."
                : "The heaviest set isn't finishing."
        }
    }

    // MARK: - Ledger

    private func ledger(_ detail: ExerciseTargetDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Session by session")
                .rqSheetLabel()
                .foregroundColor(RQColors.textTertiary)
                .padding(RQSpacing.cardPadding)

            ForEach(detail.sessions.reversed()) { session in
                Rectangle().fill(RQColors.hairline).frame(height: 1)
                sessionRow(session)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rqSheet()
    }

    private func sessionRow(_ session: ExerciseSessionDetail) -> some View {
        HStack(alignment: .top, spacing: RQSpacing.lg) {
            Text(session.date.formatted(.dateTime.month(.abbreviated).day()))
                .font(RQTypography.sheetCaption)
                .foregroundColor(RQColors.textTertiary)
                .frame(width: 48, alignment: .leading)

            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                Text(setsSummary(session))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(RQColors.textPrimary)
                Text("goal \(session.prescribedWeight.formatted(.number.precision(.fractionLength(0...1)))) × \(session.prescribedReps)")
                    .font(RQTypography.sheetCaption)
                    .foregroundColor(RQColors.textTertiary)
            }

            Spacer(minLength: 0)

            Text("\(session.setsHit)/\(session.setsGraded)")
                .font(.system(size: 11, weight: .bold))
                .monospacedDigit()
                .foregroundColor(session.isComplete ? RQColors.stateAdvancing : RQColors.textSecondary)
        }
        .padding(RQSpacing.cardPadding)
    }

    /// "205 × 5 / 5 / 4" — the weight once, then the reps per set, which is how
    /// a lifter reads their own log.
    private func setsSummary(_ session: ExerciseSessionDetail) -> String {
        let graded = session.graded
        guard !graded.isEmpty else { return "—" }
        let weights = Set(graded.map(\.weight))
        let reps = graded.map { String($0.reps) }.joined(separator: " / ")

        if weights.count == 1, let weight = weights.first {
            return "\(weight.formatted(.number.precision(.fractionLength(0...1)))) × \(reps)"
        }
        return graded
            .map { "\($0.weight.formatted(.number.precision(.fractionLength(0...1))))×\($0.reps)" }
            .joined(separator: "  ")
    }
}

// MARK: - Session capsules

private struct SessionCapsuleRow: View {
    let sessions: [ExerciseSessionDetail]

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(sessions) { session in
                ZStack(alignment: .bottom) {
                    Capsule().fill(RQColors.surfaceTertiary)
                    Capsule()
                        .fill(session.isComplete ? RQColors.stateAdvancing : RQColors.accent)
                        .frame(height: 26 * session.ratio)
                }
                .frame(height: 26)
            }
        }
    }
}

// MARK: - Gap chart

/// Prescribed as a dashed line, achieved as a solid one, with the shortfall
/// shaded. Where the two separate *is* the plateau — drawn rather than asserted.
private struct GapChart: View {
    let points: [ExerciseTargetDetail.ChartPoint]

    var body: some View {
        GeometryReader { geo in
            let plotted = layout(in: geo.size)
            ZStack {
                if plotted.count >= 2 {
                    // Shade only where the lifter fell short. Filling between
                    // the two paths unconditionally draws a solid block wherever
                    // they cross, which is how the first version produced a
                    // trapezoid out of a flat series.
                    ForEach(Array(shortfalls(plotted).enumerated()), id: \.offset) { _, band in
                        Path { path in
                            guard let first = band.first else { return }
                            path.move(to: first.goal)
                            band.forEach { path.addLine(to: $0.goal) }
                            band.reversed().forEach { path.addLine(to: $0.actual) }
                            path.closeSubpath()
                        }
                        .fill(RQColors.stateBacking.opacity(0.16))
                    }

                    line(plotted.map(\.goal))
                        .stroke(
                            RQColors.textTertiary,
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [5, 4])
                        )

                    line(plotted.map(\.actual))
                        .stroke(
                            RQColors.accent,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )

                    if let last = plotted.last {
                        Circle()
                            .fill(RQColors.accent)
                            .frame(width: 8, height: 8)
                            .position(last.actual)
                    }
                }
            }
        }
    }

    private struct Plotted {
        let goal: CGPoint
        let actual: CGPoint
        let missed: Bool
    }

    /// Contiguous runs where achieved sat below prescribed. Adjacent points are
    /// included on both ends so the band meets the lines cleanly.
    private func shortfalls(_ plotted: [Plotted]) -> [[Plotted]] {
        var bands: [[Plotted]] = []
        var current: [Plotted] = []
        for point in plotted {
            if point.missed {
                current.append(point)
            } else {
                if !current.isEmpty { current.append(point) }
                if current.count > 1 { bands.append(current) }
                current = point.missed ? [point] : []
            }
        }
        if current.count > 1 { bands.append(current) }
        return bands
    }

    private func line(_ values: [CGPoint]) -> Path {
        var path = Path()
        guard let first = values.first else { return path }
        path.move(to: first)
        values.dropFirst().forEach { path.addLine(to: $0) }
        return path
    }

    private func layout(in size: CGSize) -> [Plotted] {
        guard points.count > 1 else { return [] }
        let values = points.flatMap { [$0.goal, $0.actual] }
        guard let low = values.min(), let high = values.max() else { return [] }
        // A flat series would divide by zero; padding keeps it mid-frame rather
        // than pinned to an edge.
        let span = max(high - low, 1)
        let stepX = size.width / CGFloat(points.count - 1)
        let inset = size.height * 0.12

        func y(_ value: Double) -> CGFloat {
            let ratio = (value - low) / span
            return size.height - inset - CGFloat(ratio) * (size.height - inset * 2)
        }

        return points.enumerated().map { index, point in
            let x = CGFloat(index) * stepX
            return Plotted(
                goal: CGPoint(x: x, y: y(point.goal)),
                actual: CGPoint(x: x, y: y(point.actual)),
                missed: point.actual < point.goal
            )
        }
    }
}
