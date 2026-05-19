import SwiftUI

/// Clubs landing screen: lists clubs the user belongs to and a browse-public
/// section for discovery. Pushes into `ClubDetailView` and presents
/// `CreateClubView` as a sheet for new clubs.
struct ClubsListView: View {
    @Bindable var viewModel: SocialViewModel

    @State private var publicClubs: [Club] = []
    @State private var isLoading = false
    @State private var showCreate = false

    private let service = ChallengeService()

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xl) {
                myClubsSection
                publicClubsSection
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.lg)
        }
        .background(RQColors.background)
        .navigationTitle("Clubs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(RQColors.accent)
                }
            }
        }
        .task { await loadPublicClubs() }
        .refreshable {
            await viewModel.loadSocialData()
            await loadPublicClubs()
        }
        .sheet(isPresented: $showCreate) {
            CreateClubView(viewModel: viewModel) {
                Task {
                    await viewModel.loadSocialData()
                    await loadPublicClubs()
                }
            }
        }
    }

    // MARK: - My Clubs

    @ViewBuilder
    private var myClubsSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.sm) {
            Text("MY CLUBS")
                .font(RQTypography.label)
                .tracking(1.5)
                .foregroundColor(RQColors.textSecondary)

            if viewModel.userClubs.isEmpty {
                emptyState(
                    icon: "person.3",
                    title: "No clubs yet",
                    message: "Clubs are 3–10 person training groups working on the same goal. Create one or join a public club below."
                )
            } else {
                ForEach(viewModel.userClubs) { club in
                    NavigationLink(value: ClubDestination.detail(club)) {
                        clubCard(club, isMember: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Public Clubs

    @ViewBuilder
    private var publicClubsSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.sm) {
            HStack {
                Text("DISCOVER")
                    .font(RQTypography.label)
                    .tracking(1.5)
                    .foregroundColor(RQColors.textSecondary)
                Spacer()
                if isLoading {
                    ProgressView()
                        .tint(RQColors.accent)
                        .scaleEffect(0.7)
                }
            }

            if filteredPublicClubs.isEmpty && !isLoading {
                emptyState(
                    icon: "magnifyingglass",
                    title: "No public clubs",
                    message: "Be the first to start one for your gym or program."
                )
            } else {
                ForEach(filteredPublicClubs) { club in
                    NavigationLink(value: ClubDestination.detail(club)) {
                        clubCard(club, isMember: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationDestination(for: ClubDestination.self) { destination in
            switch destination {
            case .detail(let club):
                ClubDetailView(viewModel: viewModel, club: club) {
                    Task {
                        await viewModel.loadSocialData()
                        await loadPublicClubs()
                    }
                }
            }
        }
    }

    private var filteredPublicClubs: [Club] {
        // Hide clubs the user is already in to keep the discovery list
        // honest.
        let mineIds = Set(viewModel.userClubs.map(\.id))
        return publicClubs.filter { !mineIds.contains($0.id) }
    }

    // MARK: - Components

    private func clubCard(_ club: Club, isMember: Bool) -> some View {
        RQCard {
            HStack(spacing: RQSpacing.md) {
                Image(systemName: club.isPublic ? "person.3.fill" : "lock.fill")
                    .font(.system(size: 18))
                    .foregroundColor(RQColors.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(club.name)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)

                    if let desc = club.description, !desc.isEmpty {
                        Text(desc)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                            .lineLimit(1)
                    }

                    HStack(spacing: RQSpacing.sm) {
                        Label("\(club.memberCount)", systemImage: "person.2.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(RQColors.textTertiary)
                        if isMember {
                            Text("MEMBER")
                                .font(.system(size: 9, weight: .heavy))
                                .tracking(1)
                                .foregroundColor(RQColors.success)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(RQColors.textTertiary)
            }
        }
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: RQSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(RQColors.textTertiary)
            Text(title)
                .font(RQTypography.headline)
                .foregroundColor(RQColors.textSecondary)
            Text(message)
                .font(RQTypography.footnote)
                .foregroundColor(RQColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, RQSpacing.xl)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Loading

    private func loadPublicClubs() async {
        isLoading = true
        defer { isLoading = false }
        do {
            publicClubs = try await service.fetchPublicClubs(limit: 30)
        } catch {
            publicClubs = []
        }
    }
}

/// Push destinations for the clubs subtree. Scoped here (not in the global
/// `SocialDestination`) because Club itself isn't `Hashable` and we don't
/// want to widen the global enum for a leaf push.
enum ClubDestination: Hashable {
    case detail(Club)

    static func == (lhs: ClubDestination, rhs: ClubDestination) -> Bool {
        switch (lhs, rhs) {
        case (.detail(let a), .detail(let b)): return a.id == b.id
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .detail(let club): hasher.combine(club.id)
        }
    }
}
