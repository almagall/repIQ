import SwiftUI

/// Friends management: friend list, pending requests, search, and training partners.
struct FriendsView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var searchText = ""
    @State private var searchResults: [SocialProfile] = []
    @State private var isSearching = false
    @State private var selectedTab: FriendsTab = .friends

    enum FriendsTab: String, CaseIterable {
        case friends = "Friends"
        case requests = "Requests"
        case partners = "Partners"
        case search = "Find"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sub-tab picker
            friendsTabPicker

            // Content
            ScrollView {
                VStack(spacing: RQSpacing.lg) {
                    switch selectedTab {
                    case .friends:
                        friendsList
                    case .requests:
                        requestsList
                    case .partners:
                        partnersList
                    case .search:
                        searchSection
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.vertical, RQSpacing.lg)
            }
        }
    }

    // MARK: - Tab Picker

    private var friendsTabPicker: some View {
        HStack(spacing: RQSpacing.sm) {
            ForEach(FriendsTab.allCases, id: \.rawValue) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: RQSpacing.xs) {
                        Text(tab.rawValue)
                            .font(RQTypography.caption)
                            .fontWeight(.semibold)

                        if tab == .requests && !viewModel.pendingRequests.isEmpty {
                            Text("\(viewModel.pendingRequests.count)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(RQColors.background)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(RQColors.error)
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundColor(selectedTab == tab ? RQColors.background : RQColors.textSecondary)
                    .padding(.horizontal, RQSpacing.md)
                    .padding(.vertical, RQSpacing.sm)
                    .background(selectedTab == tab ? RQColors.accent : RQColors.surfaceTertiary)
                    .cornerRadius(RQRadius.large)
                }
            }
            Spacer()
        }
        .padding(.horizontal, RQSpacing.screenHorizontal)
        .padding(.vertical, RQSpacing.sm)
    }

    // MARK: - Friends List

    @ViewBuilder
    private var friendsList: some View {
        if viewModel.friends.isEmpty {
            emptyState(icon: "person.2", title: "No friends yet", message: "Search for users to add friends and see their workouts.")
        } else {
            ForEach(viewModel.friends) { friendship in
                friendRow(friendship)
            }
        }
    }

    private func friendRow(_ friendship: Friendship) -> some View {
        let name = friendDisplayName(friendship)

        return HStack(spacing: RQSpacing.md) {
            // Avatar
            profileAvatar(name: name, size: 44)

            // Info
            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                Text(name)
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)

                if let username = friendship.friendProfile?.username, !username.isEmpty {
                    Text("@\(username)")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }

                if friendship.safeIsTrainingPartner {
                    HStack(spacing: RQSpacing.xxs) {
                        Image(systemName: "figure.2.and.child.holdinghands")
                            .font(.system(size: 10))
                        Text("Training Partner")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                    }
                    .foregroundColor(RQColors.accent)
                }
            }

            Spacer()

            // Actions
            Menu {
                Button {
                    Task { await viewModel.toggleTrainingPartner(friendship) }
                } label: {
                    Label(
                        friendship.safeIsTrainingPartner ? "Remove Partner" : "Make Partner",
                        systemImage: friendship.safeIsTrainingPartner ? "person.badge.minus" : "person.badge.plus"
                    )
                }

                Button(role: .destructive) {
                    Task { await viewModel.removeFriend(friendship) }
                } label: {
                    Label("Remove Friend", systemImage: "person.badge.minus")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(RQColors.textTertiary)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(RQSpacing.cardPadding)
        .background(RQColors.surfacePrimary)
        .cornerRadius(RQRadius.medium)
    }

    // MARK: - Requests List

    @ViewBuilder
    private var requestsList: some View {
        if viewModel.pendingRequests.isEmpty {
            emptyState(icon: "envelope", title: "No pending requests", message: "Friend requests you receive will appear here.")
        } else {
            ForEach(viewModel.pendingRequests) { request in
                requestRow(request)
            }
        }
    }

    private func requestRow(_ request: Friendship) -> some View {
        let name = friendDisplayName(request)

        return HStack(spacing: RQSpacing.md) {
            profileAvatar(name: name, size: 44)

            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                Text(name)
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)
                if let username = request.friendProfile?.username, !username.isEmpty {
                    Text("@\(username)")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                } else {
                    Text("Wants to be friends")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }
            }

            Spacer()

            HStack(spacing: RQSpacing.sm) {
                Button {
                    Task { await viewModel.acceptRequest(request) }
                } label: {
                    Text("Accept")
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(RQColors.background)
                        .padding(.horizontal, RQSpacing.md)
                        .padding(.vertical, RQSpacing.sm)
                        .background(RQColors.accent)
                        .cornerRadius(RQRadius.large)
                }

                Button {
                    Task { await viewModel.declineRequest(request) }
                } label: {
                    Text("Decline")
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(RQColors.textSecondary)
                        .padding(.horizontal, RQSpacing.md)
                        .padding(.vertical, RQSpacing.sm)
                        .background(RQColors.surfaceTertiary)
                        .cornerRadius(RQRadius.large)
                }
            }
        }
        .padding(RQSpacing.cardPadding)
        .background(RQColors.surfacePrimary)
        .cornerRadius(RQRadius.medium)
    }

    // MARK: - Partners List

    @ViewBuilder
    private var partnersList: some View {
        if viewModel.trainingPartners.isEmpty {
            emptyState(
                icon: "figure.2.and.child.holdinghands",
                title: "No training partners",
                message: "Designate up to 5 close friends as training partners for accountability and partner streaks."
            )
        } else {
            ForEach(viewModel.trainingPartners) { partner in
                HStack(spacing: RQSpacing.md) {
                    profileAvatar(name: friendDisplayName(partner), size: 44)

                    VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                        Text(friendDisplayName(partner))
                            .font(RQTypography.headline)
                            .foregroundColor(RQColors.textPrimary)

                        if partner.safePartnerStreak > 0 {
                            HStack(spacing: RQSpacing.xxs) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(RQColors.warning)
                                Text("\(partner.safePartnerStreak) day partner streak")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.warning)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "figure.2.and.child.holdinghands")
                        .font(.system(size: 16))
                        .foregroundColor(RQColors.accent)
                }
                .padding(RQSpacing.cardPadding)
                .background(RQColors.surfacePrimary)
                .cornerRadius(RQRadius.medium)
            }
        }
    }

    // MARK: - Search

    private var searchSection: some View {
        VStack(spacing: RQSpacing.lg) {
            // Smart matchmaking banner
            NavigationLink {
                MatchmakingView(viewModel: viewModel)
            } label: {
                HStack(spacing: RQSpacing.md) {
                    Image(systemName: "person.2.wave.2.fill")
                        .font(.system(size: 20))
                        .foregroundColor(RQColors.accent)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                        Text("Find Training Partners")
                            .font(RQTypography.headline)
                            .foregroundColor(RQColors.textPrimary)
                        Text("Smart matchmaking based on your training style")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(RQColors.textTertiary)
                }
                .padding(RQSpacing.cardPadding)
                .background(RQColors.accent.opacity(0.08))
                .cornerRadius(RQRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: RQRadius.medium)
                        .stroke(RQColors.accent.opacity(0.2), lineWidth: 1)
                )
            }

            // Search bar
            HStack(spacing: RQSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(RQColors.textTertiary)

                TextField("Search by username or name", text: $searchText)
                    .font(RQTypography.body)
                    .foregroundColor(RQColors.textPrimary)
                    .autocapitalization(.none)
                    .onSubmit {
                        Task { await performSearch() }
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(RQColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, RQSpacing.md)
            .padding(.vertical, RQSpacing.md)
            .background(RQColors.surfaceTertiary)
            .cornerRadius(RQRadius.medium)

            // Results
            if isSearching {
                ProgressView()
                    .tint(RQColors.accent)
                    .padding(.top, RQSpacing.xl)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                Text("No users found")
                    .font(RQTypography.footnote)
                    .foregroundColor(RQColors.textTertiary)
                    .padding(.top, RQSpacing.xl)
            } else {
                ForEach(searchResults) { user in
                    searchResultRow(user)
                }
            }
        }
    }

    private func searchResultRow(_ user: SocialProfile) -> some View {
        let isFriend = viewModel.friendIds.contains(user.id)
        let name = user.displayName?.isEmpty == false ? user.displayName! : user.username ?? "User"

        return HStack(spacing: RQSpacing.md) {
            profileAvatar(name: name, size: 44)

            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                Text(name)
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)
                if let username = user.username {
                    Text("@\(username)")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }
            }

            Spacer()

            if isFriend {
                Text("Friends")
                    .font(RQTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(RQColors.success)
                    .padding(.horizontal, RQSpacing.md)
                    .padding(.vertical, RQSpacing.sm)
                    .background(RQColors.success.opacity(0.15))
                    .cornerRadius(RQRadius.large)
            } else if viewModel.sentRequestIds.contains(user.id) {
                HStack(spacing: RQSpacing.xxs) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("Sent")
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(RQColors.textSecondary)
                .padding(.horizontal, RQSpacing.md)
                .padding(.vertical, RQSpacing.sm)
                .background(RQColors.surfaceTertiary)
                .cornerRadius(RQRadius.large)
            } else {
                Button {
                    Task { await viewModel.sendFriendRequest(to: user.id) }
                } label: {
                    Text("Add")
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(RQColors.background)
                        .padding(.horizontal, RQSpacing.md)
                        .padding(.vertical, RQSpacing.sm)
                        .background(RQColors.accent)
                        .cornerRadius(RQRadius.large)
                }
            }
        }
        .padding(RQSpacing.cardPadding)
        .background(RQColors.surfacePrimary)
        .cornerRadius(RQRadius.medium)
    }

    // MARK: - Helpers

    private func performSearch() async {
        guard !searchText.isEmpty else { return }
        isSearching = true
        searchResults = await viewModel.searchUsers(query: searchText)
        isSearching = false
    }

    private func profileAvatar(name: String, size: CGFloat) -> some View {
        Circle()
            .fill(RQColors.accent.opacity(0.2))
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundColor(RQColors.accent)
            )
    }

    private func friendDisplayName(_ friendship: Friendship) -> String {
        if let display = friendship.friendProfile?.displayName, !display.isEmpty {
            return display
        }
        if let username = friendship.friendProfile?.username, !username.isEmpty {
            return username
        }
        return "User"
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: RQSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(RQColors.textTertiary)
            Text(title)
                .font(RQTypography.headline)
                .foregroundColor(RQColors.textSecondary)
            Text(message)
                .font(RQTypography.footnote)
                .foregroundColor(RQColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, RQSpacing.xxxl)
    }
}
