import SwiftUI

/// Head-to-head challenges and clubs management.
struct ChallengesView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var selectedTab: ChallengeTab = .active
    @State private var showCreateChallenge = false

    enum ChallengeTab: String, CaseIterable {
        case active = "Active"
        case clubs = "Clubs"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sub-tab picker
            HStack(spacing: RQSpacing.sm) {
                ForEach(ChallengeTab.allCases, id: \.rawValue) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(RQTypography.caption)
                            .fontWeight(.semibold)
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

            ScrollView {
                VStack(spacing: RQSpacing.lg) {
                    switch selectedTab {
                    case .active:
                        challengesList
                    case .clubs:
                        clubsList
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.vertical, RQSpacing.lg)
            }
        }
        .sheet(isPresented: $showCreateChallenge) {
            CreateChallengeView(viewModel: viewModel)
        }
    }

    // MARK: - Challenges List

    @ViewBuilder
    private var challengesList: some View {
        // Create challenge button
        Button {
            showCreateChallenge = true
        } label: {
            HStack(spacing: RQSpacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text("Create Challenge")
                    .font(RQTypography.headline)
            }
            .foregroundColor(RQColors.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, RQSpacing.md)
            .background(RQColors.accent.opacity(0.1))
            .cornerRadius(RQRadius.medium)
        }

        if viewModel.activeChallenges.isEmpty {
            emptyState(
                icon: "bolt.circle",
                title: "No active challenges",
                message: "Challenge a friend to a workout competition!"
            )
        } else {
            // Pending challenges (received)
            let pending = viewModel.activeChallenges.filter {
                $0.status == .pending && $0.challengedId == viewModel.currentUserId
            }
            if !pending.isEmpty {
                sectionHeader("INCOMING CHALLENGES")
                ForEach(pending) { challenge in
                    pendingChallengeCard(challenge)
                }
            }

            // Active challenges
            let active = viewModel.activeChallenges.filter { $0.status == .active }
            if !active.isEmpty {
                sectionHeader("ACTIVE")
                ForEach(active) { challenge in
                    activeChallengeCard(challenge)
                }
            }

            // Pending (sent)
            let sent = viewModel.activeChallenges.filter {
                $0.status == .pending && $0.challengerId == viewModel.currentUserId
            }
            if !sent.isEmpty {
                sectionHeader("SENT")
                ForEach(sent) { challenge in
                    sentChallengeCard(challenge)
                }
            }
        }
    }

    // MARK: - Challenge Cards

    private func pendingChallengeCard(_ challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            HStack(spacing: RQSpacing.sm) {
                Image(systemName: challenge.challengeType.icon)
                    .font(.system(size: 16))
                    .foregroundColor(RQColors.warning)

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(challenge.challengeType.displayName)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)
                    Text("from \(challenge.challengerProfile?.displayName ?? "Someone")")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }

                Spacer()

                Text("\(challenge.durationDays)d")
                    .font(RQTypography.numbersSmall)
                    .foregroundColor(RQColors.textSecondary)
            }

            HStack(spacing: RQSpacing.sm) {
                Button {
                    Task { await viewModel.acceptChallenge(challenge) }
                } label: {
                    Text("Accept")
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(RQColors.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RQSpacing.sm)
                        .background(RQColors.accent)
                        .cornerRadius(RQRadius.large)
                }

                Button {
                    Task { await viewModel.declineChallenge(challenge) }
                } label: {
                    Text("Decline")
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(RQColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RQSpacing.sm)
                        .background(RQColors.surfaceTertiary)
                        .cornerRadius(RQRadius.large)
                }
            }
        }
        .padding(RQSpacing.cardPadding)
        .background(RQColors.surfacePrimary)
        .cornerRadius(RQRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: RQRadius.medium)
                .stroke(RQColors.warning.opacity(0.3), lineWidth: 1)
        )
    }

    private func activeChallengeCard(_ challenge: Challenge) -> some View {
        let isChallenger = challenge.challengerId == viewModel.currentUserId
        let myScore = isChallenger ? challenge.challengerScore : challenge.challengedScore
        let theirScore = isChallenger ? challenge.challengedScore : challenge.challengerScore
        let opponentName = isChallenger
            ? (challenge.challengedProfile?.displayName ?? "Opponent")
            : (challenge.challengerProfile?.displayName ?? "Opponent")
        let winning = myScore > theirScore

        return VStack(alignment: .leading, spacing: RQSpacing.md) {
            HStack(spacing: RQSpacing.sm) {
                Image(systemName: challenge.challengeType.icon)
                    .font(.system(size: 16))
                    .foregroundColor(RQColors.accent)

                Text(challenge.challengeType.displayName)
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)

                Spacer()

                if let endDate = challenge.endDate {
                    let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
                    Text("\(max(0, daysLeft))d left")
                        .font(RQTypography.caption)
                        .foregroundColor(daysLeft <= 1 ? RQColors.warning : RQColors.textTertiary)
                }
            }

            // Score comparison
            HStack(spacing: RQSpacing.md) {
                // Your score
                VStack(spacing: RQSpacing.xxs) {
                    Text("You")
                        .font(RQTypography.label)
                        .foregroundColor(RQColors.textTertiary)
                        .textCase(.uppercase)
                    Text(String(format: "%.0f", myScore))
                        .font(RQTypography.numbers)
                        .foregroundColor(winning ? RQColors.success : RQColors.textPrimary)
                }
                .frame(maxWidth: .infinity)

                Text("vs")
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)

                // Their score
                VStack(spacing: RQSpacing.xxs) {
                    Text(opponentName)
                        .font(RQTypography.label)
                        .foregroundColor(RQColors.textTertiary)
                        .textCase(.uppercase)
                        .lineLimit(1)
                    Text(String(format: "%.0f", theirScore))
                        .font(RQTypography.numbers)
                        .foregroundColor(!winning && theirScore > myScore ? RQColors.error : RQColors.textPrimary)
                }
                .frame(maxWidth: .infinity)
            }

            // Progress bar
            GeometryReader { geometry in
                let total = max(myScore + theirScore, 1)
                let myWidth = CGFloat(myScore / total) * geometry.size.width

                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(RQColors.error.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)

                    Rectangle()
                        .fill(RQColors.success)
                        .frame(width: max(myWidth, 2), height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
        }
        .padding(RQSpacing.cardPadding)
        .background(RQColors.surfacePrimary)
        .cornerRadius(RQRadius.medium)
    }

    private func sentChallengeCard(_ challenge: Challenge) -> some View {
        HStack(spacing: RQSpacing.md) {
            Image(systemName: challenge.challengeType.icon)
                .font(.system(size: 16))
                .foregroundColor(RQColors.textTertiary)

            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                Text(challenge.challengeType.displayName)
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)
                Text("Sent to \(challenge.challengedProfile?.displayName ?? "Someone")")
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
            }

            Spacer()

            Text("Pending")
                .font(RQTypography.label)
                .foregroundColor(RQColors.warning)
                .textCase(.uppercase)
        }
        .padding(RQSpacing.cardPadding)
        .background(RQColors.surfacePrimary)
        .cornerRadius(RQRadius.medium)
    }

    // MARK: - Clubs List

    @ViewBuilder
    private var clubsList: some View {
        if viewModel.userClubs.isEmpty {
            emptyState(
                icon: "person.3.fill",
                title: "No clubs yet",
                message: "Join a club to train with a group and compete together."
            )
        } else {
            ForEach(viewModel.userClubs) { club in
                clubCard(club)
            }
        }
    }

    private func clubCard(_ club: Club) -> some View {
        HStack(spacing: RQSpacing.md) {
            // Club icon
            RoundedRectangle(cornerRadius: RQRadius.medium)
                .fill(RQColors.accent.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 16))
                        .foregroundColor(RQColors.accent)
                )

            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                Text(club.name)
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)

                HStack(spacing: RQSpacing.sm) {
                    HStack(spacing: RQSpacing.xxs) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                        Text("\(club.memberCount)")
                            .font(RQTypography.caption)
                    }
                    .foregroundColor(RQColors.textTertiary)

                    if club.isPublic {
                        HStack(spacing: RQSpacing.xxs) {
                            Image(systemName: "globe")
                                .font(.system(size: 10))
                            Text("Public")
                                .font(RQTypography.caption)
                        }
                        .foregroundColor(RQColors.textTertiary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(RQColors.textTertiary)
        }
        .padding(RQSpacing.cardPadding)
        .background(RQColors.surfacePrimary)
        .cornerRadius(RQRadius.medium)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(RQTypography.label)
                .foregroundColor(RQColors.textTertiary)
                .tracking(1.5)
            Spacer()
        }
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

