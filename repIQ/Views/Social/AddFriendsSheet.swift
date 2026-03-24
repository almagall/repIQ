import SwiftUI

/// Quick sheet for searching users and managing friend requests.
struct AddFriendsSheet: View {
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var searchResults: [SocialProfile] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RQSpacing.lg) {
                    searchSection
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.vertical, RQSpacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(RQColors.background)
            .navigationTitle("Find Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(RQColors.accent)
                }
            }
        }
    }

    // MARK: - Search

    private var searchSection: some View {
        VStack(spacing: RQSpacing.lg) {
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
                emptyState(
                    icon: "magnifyingglass",
                    title: "No users found",
                    message: "Try searching by username or display name."
                )
            } else if searchResults.isEmpty {
                emptyState(
                    icon: "person.2.badge.gearshape",
                    title: "Find Friends",
                    message: "Search by username or name to find and add friends."
                )
            } else {
                ForEach(searchResults) { user in
                    searchResultRow(user)
                }
            }
        }
    }

    // MARK: - Requests

    @ViewBuilder
    private var requestsSection: some View {
        if viewModel.pendingRequests.isEmpty {
            emptyState(
                icon: "envelope",
                title: "No pending requests",
                message: "Friend requests you receive will appear here."
            )
        } else {
            ForEach(viewModel.pendingRequests) { request in
                requestRow(request)
            }
        }
    }

    // MARK: - Rows

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

    private func requestRow(_ request: Friendship) -> some View {
        let name = requestDisplayName(request)

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

    // MARK: - Helpers

    private func performSearch() async {
        guard !searchText.isEmpty else { return }
        isSearching = true
        searchResults = await viewModel.searchUsers(query: searchText)
        isSearching = false
    }

    private func requestDisplayName(_ request: Friendship) -> String {
        if let display = request.friendProfile?.displayName, !display.isEmpty {
            return display
        }
        if let username = request.friendProfile?.username, !username.isEmpty {
            return username
        }
        return "User"
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
