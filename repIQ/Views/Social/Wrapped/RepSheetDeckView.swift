import SwiftUI

/// The Rep Sheet deck: an industrial spec-card deck the user flips through to
/// review the prior month. Tap the right two-thirds to advance, the left third
/// to go back, or drag the top card; the stack visibly depletes forward and
/// restacks back. The ✕ (and swipe-down) exits at any point. Cards are the
/// pre-selected, pre-ordered set in `RepSheet.content.order`; a single accent
/// (`RQColors.accent`) runs through every card for a consistent scheme.
struct RepSheetDeckView: View {
    let wrapped: RepSheet
    var onClose: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var onViewHistory: (() -> Void)? = nil
    var onViewReport: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var drag: CGFloat = 0

    private var content: RepSheetContent {
        wrapped.content ?? .fallback(from: wrapped)
    }
    private var order: [RepSheetCardID] {
        content.order.isEmpty ? [.cover, .nextMonth] : content.order
    }

    var body: some View {
        ZStack(alignment: .top) {
            RQColors.background.ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    ForEach(order.indices, id: \.self) { i in
                        card(for: order[i])
                            .modifier(DeckPosition(offset: i - index, drag: i == index ? drag : 0))
                            .zIndex(Double(order.count - abs(i - index)))
                            .animation(.easeInOut(duration: 0.3), value: index)
                    }

                    HStack(spacing: 0) {
                        Color.clear
                            .frame(width: geo.size.width * 0.34)
                            .contentShape(Rectangle())
                            .onTapGesture { step(-1) }
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture { step(1) }
                    }
                    // Above the cards so taps on the card body advance/rewind;
                    // disabled on the last card so its buttons receive taps.
                    .zIndex(1000)
                    .allowsHitTesting(index < order.count - 1)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .gesture(
                    DragGesture()
                        .onChanged { drag = $0.translation.width }
                        .onEnded { end($0) }
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 54)
            .padding(.bottom, 28)

            topBar
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    // MARK: - Top bar (progress dots + close)

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(order.indices, id: \.self) { i in
                    Capsule()
                        .fill(i <= index ? RQColors.textPrimary : RQColors.surfaceTertiary)
                        .frame(height: 3)
                        .animation(.easeOut(duration: 0.25), value: index)
                }
            }
            .padding(.horizontal, RQSpacing.md)
            .padding(.top, RQSpacing.sm)

            HStack {
                Spacer()
                Button {
                    (onClose ?? { dismiss() })()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(RQColors.textSecondary)
                        .padding(8)
                        .background(RQColors.surfaceTertiary, in: Circle())
                }
                .padding(.trailing, RQSpacing.md)
            }
            .padding(.top, RQSpacing.xs)
        }
    }

    // MARK: - Navigation

    private func step(_ delta: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            index = min(max(index + delta, 0), order.count - 1)
        }
    }

    private func end(_ value: DragGesture.Value) {
        let t = value.translation.width
        withAnimation(.easeInOut(duration: 0.3)) {
            if t < -50 { index = min(index + 1, order.count - 1) }
            else if t > 50 { index = max(index - 1, 0) }
            drag = 0
        }
    }

    // MARK: - Card dispatcher

    @ViewBuilder
    private func card(for id: RepSheetCardID) -> some View {
        let idx = order.firstIndex(of: id) ?? 0
        let total = order.count
        switch id {
        case .cover:
            if let c = content.cover { CoverCard(card: c, index: idx, total: total, monthStart: wrapped.monthStart) }
        case .strengthGained:
            if let c = content.strengthGained { StrengthGainedCard(card: c, index: idx, total: total) }
        case .biggestMover:
            if let c = content.biggestMover { BiggestMoverCard(card: c, index: idx, total: total) }
        case .breakthrough:
            if let c = content.breakthrough { BreakthroughCard(card: c, index: idx, total: total) }
        case .prWall:
            if let c = content.prWall { PRWallCard(card: c, index: idx, total: total) }
        case .allTimeRank:
            if let c = content.allTimeRank { AllTimeRankCard(card: c, index: idx, total: total) }
        case .consistency:
            if let c = content.consistency { ConsistencyCard(card: c, index: idx, total: total) }
        case .relativeStrength:
            if let c = content.relativeStrength { RelativeStrengthCard(card: c, index: idx, total: total) }
        case .muscleBalance:
            if let c = content.muscleBalance { MuscleBalanceCard(card: c, index: idx, total: total) }
        case .monthOverMonth:
            if let c = content.monthOverMonth { MonthOverMonthCard(card: c, index: idx, total: total) }
        case .whenYouTrain:
            if let c = content.whenYouTrain { WhenYouTrainCard(card: c, index: idx, total: total) }
        case .style:
            if let c = content.style { StyleCard(card: c, index: idx, total: total) }
        case .nextMonth:
            if let c = content.nextMonth {
                NextMonthCard(card: c, index: idx, total: total,
                              onViewReport: { onViewReport?() },
                              onShare: { onShare?() },
                              onViewHistory: { onViewHistory?() })
            }
        }
    }
}

