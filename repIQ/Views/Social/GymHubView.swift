import SwiftUI
import Supabase

/// Gym-based social discovery — see and connect with lifters at your gym.
struct GymHubView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var gymName: String?
    @State private var gymAddress: String?
    @State private var gymPlaceId: String?
    @State private var gymMembers: [GymService.GymMember] = []
    @State private var gymFeedItems: [FeedItem] = []
    @State private var trainingNow: [TrainingNowEntry] = []
    @State private var isLoadingMembers = false
    @State private var isLoadingFeed = false
    @State private var showGymSearch = false

    private let presenceService = PresenceService()

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.lg) {
                if let name = gymName, !name.isEmpty {
                    // Gym header
                    gymHeader(name: name)

                    // Friends actively training right now
                    if !trainingNow.isEmpty {
                        trainingNowBanner
                    }

                    // Gym members
                    gymMembersSection

                    // Gym activity feed
                    gymActivitySection

                } else {
                    // No gym set — prompt to set one
                    noGymState
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.lg)
        }
        .task {
            await loadGymData()
            await loadTrainingNow()
        }
        .refreshable {
            await loadGymData()
            await loadTrainingNow()
        }
        .navigationDestination(isPresented: $showGymSearch) {
            GymSearchView()
        }
    }

    // MARK: - No Gym State

    // MARK: - Training Now

    private var trainingNowBanner: some View {
        VStack(alignment: .leading, spacing: RQSpacing.sm) {
            HStack(spacing: RQSpacing.xs) {
                Circle()
                    .fill(RQColors.success)
                    .frame(width: 8, height: 8)
                Text("TRAINING NOW")
                    .font(RQTypography.label)
                    .tracking(1.5)
                    .foregroundColor(RQColors.success)
                Spacer()
                Text("\(trainingNow.count) active")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(RQColors.textTertiary)
            }

            ForEach(trainingNow) { entry in
                let name = nameFor(userId: entry.userId)
                HStack(spacing: RQSpacing.md) {
                    Circle()
                        .fill(RQColors.success.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(name.prefix(1)).uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(RQColors.success)
                        )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name)
                            .font(RQTypography.body)
                            .foregroundColor(RQColors.textPrimary)
                        Text("Started \(relativeMinutes(entry.startedAt)) ago")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 14))
                        .foregroundColor(RQColors.success)
                }
            }
        }
        .padding(RQSpacing.cardPadding)
        .background(RQColors.success.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: RQRadius.medium)
                .stroke(RQColors.success.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(RQRadius.medium)
    }

    private func nameFor(userId: UUID) -> String {
        viewModel.friends
            .first { $0.friendId == userId }
            .flatMap { $0.friendProfile?.username }
            ?? "Friend"
    }

    private func relativeMinutes(_ start: Date) -> String {
        let elapsed = Int(Date().timeIntervalSince(start) / 60)
        if elapsed < 1 { return "just now" }
        if elapsed < 60 { return "\(elapsed)m" }
        let hours = elapsed / 60
        return "\(hours)h"
    }

    private func loadTrainingNow() async {
        let friendIds = Array(viewModel.friendIds)
        do {
            trainingNow = try await presenceService.fetchFriendsTraining(friendIds: friendIds)
        } catch {
            trainingNow = []
        }
    }

    private var noGymState: some View {
        VStack(spacing: RQSpacing.xl) {
            Spacer().frame(height: RQSpacing.xxxl)

            Image(systemName: "building.2")
                .font(.system(size: 40))
                .foregroundColor(RQColors.textTertiary)

            VStack(spacing: RQSpacing.sm) {
                Text("Set Your Gym")
                    .font(RQTypography.title2)
                    .foregroundColor(RQColors.textPrimary)

                Text("Connect with other lifters training at the same gym. See their workouts, PRs, and add them as friends.")
                    .font(RQTypography.body)
                    .foregroundColor(RQColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, RQSpacing.lg)
            }

            Button {
                showGymSearch = true
            } label: {
                Text("Find Your Gym")
                    .font(RQTypography.body)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RQSpacing.md)
                    .background(RQColors.accent)
                    .cornerRadius(RQRadius.medium)
            }
            .padding(.horizontal, RQSpacing.xl)
        }
    }

    // MARK: - Gym Header

    private func gymHeader(name: String) -> some View {
        RQCard {
            HStack(spacing: RQSpacing.md) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 24))
                    .foregroundColor(RQColors.accent)

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(name)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)

                    if let address = gymAddress, !address.isEmpty {
                        Text(address)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textSecondary)
                            .lineLimit(1)
                    }

                    Text("\(gymMembers.count) member\(gymMembers.count == 1 ? "" : "s")")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.accent)
                }

                Spacer()

                Button {
                    showGymSearch = true
                } label: {
                    Text("Change")
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(RQColors.accent)
                }
            }
        }
    }

    // MARK: - Gym Members

    private var gymMembersSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            Text("Members")
                .font(RQTypography.label)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(RQColors.textSecondary)

            if isLoadingMembers {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                        .scaleEffect(0.7)
                    Text("Finding members...")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }
                .padding(.vertical, RQSpacing.md)
            } else if gymMembers.isEmpty {
                RQCard {
                    HStack(spacing: RQSpacing.md) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 16))
                            .foregroundColor(RQColors.textTertiary)
                        Text("No other members yet. Be the first to invite a friend.")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }
                }
            } else {
                ForEach(gymMembers) { member in
                    memberCard(member)
                }
            }
        }
    }

    private func memberCard(_ member: GymService.GymMember) -> some View {
        RQCard {
            HStack(spacing: RQSpacing.md) {
                // Avatar
                Circle()
                    .fill(RQColors.accent.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String((member.username ?? "?").prefix(1)).uppercased())
                            .font(RQTypography.caption)
                            .fontWeight(.bold)
                            .foregroundColor(RQColors.accent)
                    )

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(member.username ?? "User")
                        .font(RQTypography.body)
                        .fontWeight(.medium)
                        .foregroundColor(RQColors.textPrimary)

                    if let lastWorkout = member.lastWorkoutDate {
                        Text("Trained \(lastWorkout.relativeDisplay)")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }
                }

                Spacer()

                // Friend status / add button
                let isFriend = viewModel.friendIds.contains(member.id)
                let isSent = viewModel.sentRequestIds.contains(member.id)

                if isFriend {
                    Text("Friends")
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(RQColors.success)
                } else if isSent {
                    Text("Sent")
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
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
        }
    }

    // MARK: - Gym Activity Feed

    private var gymActivitySection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            Text("Gym Activity")
                .font(RQTypography.label)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(RQColors.textSecondary)

            if isLoadingFeed {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                        .scaleEffect(0.7)
                    Text("Loading activity...")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }
                .padding(.vertical, RQSpacing.md)
            } else if gymFeedItems.isEmpty {
                RQCard {
                    HStack(spacing: RQSpacing.md) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 16))
                            .foregroundColor(RQColors.textTertiary)
                        Text("No recent activity from gym members.")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }
                }
            } else {
                ForEach(gymFeedItems.prefix(10)) { item in
                    gymFeedCard(item)
                }
            }
        }
    }

    private func gymFeedCard(_ item: FeedItem) -> some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                // Header
                HStack(spacing: RQSpacing.sm) {
                    Circle()
                        .fill(RQColors.accent.opacity(0.2))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(String((item.userProfile?.username ?? "?").prefix(1)).uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(RQColors.accent)
                        )

                    Text(item.userProfile?.username ?? "User")
                        .font(RQTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(RQColors.textPrimary)

                    Spacer()

                    Text(timeAgo(item.createdAt))
                        .font(.system(size: 10))
                        .foregroundColor(RQColors.textTertiary)
                }

                // Content
                switch item.itemType {
                case .workoutCompleted:
                    if let dayName = item.data.workoutDayName, !dayName.isEmpty {
                        Text("Completed \(dayName)")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textSecondary)
                    } else {
                        Text("Completed a workout")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textSecondary)
                    }

                    // Compact stats
                    HStack(spacing: RQSpacing.lg) {
                        if let sets = item.data.totalSets {
                            Label("\(sets) sets", systemImage: "number")
                                .font(.system(size: 10))
                                .foregroundColor(RQColors.textTertiary)
                        }
                        if let volume = item.data.totalVolume {
                            let formatted = volume >= 1000 ? String(format: "%.1fk", volume / 1000) : "\(Int(volume))"
                            Label("\(formatted) lbs", systemImage: "scalemass")
                                .font(.system(size: 10))
                                .foregroundColor(RQColors.textTertiary)
                        }
                        if let prs = item.data.prCount, prs > 0 {
                            Label("\(prs) PR\(prs == 1 ? "" : "s")", systemImage: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(RQColors.warning)
                        }
                    }

                case .prAchieved:
                    HStack(spacing: RQSpacing.xs) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(RQColors.warning)
                        Text("Hit a new personal record!")
                            .font(RQTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(RQColors.textPrimary)
                    }

                default:
                    Text(item.itemType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadGymData() async {
        // Load gym info
        struct GymFields: Decodable {
            let gymName: String?
            let gymAddress: String?
            let gymPlaceId: String?
            enum CodingKeys: String, CodingKey {
                case gymName = "gym_name"
                case gymAddress = "gym_address"
                case gymPlaceId = "gym_place_id"
            }
        }

        guard let userId = try? await supabase.auth.session.user.id else { return }

        if let fields: GymFields = try? await supabase.from("profiles")
            .select("gym_name, gym_address, gym_place_id")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value {
            gymName = fields.gymName
            gymAddress = fields.gymAddress
            gymPlaceId = fields.gymPlaceId
        }

        // Load members if gym is set
        guard let placeId = gymPlaceId, !placeId.isEmpty else { return }

        isLoadingMembers = true
        gymMembers = (try? await GymService().fetchGymMembers(placeId: placeId, excludeUserId: userId)) ?? []
        isLoadingMembers = false

        // Load gym feed (from all gym members)
        let memberIds = gymMembers.map(\.id)
        guard !memberIds.isEmpty else { return }

        isLoadingFeed = true
        gymFeedItems = (try? await FeedService().fetchFeed(userId: userId, friendIds: memberIds, limit: 20)) ?? []
        // Filter out own items
        gymFeedItems = gymFeedItems.filter { $0.userId != userId }
        isLoadingFeed = false
    }

    // MARK: - Helpers

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        return "\(Int(interval / 604800))w ago"
    }
}
