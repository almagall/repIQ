import SwiftUI

struct GoalCelebrationView: View {
    let goal: Goal
    let onDismiss: () -> Void

    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    @State private var animateIn = false

    var body: some View {
        ZStack {
            RQColors.background.ignoresSafeArea()

            VStack(spacing: RQSpacing.xl) {
                Spacer()

                // Trophy burst
                VStack(spacing: RQSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(RQColors.accent.opacity(0.12))
                            .frame(width: 120, height: 120)
                            .scaleEffect(animateIn ? 1.0 : 0.4)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: animateIn)

                        Circle()
                            .fill(RQColors.accent.opacity(0.06))
                            .frame(width: 160, height: 160)
                            .scaleEffect(animateIn ? 1.0 : 0.2)
                            .animation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.05), value: animateIn)

                        Image(systemName: "trophy.fill")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundColor(RQColors.accent)
                            .scaleEffect(animateIn ? 1.0 : 0.1)
                            .animation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.1), value: animateIn)
                    }

                    VStack(spacing: RQSpacing.xs) {
                        Text("Goal Achieved")
                            .font(RQTypography.title1)
                            .foregroundColor(RQColors.textPrimary)
                            .opacity(animateIn ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.25), value: animateIn)

                        if let exerciseName = goal.exerciseName {
                            Text(exerciseName)
                                .font(RQTypography.headline)
                                .foregroundColor(RQColors.accent)
                                .opacity(animateIn ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.3), value: animateIn)
                        }
                    }
                }

                // Stats card
                RQCard {
                    VStack(spacing: RQSpacing.md) {
                        statRow(label: "Goal Type", value: goal.goalTypeBadge)
                        Divider().background(RQColors.surfaceTertiary)
                        statRow(label: "Target", value: goal.displayTarget)
                        Divider().background(RQColors.surfaceTertiary)
                        statRow(label: "Achieved", value: goal.displayCurrent)
                        if goal.startingValue > 0 {
                            Divider().background(RQColors.surfaceTertiary)
                            let gain = goal.currentValue - goal.startingValue
                            statRow(
                                label: "Total Gain",
                                value: "+\(formatValue(gain)) \(goal.unit)",
                                valueColor: RQColors.success
                            )
                        }
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)
                .animation(.easeOut(duration: 0.45).delay(0.35), value: animateIn)

                Spacer()

                // Share card preview
                GoalShareCard(goal: goal)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: RQColors.accent.opacity(0.15), radius: 16, y: 6)
                    .padding(.horizontal, RQSpacing.screenHorizontal)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 30)
                    .animation(.easeOut(duration: 0.45).delay(0.45), value: animateIn)

                // Buttons
                VStack(spacing: RQSpacing.md) {
                    Button {
                        generateShareImage()
                    } label: {
                        HStack(spacing: RQSpacing.sm) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15))
                            Text("Share Achievement")
                                .font(RQTypography.headline)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RQSpacing.md)
                        .background(RQColors.accent)
                        .cornerRadius(RQRadius.medium)
                    }

                    Button {
                        onDismiss()
                    } label: {
                        Text("Continue")
                            .font(RQTypography.body)
                            .foregroundColor(RQColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, RQSpacing.md)
                            .background(RQColors.surfaceSecondary)
                            .cornerRadius(RQRadius.medium)
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.55), value: animateIn)
            }
            .padding(.bottom, RQSpacing.xl)
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
        .onAppear {
            animateIn = true
        }
    }

    // MARK: - Helpers

    private func statRow(label: String, value: String, valueColor: Color = RQColors.textPrimary) -> some View {
        HStack {
            Text(label)
                .font(RQTypography.caption)
                .foregroundColor(RQColors.textTertiary)
            Spacer()
            Text(value)
                .font(RQTypography.body)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
        }
    }

    private func formatValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    private func generateShareImage() {
        let card = GoalShareCard(goal: goal)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
    }
}

// MARK: - Goal Share Card

struct GoalShareCard: View {
    let goal: Goal

    private let cardWidth: CGFloat = 360
    private let cardHeight: CGFloat = 480

    var body: some View {
        ZStack {
            // Background
            RQColors.background

            // Subtle grid lines
            Canvas { context, size in
                for x in stride(from: 0, through: size.width, by: 24) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(RQColors.accent.opacity(0.04)), lineWidth: 0.5)
                }
                for y in stride(from: 0, through: size.height, by: 24) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(RQColors.accent.opacity(0.04)), lineWidth: 0.5)
                }
            }

            // Top accent bar
            VStack(spacing: 0) {
                Rectangle()
                    .fill(RQColors.accent)
                    .frame(height: 3)
                Spacer()
            }

            // Content
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("repIQ")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .tracking(2)
                            .foregroundColor(RQColors.accent)

                        Text("Goal Achieved")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(RQColors.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "trophy.fill")
                        .font(.system(size: 22))
                        .foregroundColor(RQColors.accent)
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)

                Spacer()

                // Main stat
                VStack(alignment: .leading, spacing: 8) {
                    if let exerciseName = goal.exerciseName {
                        Text(exerciseName.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(2)
                            .foregroundColor(RQColors.textTertiary)
                    }

                    Text(goal.displayCurrent)
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundColor(RQColors.textPrimary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        Text(goal.goalTypeBadge)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(RQColors.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(RQColors.accent.opacity(0.15))
                            .cornerRadius(4)

                        if goal.startingValue > 0 {
                            let gain = goal.currentValue - goal.startingValue
                            Text("+\(formatValue(gain)) \(goal.unit) gained")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(RQColors.success)
                        }
                    }
                }
                .padding(.horizontal, 28)

                Spacer()

                // Progress bar (full, since goal is complete)
                VStack(spacing: 8) {
                    HStack {
                        if goal.startingValue > 0 {
                            Text("\(formatValue(goal.startingValue)) \(goal.unit)")
                                .font(.system(size: 11))
                                .foregroundColor(RQColors.textTertiary)
                        }
                        Spacer()
                        Text("Target: \(goal.displayTarget)")
                            .font(.system(size: 11))
                            .foregroundColor(RQColors.textTertiary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(RQColors.surfaceTertiary)
                                .frame(height: 6)
                            Capsule()
                                .fill(RQColors.accent)
                                .frame(width: geo.size.width, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, 28)

                Spacer()

                // Footer
                HStack {
                    Text(Date(), style: .date)
                        .font(.system(size: 11))
                        .foregroundColor(RQColors.textTertiary)

                    Spacer()

                    Text("repiq.app")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(RQColors.accent.opacity(0.6))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
    }

    private func formatValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