// MARK: - Deck positioning

private struct DeckPosition: ViewModifier {
    let offset: Int
    let drag: CGFloat

    func body(content: Content) -> some View {
        let behind = min(max(offset, 0), 6)
        return content
            .scaleEffect(offset == 0 ? 1 : max(0.8, 1 - CGFloat(behind) * 0.03))
            .rotationEffect(.degrees(offset == 0 ? Double(drag) * 0.02 : 0))
            .offset(x: offset == 0 ? drag : 0,
                    y: offset < 0 ? -1000 : CGFloat(behind) * 10)
            .opacity(offset < 0 ? 0 : (offset > 6 ? 0 : (offset >= 4 ? 0.5 : 1)))
            .allowsHitTesting(offset == 0)
    }
}

// MARK: - Card chrome

private struct DeckCard<Hero: View, Footer: View>: View {
    let chip: String
    let index: Int
    let total: Int
    let icon: String
    @ViewBuilder var hero: () -> Hero
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(RQColors.surfacePrimary)

            Image(systemName: icon)
                .font(.system(size: 150, weight: .semibold))
                .foregroundStyle(RQColors.accent.opacity(0.06))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 44, y: 34)

            CornerBrackets()

            VStack(spacing: 0) {
                HStack {
                    Text(chip)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(RQColors.background)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(RQColors.accent, in: RoundedRectangle(cornerRadius: 4))
                    Spacer()
                    Text(String(format: "%02d / %02d", index + 1, total))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(RQColors.textTertiary)
                }
                .padding(.horizontal, 15).padding(.top, 13).padding(.bottom, 11)

                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                    .padding(.horizontal, 14)

                VStack(spacing: 10) { hero() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 18)

                footer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct CornerBrackets: View {
    var body: some View {
        ZStack {
            bracket(.tl).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            bracket(.tr).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            bracket(.bl).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            bracket(.br).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .padding(9)
    }

    private func bracket(_ corner: BracketShape.Corner) -> some View {
        BracketShape(corner: corner)
            .stroke(RQColors.accent.opacity(0.55), lineWidth: 1.5)
            .frame(width: 13, height: 13)
    }
}

private struct BracketShape: Shape {
    enum Corner { case tl, tr, bl, br }
    let corner: Corner
    func path(in rect: CGRect) -> Path {
        let s = rect.width
        var p = Path()
        switch corner {
        case .tl:
            p.move(to: CGPoint(x: 0, y: s)); p.addLine(to: .zero); p.addLine(to: CGPoint(x: s, y: 0))
        case .tr:
            p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: s, y: 0)); p.addLine(to: CGPoint(x: s, y: s))
        case .bl:
            p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 0, y: s)); p.addLine(to: CGPoint(x: s, y: s))
        case .br:
            p.move(to: CGPoint(x: 0, y: s)); p.addLine(to: CGPoint(x: s, y: s)); p.addLine(to: CGPoint(x: s, y: 0))
        }
        return p
    }
}

