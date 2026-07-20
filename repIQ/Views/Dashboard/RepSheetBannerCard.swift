import SwiftUI

/// Dashboard banner that appears on the 1st–14th of a new month when the
/// prior month's Rep Sheet is ready and unviewed. Tapping deep-links into the
/// Spotify-style story flow.
struct RepSheetBannerCard: View {
    let wrapped: RepSheet
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                LinearGradient(
                    colors: [
                        RQColors.accent.opacity(0.18),
                        RQColors.accent.opacity(0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                HStack(spacing: RQSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(RQColors.accent.opacity(0.25))
                            .frame(width: 48, height: 48)
                        Image(systemName: "sparkles")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(RQColors.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("YOUR \(monthLabel(wrapped.monthStart).uppercased()) REP SHEET")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(RQColors.accent)
                        Text("Ready to view")
                            .font(RQTypography.headline)
                            .foregroundColor(RQColors.textPrimary)
                        Text("\(wrapped.totalSessions) workouts · \(wrapped.totalPRs) PRs · tap to open")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(RQColors.accent)
                }
                .padding(RQSpacing.lg)
            }
            .clipShape(RoundedRectangle(cornerRadius: RQRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RQRadius.large, style: .continuous)
                    .stroke(RQColors.accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: date)
    }
}