// MARK: - Create Challenge Sheet

struct CreateChallengeView: View {
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFriendId: UUID?
    @State private var challengeType: ChallengeType = .iqPoints
    @State private var durationDays = 7

    var body: some View {
        NavigationStack {
            VStack(spacing: RQSpacing.lg) {
                // Challenge type
                VStack(alignment: .leading, spacing: RQSpacing.sm) {
                    Text("CHALLENGE TYPE")
                        .font(RQTypography.label)
                        .foregroundColor(RQColors.textTertiary)
                        .tracking(1.5)

                    ForEach([ChallengeType.iqPoints, .prs, .consistency, .volumeExercise], id: \.rawValue) { type in
                        Button {
                            challengeType = type
                        } label: {
                            HStack(spacing: RQSpacing.md) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(challengeType == type ? RQColors.accent : RQColors.textTertiary)
                                    .frame(width: 24)

                                Text(type.displayName)
                                    .font(RQTypography.body)
                                    .foregroundColor(RQColors.textPrimary)

                                Spacer()

                                if challengeType == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(RQColors.accent)
                                }
                            }
                            .padding(RQSpacing.md)
                            .background(challengeType == type ? RQColors.accent.opacity(0.1) : RQColors.surfaceTertiary)
                            .cornerRadius(RQRadius.medium)
                        }
                    }
                }

                // Duration
                VStack(alignment: .leading, spacing: RQSpacing.sm) {
                    Text("DURATION")
                        .font(RQTypography.label)
                        .foregroundColor(RQColors.textTertiary)
                        .tracking(1.5)

                    HStack(spacing: RQSpacing.sm) {
                        ForEach([3, 7, 14, 30], id: \.self) { days in
                            Button {
                                durationDays = days
                            } label: {
                                Text("\(days)d")
                                    .font(RQTypography.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(durationDays == days ? RQColors.background : RQColors.textSecondary)
                                    .padding(.horizontal, RQSpacing.md)
                                    .padding(.vertical, RQSpacing.sm)
                                    .background(durationDays == days ? RQColors.accent : RQColors.surfaceTertiary)
                                    .cornerRadius(RQRadius.large)
                            }
                        }
                        Spacer()
                    }
                }

                // Friend picker
                VStack(alignment: .leading, spacing: RQSpacing.sm) {
                    Text("CHALLENGE")
                        .font(RQTypography.label)
                        .foregroundColor(RQColors.textTertiary)
                        .tracking(1.5)

                    if viewModel.friends.isEmpty {
                        Text("Add friends first to create challenges")
                            .font(RQTypography.footnote)
                            .foregroundColor(RQColors.textTertiary)
                    } else {
                        ForEach(viewModel.friends) { friendship in
                            let friendId = friendship.userId == viewModel.currentUserId ? friendship.friendId : friendship.userId
                            Button {
                                selectedFriendId = friendId
                            } label: {
                                HStack(spacing: RQSpacing.md) {
                                    Circle()
                                        .fill(RQColors.accent.opacity(0.2))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Text(String((friendship.friendProfile?.displayName ?? "?").prefix(1)).uppercased())
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(RQColors.accent)
                                        )

                                    Text(friendship.friendProfile?.displayName ?? "Friend")
                                        .font(RQTypography.body)
                                        .foregroundColor(RQColors.textPrimary)

                                    Spacer()

                                    if selectedFriendId == friendId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(RQColors.accent)
                                    }
                                }
                                .padding(RQSpacing.sm)
                                .background(selectedFriendId == friendId ? RQColors.accent.opacity(0.1) : Color.clear)
                                .cornerRadius(RQRadius.small)
                            }
                        }
                    }
                }

                Spacer()

                // Create button
                Button {
                    guard let friendId = selectedFriendId else { return }
                    Task {
                        await viewModel.createChallenge(
                            challengedId: friendId,
                            type: challengeType,
                            days: durationDays
                        )
                        dismiss()
                    }
                } label: {
                    Text("Send Challenge")
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RQSpacing.lg)
                        .background(selectedFriendId != nil ? RQColors.accent : RQColors.surfaceTertiary)
                        .cornerRadius(RQRadius.medium)
                }
                .disabled(selectedFriendId == nil)
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.lg)
            .background(RQColors.background)
            .navigationTitle("New Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(RQColors.textSecondary)
                }
            }
        }
    }
}