// MARK: - Shared card pieces

private struct StatStrip: View {
    let items: [(String, String)]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                if i > 0 {
                    Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1)
                }
                VStack(spacing: 3) {
                    Text(item.0)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(RQColors.textTertiary)
                    Text(item.1)
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundStyle(RQColors.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10).padding(.horizontal, 4)
            }
        }
        .overlay(Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1), alignment: .top)
    }
}

private struct KeyValueRow: View {
    let key: String
    let value: String
    var body: some View {
        HStack {
            Text(key)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(RQColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(RQColors.accent)
        }
        .frame(width: 190)
    }
}

private struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(2)
            .foregroundStyle(RQColors.textSecondary)
    }
}

// MARK: - Mini charts

private struct BarsChart: View {
    let values: [Double]
    var body: some View {
        GeometryReader { geo in
            let maxV = max(values.max() ?? 1, 1)
            let n = max(values.count, 1)
            let gap: CGFloat = 6
            let w = (geo.size.width - gap * CGFloat(n - 1)) / CGFloat(n)
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(values.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i == values.count - 1 ? RQColors.accent : RQColors.surfaceTertiary)
                        .frame(width: w, height: max(4, geo.size.height * CGFloat(values[i] / maxV)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: 182, height: 56)
    }
}

private struct GaugeBar: View {
    /// 0…1 fill fraction.
    let fraction: Double
    var body: some View {
        GeometryReader { geo in
            let f = CGFloat(min(max(fraction, 0), 1))
            ZStack(alignment: .leading) {
                Capsule().fill(RQColors.surfaceTertiary).frame(height: 6)
                Capsule().fill(RQColors.accent).frame(width: geo.size.width * f, height: 6)
                Rectangle().fill(RQColors.textPrimary)
                    .frame(width: 2, height: 18)
                    .offset(x: geo.size.width * f - 1)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(width: 182, height: 22)
    }
}

private struct StepChart: View {
    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 34)); p.addLine(to: CGPoint(x: 106, y: 34))
            }
            .stroke(RQColors.textTertiary, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
            Path { p in
                p.move(to: CGPoint(x: 106, y: 34)); p.addLine(to: CGPoint(x: 130, y: 10))
                p.addLine(to: CGPoint(x: 178, y: 10))
            }
            .stroke(RQColors.accent, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
            Circle().fill(RQColors.accent).frame(width: 7, height: 7).position(x: 178, y: 10)
        }
        .frame(width: 182, height: 46)
    }
}

private struct HeatmapGrid: View {
    let trained: Set<Int>
    let prDays: Set<Int>
    let daysInMonth: Int
    var body: some View {
        let cols = 7
        let rows = Int(ceil(Double(daysInMonth) / Double(cols)))
        VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 4) {
                    ForEach(0..<cols, id: \.self) { c in
                        cell(r * cols + c + 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(_ day: Int) -> some View {
        if day > daysInMonth {
            Color.clear.frame(width: 18, height: 18)
        } else if prDays.contains(day) {
            RoundedRectangle(cornerRadius: 3).fill(RQColors.accent)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(RQColors.textPrimary, lineWidth: 2))
                .frame(width: 18, height: 18)
        } else if trained.contains(day) {
            RoundedRectangle(cornerRadius: 3).fill(RQColors.accent).frame(width: 18, height: 18)
        } else {
            RoundedRectangle(cornerRadius: 3).fill(RQColors.surfaceTertiary).frame(width: 18, height: 18)
        }
    }
}

private struct PushPullBars: View {
    let pushFraction: Double
    let pullFraction: Double
    var body: some View {
        VStack(spacing: 9) {
            bar("PUSH", pushFraction, RQColors.accent)
            bar("PULL", pullFraction, RQColors.surfaceTertiary)
        }
        .frame(width: 186)
    }

    private func bar(_ label: String, _ fraction: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(RQColors.textSecondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(RQColors.surfaceSecondary)
                    RoundedRectangle(cornerRadius: 3).fill(color)
                        .frame(width: geo.size.width * CGFloat(min(max(fraction, 0), 1)))
                }
            }
            .frame(height: 10)
        }
    }
}

// MARK: - Cards

private struct CoverCard: View {
    let card: RepSheetContent.Cover
    let index: Int
    let total: Int
    let monthStart: Date
    var body: some View {
        DeckCard(chip: monthLabel(monthStart).uppercased(), index: index, total: total, icon: "dumbbell.fill") {
            Text("REP\nSHEET")
                .font(.system(size: 46, weight: .heavy, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(RQColors.textPrimary)
                .lineSpacing(-6)
            Rectangle().fill(RQColors.accent).frame(width: 40, height: 3)
            Text("tap to begin")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(RQColors.textTertiary)
        } footer: {
            StatStrip(items: [
                ("SESSIONS", "\(card.totalSessions)"),
                ("PRs", "\(card.totalPRs)"),
                ("VOLUME", fmtVol(card.totalVolume))
            ])
        }
    }
    private func monthLabel(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f.string(from: d)
    }
}

private struct StrengthGainedCard: View {
    let card: RepSheetContent.StrengthGained
    let index: Int
    let total: Int
    var body: some View {
        DeckCard(chip: "STRENGTH GAINED", index: index, total: total, icon: "chart.line.uptrend.xyaxis") {
            Text("+\(fmtWeight(card.totalGainLbs))")
                .font(.system(size: 50, weight: .heavy, design: .monospaced))
                .foregroundStyle(RQColors.accent)
            Text("lbs of e1RM added")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(RQColors.textPrimary)
            Text("across your \(card.liftCount) main lifts")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(RQColors.textSecondary)
            VStack(spacing: 6) {
                ForEach(card.topLifts.indices, id: \.self) { i in
                    KeyValueRow(key: card.topLifts[i].exerciseName, value: "+\(fmtWeight(card.topLifts[i].deltaLbs)) lb")
                }
            }
        } footer: {
            StatStrip(items: [
                ("LIFTS", "\(card.liftCount)"),
                ("ADDED", "+\(fmtWeight(card.totalGainLbs))"),
                ("TOP", card.topLifts.first.map { shortName($0.exerciseName) } ?? "—")
            ])
        }
    }
}

private struct BiggestMoverCard: View {
    let card: RepSheetContent.BiggestMover
    let index: Int
    let total: Int
    var body: some View {
        DeckCard(chip: "BIGGEST MOVER", index: index, total: total, icon: "flame.fill") {
            Text(card.exerciseName.uppercased())
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(RQColors.textPrimary)
            Text(fmtPct(card.percentGain))
                .font(.system(size: 46, weight: .heavy, design: .monospaced))
                .foregroundStyle(RQColors.accent)
            Text("\(fmtWeight(card.fromE1RM)) → \(fmtWeight(card.toE1RM)) e1RM")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(RQColors.textSecondary)
        } footer: {
            StatStrip(items: [
                ("FROM", fmtWeight(card.fromE1RM)),
                ("TO", fmtWeight(card.toE1RM)),
                ("GAIN", fmtPct(card.percentGain))
            ])
        }
    }
}

private struct BreakthroughCard: View {
    let card: RepSheetContent.Breakthrough
    let index: Int
    let total: Int
    var body: some View {
        DeckCard(chip: "THE BREAKTHROUGH", index: index, total: total, icon: "trophy.fill") {
            Text(card.reps > 0 ? "\(fmtWeight(card.weight)) × \(card.reps)" : fmtWeight(card.weight))
                .font(.system(size: 36, weight: .heavy, design: .monospaced))
                .foregroundStyle(RQColors.textPrimary)
            Text(card.exerciseName.uppercased())
                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundStyle(RQColors.accent)
            StepChart()
            Text(card.achievedAtDisplay + (card.priorBest == nil ? " · first time ever" : ""))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(RQColors.textSecondary)
        } footer: {
            StatStrip(items: [
                ("OLD BEST", card.priorBest.map { fmtWeight($0) } ?? "—"),
                ("NEW", fmtWeight(card.weight)),
                ("STUCK", card.stuckWeeks.map { "\($0) wk" } ?? "—")
            ])
        }
    }
}

private struct PRWallCard: View {
    let card: RepSheetContent.PRWall
    let index: Int
    let total: Int
    var body: some View {
        DeckCard(chip: "PR WALL", index: index, total: total, icon: "rosette") {
            Text("\(card.count)")
                .font(.system(size: 44, weight: .heavy, design: .monospaced))
                .foregroundStyle(RQColors.accent)
            Text("records broken")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(RQColors.textPrimary)
            VStack(spacing: 8) {
                ForEach(card.entries.indices, id: \.self) { i in
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 11)).foregroundStyle(RQColors.accent)
                            Text(card.entries[i].exerciseName)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(RQColors.textPrimary)
                        }
                        Spacer()
                        Text(prValue(card.entries[i]))
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundStyle(RQColors.textPrimary)
                    }
                    .frame(width: 196)
                }
            }
        } footer: {
            StatStrip(items: [
                ("WEIGHT", "\(card.weightPRs)"),
                ("REPS", "\(card.repPRs)"),
                ("TOTAL", "\(card.count)")
            ])
        }
    }

    private func prValue(_ e: RepSheetContent.PREntry) -> String {
        if e.recordType == "reps" { return "\(Int(e.value)) reps" }
        if let r = e.repsAtWeight, r > 1, e.recordType == "weight" { return "\(fmtWeight(e.value))×\(r)" }
        return fmtWeight(e.value)
    }
}

