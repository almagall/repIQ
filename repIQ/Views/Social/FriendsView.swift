import SwiftUI
import Supabase

/// Friends management: friend list, pending requests, and search.
struct FriendsView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var searchText = ""
    @State private var searchResults: [SocialProfile] = []
    @State private var isSearching = false
    @State private var selectedTab: FriendsTab = .friends
    @State private var gymMembers: [SocialProfile] = []
    @State private var isLoadingGymMembers = false

    enum FriendsTab: String, CaseIterable {
        case friends = "Friends"
        case requests = "Requests"
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

    // MARK: - Search

    private var searchSection: some View {
        VStack(spacing: RQSpacing.lg) {
            // Gym discovery
            if let gymName = viewModel.socialProfile?.gymName,
               let gymPlaceId = viewModel.socialProfile?.gymPlaceId,
               !gymName.isEmpty {
                VStack(alignment: .leading, spacing: RQSpacing.md) {
                    HStack {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 14))
                            .foregroundColor(RQColors.accent)

                        Text("At Your Gym")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)

                        Spacer()

                        Text(gymName)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                            .lineLimit(1)
                    }

                    if isLoadingGymMembers {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                                .scaleEffect(0.7)
                            Text("Finding members...")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }
                    } else if gymMembers.isEmpty {
                        HStack(spacing: RQSpacing.sm) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 14))
                                .foregroundColor(RQColors.textTertiary)
                            Text("No other members yet")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }
                        .padding(.vertical, RQSpacing.sm)
                    } else {
                        Text("\(gymMembers.count) member\(gymMembers.count == 1 ? "" : "s")")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.accent)

                        ForEach(gymMembers) { member in
                            HStack(spacing: RQSpacing.md) {
                                profileAvatar(name: member.username ?? member.displayName ?? "?", size: 36)

                                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                                    Text(member.username ?? member.displayName ?? "User")
                                        .font(RQTypography.body)
                                        .foregroundColor(RQColors.textPrimary)

                                    if let username = member.username, !username.isEmpty,
                                       let display = member.displayName, !display.isEmpty,
                                       username != display {
                                        Text(display)
                                            .font(RQTypography.caption)
                                            .foregroundColor(RQColors.textTertiary)
                                    }
                                }

                                Spacer()

                                let isFriend = viewModel.friendIds.contains(member.id)
                                let isSent = viewModel.sentRequestIds.contains(member.id)

                                if isFriend {
                                    Text("Friends")
                                        .font(RQTypography.caption)
                                        .foregroundColor(RQColors.success)
                                } else if isSent {
                                    Text("Sent")
                                        .font(RQTypography.caption)
                                        .foregroundColor(RQColors.textTertiary)
                                } else {
                                    Button {
                                        Task { await viewModel.sendFriendRequest(to: member.id) }
                                    } label: {
                                        Text("Add")
                                            .font(RQTypography.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(RQColors.background)
                                            .padding(.horizontal, RQSpacing.md)
                                            .padding(.vertical, 5)
                                            .background(RQColors.accent)
                                            .cornerRadius(RQRadius.large)
                                    }
                                }
                            }
                            .padding(.vertical, RQSpacing.xxs)
                        }
                    }
                }
                .padding(RQSpacing.cardPadding)
                .background(RQColors.surfacePrimary)
                .cornerRadius(RQRadius.medium)
                .task {
                    await loadGymMembers(placeId: gymPlaceId)
                }
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

    // MARK: - Gym Members

    private func loadGymMembers(placeId: String) async {
        isLoadingGymMembers = true
        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            gymMembers = try await GymService().fetchGymMembers(placeId: placeId, excludeUserId: userId)
        } catch {}
        isLoadingGymMembers = false
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
