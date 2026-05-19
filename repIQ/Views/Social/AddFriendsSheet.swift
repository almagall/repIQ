import SwiftUI

/// Quick sheet for searching users and managing friend requests.
struct AddFriendsSheet: View {
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var searchResults: [SocialProfile] = []
    @State private var isSearching = false
    @State private var suggestions: [MatchmakingResult] = []
    @State private var isLoadingSuggestions = false

    private let matchmakingService = MatchmakingService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RQSpacing.lg) {
                    searchSection

                    // When the user hasn't typed a query, show match
                    // suggestions and an invite button so the sheet isn't a
                    // dead-end on first open.
                    if searchText.isEmpty {
                        suggestionsSection
                        inviteCard
                    }
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
            .task { await loadSuggestions() }
        }
    }

    // MARK: - Suggestions

    @ViewBuilder
    private var suggestionsSection: some View {
        if isLoadingSuggestions {
            HStack {
                ProgressView().tint(RQColors.accent)
                Text("Finding people who train like you…")
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, RQSpacing.lg)
        } else if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(RQColors.accent)
                    Text("SUGGESTED FOR YOU")
                        .font(RQTypography.label)
                        .tracking(1.5)
                        .foregroundColor(RQColors.textSecondary)
                }
                .padding(.horizontal, RQSpacing.xs)

                ForEach(suggestions) { result in
                    suggestionRow(result)
                }
            }
        }
    }

    private func suggestionRow(_ result: MatchmakingResult) -> some View {
        let user = result.profile
        let isFriend = viewModel.friendIds.contains(user.id)
        let isSent = viewModel.sentRequestIds.contains(user.id)
        let name = user.username ?? "User"

        return HStack(spacing: RQSpacing.md) {
            profileAvatar(name: name, size: 44)

            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                Text(name)
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)
                if let reason = result.reasons.first {
                    Text(reason)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isFriend {
                statusPill(text: "Friends", color: RQColors.success)
            } else if isSent {
                statusPill(text: "Sent", color: RQColors.textSecondary)
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

    private func statusPill(text: String, color: Color) -> some View {
        Text(text)
            .font(RQTypography.caption)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, RQSpacing.md)
            .padding(.vertical, RQSpacing.sm)
            .background(color.opacity(0.15))
            .cornerRadius(RQRadius.large)
    }

    // MARK: - Invite

    private var inviteCard: some View {
        Button {
            presentInvite()
        } label: {
            HStack(spacing: RQSpacing.md) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
                    .foregroundColor(RQColors.accent)

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text("Invite friends to repIQ")
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)
                    Text("Share a link with your gym crew")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(RQColors.textTertiary)
            }
            .padding(RQSpacing.cardPadding)
            .background(RQColors.surfacePrimary)
            .cornerRadius(RQRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: RQRadius.medium)
                    .stroke(RQColors.accent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func presentInvite() {
        let username = viewModel.socialProfile?.username ?? ""
        let signature = username.isEmpty ? "" : " — @\(username)"
        let text = "Train smarter with me on repIQ\(signature). Logging workouts, tracking PRs, and seeing real progress." +
            "\n\nhttps://apps.apple.com/app/repiq"
        guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController else { return }
        var presenter = root
        while let presented = presenter.presentedViewController { presenter = presented }
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let popover = vc.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX,
                                        y: presenter.view.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(vc, animated: true)
    }

    private func loadSuggestions() async {
        guard let userId = viewModel.currentUserId else { return }
        isLoadingSuggestions = true
        defer { isLoadingSuggestions = false }
        do {
            let existing = Array(viewModel.friendIds) + [userId]
            suggestions = try await matchmakingService.findMatches(
                userId: userId,
                existingFriendIds: existing,
                limit: 6
            )
        } catch {
            suggestions = []
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
        let name = user.username ?? "User"

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