private struct AllTimeRankCard: View {
    let card: RepSheetContent.AllTimeRank
    let index: Int
    let total: Int
    var body: some View {
        DeckCard(chip: "ALL-TIME RANK", index: index, total: total, icon: "chart.bar.fill") {
            Text("#\(card.rank)")
                .font(.system(size: 56, weight: .heavy, design: .monospaced))
                .foregroundStyle(RQColors.accent)
            Text(card.rank == 1 ? "strongest month yet" : "of \(card.totalMonths) months tracked")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(RQColors.textPrimary)
            BarsChart(values: card.monthlyValues)
        } footer: {
            StatStrip(items: [
                ("THIS MO", fmtVol(card.thisValue)),
                ("PREV BEST", fmtVol(card.previousBest)),
                ("TRACKED", "\(card.totalMonths)")
            ])
        }
    }
}

private struct ConsistencyCard: View {
    let card: RepSheetContent.Consistency
    let index: Int
    let total: Int
    var body: some View {
        DeckCard(chip: "CONSISTENCY", index: index, total: total, icon: "calendar") {
            Text("\(card.trainedDays) DAYS ON")
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .foregroundStyle(RQColors.textPrimary)
            HeatmapGrid(trained: Set(card.trainedDayNumbers), prDays: Set(card.prDayNumbers), daysInMonth: card.daysInMonth)
            Text("filled = trained · outlined = PR day")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(RQColors.textTertiary)
        } footer: {
            StatStrip(items: [
                ("TRAINED", "\(card.trainedDays)"),
                ("REST", "\(card.restDays)"),
                ("BEST WK", "\(card.bestWeekSessions)")
            ])
        }
    }
}

