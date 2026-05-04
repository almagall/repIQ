import SwiftUI

/// Entry point for the monthly wrapped flow. Generates (idempotently) the
/// prior month's wrapped on appear, then hands off to `WrappedStoryView` for
/// the Spotify-style story presentation. Past months are accessible via a
/// sheet from the archetype (closing) slide.
struct MonthlyWrappedView: View {
    @Bindable var viewModel: SocialViewModel

    @State private var wrapped: MonthlyWrapped?
    @State private var pastWrapped: [MonthlyWrapped] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showHistorySheet = false
    @State private var shareImage: UIImage?
    @State private var showWrappedShareSheet = false

    private let service = DigestService()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(RQColors.accent)
            } else if let wrapped {
                WrappedStoryView(
                    wrapped: wrapped,
                    onShare: { share(wrapped: wrapped) },
                    onViewHistory: { showHistorySheet = true }
                )
                // Force a fresh story view (slide index reset) when the user
                // switches between months from the history sheet.
                .id(wrapped.id)
            } else {
                emptyOrErrorState
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .task { await load() }
        .sheet(isPresented: $showHistorySheet) {
            WrappedHistorySheet(
                pastWrapped: pastWrapped,
                onSelect: { selected in
                    showHistorySheet = false
                    wrapped = selected
                }
            )
        }
        .sheet(isPresented: $showWrappedShareSheet) {
            if let img = shareImage {
                WrappedShareSheet(items: [img])
            }
        }
    }

    @ViewBuilder
    private var emptyOrErrorState: some View {
        VStack(spacing: RQSpacing.lg) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))
            if let errorMessage {
                Text("Couldn't load your Wrapped")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text(errorMessage)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, RQSpacing.xl)
                Button("Try again") {
                    Task { await load() }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RQColors.accent)
            } else {
                Text("No Wrapped yet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Train this month and your Wrapped will be ready on the 1st of next month.")
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, RQSpacing.xl)
            }
        }
    }

    // MARK: - Loading

    private func load() async {
        guard let userId = viewModel.currentUserId else {
            errorMessage = "Not signed in."
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let current = try await service.generateMonthlyWrapped(userId: userId)
            let history = try await service.fetchWrappedHistory(userId: userId)
            wrapped = current
            pastWrapped = history.filter { $0.id != current.id }
            // Mark as viewed so the dashboard banner + tab dot badge clear.
            if current.viewedAt == nil {
                Task { try? await service.markWrappedViewed(wrappedId: current.id) }
            }
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        isLoading = false
    }

    // MARK: - Sharing

    @MainActor
    private func share(wrapped: MonthlyWrapped) {
        let card = WrappedShareCard(wrapped: wrapped)
        let renderer = ImageRenderer(content: card)
        // Render at the active scene's display scale so the PNG is crisp
        // across devices. Fall back to 3 (iPhone Pro / Plus) if no scene found.
        let scale = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.scale }
            .first ?? 3.0
        renderer.scale = scale
        renderer.proposedSize = .init(width: 1080, height: 1920) // 9:16
        if let image = renderer.uiImage {
            shareImage = image
            showWrappedShareSheet = true
        }
    }
}

// MARK: - History sheet

private struct WrappedHistorySheet: View {
    let pastWrapped: [MonthlyWrapped]
    var onSelect: (MonthlyWrapped) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RQSpacing.md) {
                    if pastWrapped.isEmpty {
                        Text("No past months yet.")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                            .padding(.top, RQSpacing.xxl)
                    } else {
                        ForEach(pastWrapped) { past in
                            Button { onSelect(past) } label: {
                                RQCard {
                                    HStack(spacing: RQSpacing.md) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(monthLabel(past.monthStart))
                                                .font(RQTypography.headline)
                                                .foregroundColor(RQColors.textPrimary)
                                            HStack(spacing: RQSpacing.md) {
                                                Label("\(past.totalSessions)", systemImage: "figure.strengthtraining.traditional")
                                                Label("\(past.totalPRs)", systemImage: "trophy.fill")
                                            }
                                            .font(RQTypography.caption)
                                            .foregroundColor(RQColors.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(RQColors.textTertiary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.top, RQSpacing.lg)
            }
            .background(RQColors.background)
            .navigationTitle("Past Months")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }

    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}

// MARK: - Share card (rendered to a 9:16 PNG)

private struct WrappedShareCard: View {
    let wrapped: MonthlyWrapped

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text(monthLabel(wrapped.monthStart).uppercased())
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(RQColors.accent)
                Text("YOUR WRAPPED")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white)
            }

            Spacer().frame(height: 24)

            HStack(spacing: 24) {
                shareStat(label: "WORKOUTS", value: "\(wrapped.totalSessions)")
                shareStat(label: "PRs", value: "\(wrapped.totalPRs)")
            }
            HStack(spacing: 24) {
                shareStat(label: "TOTAL VOLUME", value: formatVolume(wrapped.totalVolume))
                shareStat(label: "WORKING SETS", value: "\(wrapped.totalSets)")
            }

            Spacer().frame(height: 24)

            if let archetype = WrappedArchetype(rawValue: wrapped.archetype ?? "") {
                VStack(spacing: 12) {
                    Image(systemName: archetype.systemImageName)
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(RQColors.accent)
                    Text("YOU ARE A")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.55))
                    Text(archetype.displayName.uppercased())
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            Spacer()

            Text("repIQ")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 32)
        }
        .frame(width: 1080, height: 1920)
        .background(
            LinearGradient(
                colors: [Color.black, Color(red: 0.04, green: 0.07, blue: 0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func shareStat(label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(2.5)
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 220)
    }

    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    private func formatVolume(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.0fK", value / 1_000) }
        return String(format: "%.0f", value)
    }
}

// MARK: - UIKit share sheet bridge

private struct WrappedShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
