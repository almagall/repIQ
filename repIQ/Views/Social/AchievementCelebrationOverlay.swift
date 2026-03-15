import SwiftUI

/// Full-screen celebration overlay when an achievement tier is unlocked.
/// Shows confetti, the achievement icon, and tier name with spring animation.
struct AchievementCelebrationOverlay: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var confettiParticles: [ConfettiParticle] = []

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Content
            VStack(spacing: RQSpacing.lg) {
                Spacer()

                // Achievement icon
                ZStack {
                    // Glow ring
                    Circle()
                        .fill((achievement.currentTier?.color ?? RQColors.accent).opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(showContent ? 1.0 : 0.3)

                    Circle()
                        .fill(RQColors.surfacePrimary)
                        .frame(width: 88, height: 88)
                        .overlay(
                            Image(systemName: achievement.icon)
                                .font(.system(size: 36))
                                .foregroundColor(achievement.currentTier?.color ?? RQColors.accent)
                        )
                        .scaleEffect(showContent ? 1.0 : 0.1)
                }

                // Tier badge
                if let tier = achievement.currentTier {
                    HStack(spacing: RQSpacing.xs) {
                        Image(systemName: tier.icon)
                            .font(.system(size: 14))
                        Text(tier.displayName)
                            .font(RQTypography.label)
                            .fontWeight(.bold)
                            .tracking(1.5)
                    }
                    .foregroundColor(tier.color)
                    .opacity(showContent ? 1 : 0)
                }

                // Achievement name
                Text(achievement.name)
                    .font(RQTypography.title2)
                    .foregroundColor(RQColors.textPrimary)
                    .opacity(showContent ? 1 : 0)

                Text("Achievement Unlocked!")
                    .font(RQTypography.subheadline)
                    .foregroundColor(RQColors.textSecondary)
                    .opacity(showContent ? 1 : 0)

                Spacer()

                // Tap to dismiss hint
                Text("Tap to continue")
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
                    .opacity(showContent ? 0.6 : 0)
                    .padding(.bottom, RQSpacing.xl)
            }

            // Confetti
            Canvas { context, size in
                for particle in confettiParticles {
                    let rect = CGRect(
                        x: particle.x * size.width - 4,
                        y: particle.y * size.height - 4,
                        width: 8,
                        height: 8
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: particle.isCircle ? 4 : 1),
                        with: .color(particle.color)
                    )
                }
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
        .onAppear {
            generateConfetti()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showContent = true
            }
            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                dismiss()
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            showContent = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }

    private func generateConfetti() {
        let colors: [Color] = [
            RQColors.accent, RQColors.warning, RQColors.success,
            RQColors.hypertrophy, RQColors.info, .white
        ]

        confettiParticles = (0..<40).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...0.6),
                color: colors.randomElement() ?? .white,
                isCircle: Bool.random()
            )
        }

        // Animate particles falling
        withAnimation(.easeIn(duration: 2.0)) {
            for i in confettiParticles.indices {
                confettiParticles[i].y += CGFloat.random(in: 0.4...0.8)
            }
        }
    }
}

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let isCircle: Bool
}