private struct RelativeStrengthCard: View {
    let card: RepSheetContent.RelativeStrength
    let index: Int
    let total: Int
    var body: some View {
        DeckCard(chip: "RELATIVE STRENGTH", index: index, total: total, icon: "bolt.fill") {
            if let top = card.lifts.first {
                Text(fmtRatio(top.ratio))
                    .font(.system(size: 50, weight: .heavy, design: .monospaced))
                    .foregroundStyle(RQColors.accent)
                Text("bodyweight \(top.exerciseName.lowercased())")
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RQColors.textPrimary)
                Text("at \(fmtWeight(card.bodyweightLbs)) lb bodyweight")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(RQColors.textSecondary)
                VStack(spacing: 6) {
                    ForEach(Array(card.lifts.dropFirst().enumerated()), id: \.offset) { _, lift in
                        KeyValueRow(key: lift.exerciseName, value: fmtRatio(lift.ratio))
                    }
                }
            }
        } footer: {
            StatStrip(items: [
                ("BODYWT", fmtWeight(card.bodyweightLbs)),
                ("TOP", card.lifts.first.map { fmtRatio($0.ratio) } ?? "—"),
                ("LIFTS", "\(card.lifts.count)")
            ])
        }
    }
}

private struct MuscleBalanceCard: View {
    let card: RepSheetContent.MuscleBalance
    let index: Int
    let total: Int
    var body: some View {
        let hi = max(card.pushVolume, card.pullVolume, 1)
        return DeckCard(chip: "MUSCLE BALANCE", index: index, total: total, icon: "scalemass.fill") {
            Text("\(fmtRatio(card.ratio).replacingOccurrences(of: "×", with: "")) : 1")
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .foregroundStyle(RQColors.accent)
            Text(card.pushDominant ? "push to pull" : "pull to push")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(RQColors.textSecondary)
            PushPullBars(pushFraction: card.pushVolume / hi, pullFraction: card.pullVolume / hi)
        } footer: {
            StatStrip(items: [
                ("PUSH", fmtVol(card.pushVolume)),
                ("PULL", fmtVol(card.pullVolume)),
                ("GAP", fmtRatio(card.ratio))
            ])
        }
    }
}

private struct MonthOverMonthCard: View {
    let card: RepSheetContent.MonthOverMonth
    let index: Int
    let total: Int
    var body: some View {
        DeckCard(chip: "VS \(card.priorMonthLabel.uppercased())", index: index, total: total, icon: "arrow.left.arrow.right") {
            Text("MONTH OVER MONTH")
                .font(.system(size: 17, weight: .heavy, design: .monospaced))
                .foregroundStyle(RQColors.textPrimary)
            VStack(spacing: 11) {
                if let v = card.volumeDeltaPct { KeyValueRow(key: "Volume", value: fmtPct(v)) }
                KeyValueRow(key: "Sessions", value: fmtSigned(card.sessionsDelta))
                if let e = card.e1rmDeltaPct { KeyValueRow(key: "Avg e1RM", value: fmtPct(e)) }
            }
        } footer: {
            StatStrip(items: [
                (String(card.priorMonthLabel.prefix(3)).uppercased(), fmtVol(card.priorVolume)),
                ("NOW", fmtVol(card.thisVolume)),
                ("Δ", card.volumeDeltaPct.map { fmtPct($0) } ?? "—")
            ])
        }
    }
}

private struct WhenYouTrainCard: View {
    let card: RepSheetContent.WhenYouTrain
    let index: Int
    let total: Int
    var body: some View {
        DeckCard(chip: "WHEN YOU TRAIN", index: index, total: total, icon: "clock.fill") {
            Text(card.window.uppercased())
                .font(.system(size: 30, weight: .heavy, design: .monospaced))
                .foregroundStyle(RQColors.accent)
            Text("\(Int(card.windowPct.rounded()))% of your sessions")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(RQColors.textPrimary)
            Text("most often around \(hourLabel(card.mostCommonHour))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(RQColors.textSecondary)
        } footer: {
            StatStrip(items: [
                ("WINDOW", card.window.uppercased()),
                ("SHARE", "\(Int(card.windowPct.rounded()))%"),
                ("PEAK", hourLabel(card.mostCommonHour))
            ])
        }
    }
}

private struct StyleCard: View {
    let card: RepSheetContent.Style
    let index: Int
    let total: Int
    var body: some View {
        let arch = WrappedArchetype(rawValue: card.archetype) ?? .steadyBuilder
        return DeckCard(chip: "YOUR STYLE", index: index, total: total, icon: arch.systemImageName) {
            Text(arch.displayName.uppercased())
                .font(.system(size: 26, weight: .heavy, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(RQColors.textPrimary)
            if let rpe = card.avgRPE {
                Eyebrow(text: "AVG EFFORT · RPE \(String(format: "%.1f", rpe))")
                GaugeBar(fraction: rpe / 10.0)
            }
            Text(arch.headline)
                .font(.system(size: 11, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(RQColors.textSecondary)
        } footer: {
            StatStrip(items: [
                ("AVG RPE", card.avgRPE.map { String(format: "%.1f", $0) } ?? "—"),
                ("HARDEST", card.hardestRPE.map { String(format: "%.1f", $0) } ?? "—"),
                ("FAILURE", "\(card.failureSets)")
            ])
        }
    }
}

private struct NextMonthCard: View {
    let card: RepSheetContent.NextMonth
    let index: Int
    let total: Int
    var onViewReport: () -> Void
    var onShare: () -> Void
    var onViewHistory: () -> Void

    var body: some View {
        DeckCard(chip: "NEXT MONTH", index: index, total: total, icon: "target") {
            Text("YOUR NEXT MOVE")
                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                .foregroundStyle(RQColors.textPrimary)
            VStack(alignment: .leading, spacing: 11) {
                ForEach(card.tips.indices, id: \.self) { i in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(RQColors.accent)
                            .padding(.top, 1)
                        Text(card.tips[i])
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(RQColors.textPrimary.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(width: 210)
        } footer: {
            VStack(spacing: 8) {
                Button(action: onViewReport) {
                    Text("View full report")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(RQColors.background)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(RQColors.accent, in: Capsule())
                }
                Button(action: onShare) {
                    Text("Share my Rep Sheet")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(RQColors.textPrimary)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(RQColors.surfaceTertiary, in: Capsule())
                }
                Button(action: onViewHistory) {
                    Text("Past months")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(RQColors.textTertiary)
                }
            }
            .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 16)
        }
    }
}

// MARK: - Formatting helpers

private func fmtVol(_ v: Double) -> String {
    if v >= 1_000_000 { return String(format: "%.1fM", v / 1_000_000) }
    if v >= 1_000 { return String(format: "%.0fK", v / 1_000) }
    return String(format: "%.0f", v)
}

private func fmtWeight(_ v: Double) -> String {
    v.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", v) : String(format: "%.1f", v)
}

private func fmtPct(_ v: Double) -> String {
    (v >= 0 ? "+" : "") + String(format: "%.0f%%", v)
}

private func fmtRatio(_ v: Double) -> String { String(format: "%.1f×", v) }

private func fmtSigned(_ v: Int) -> String { (v >= 0 ? "+" : "") + "\(v)" }

private func shortName(_ name: String) -> String {
    name.split(separator: " ").first.map(String.init) ?? name
}

private func hourLabel(_ h: Int) -> String {
    let am = h < 12
    let hr = h % 12 == 0 ? 12 : h % 12
    return "\(hr)\(am ? "am" : "pm")"
}

// MARK: - Legacy fallback

extension RepSheetContent {
    /// Minimal deck for legacy `monthly_wrapped` rows generated before the Rep
    /// Sheet redesign (no `data` payload): cover + archetype + a generic tip.
    static func fallback(from w: RepSheet) -> RepSheetContent {
        var c = RepSheetContent(order: [])
        c.cover = .init(totalSessions: w.totalSessions, totalPRs: w.totalPRs, totalVolume: w.totalVolume)
        var order: [RepSheetCardID] = [.cover]
        if let a = w.archetype {
            c.style = .init(archetype: a, avgRPE: nil, hardestRPE: nil, failureSets: 0)
            order.append(.style)
        }
        c.nextMonth = .init(
            tips: ["Keep logging your sets — next month's Rep Sheet gets sharper with every session you record."],
            tone: "build"
        )
        order.append(.nextMonth)
        c.order = order
        return c
    }
}
