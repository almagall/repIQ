import SwiftUI

/// Single-club view: header, members list, and the join/leave action. The
/// `onChange` callback lets the parent refresh `userClubs` after the user
/// joins or leaves so the list and the chevron state stay in sync.
struct ClubDetailView: View {
    @Bindable var viewModel: SocialViewModel
    let club: Club
    let onChange: () -> Void

    @State private var members: [ClubMember] = []
    @State private var isLoading = true
    @State private var isMutating = false
    @Environment(\.dismiss) private var dismiss

    private let service = ChallengeService()

    private var isMember: Bool {
        viewModel.userClubs.contains { $0.id == club.id }
    }

    private var isOwner: Bool {
        guard let uid = viewModel.currentUserId else { return false }
        return club.ownerId == uid
    }

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xl) {
                header
                membersSection
                actionButton
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.lg)
        }
        .background(RQColors.background)
        .navigationTitle(club.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadMembers() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: RQSpacing.md) {
            Image(systemName: club.isPublic ? "person.3.fill" : "lock.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(RQColors.accent)
                .padding(RQSpacing.lg)
                .background(RQColors.accent.opacity(0.15))
                .clipShape(Circle())

            VStack(spacing: RQSpacing.xxs) {
                Text(club.name)
                    .font(RQTypography.largeTitle)
                    .foregroundColor(RQColors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("\(club.memberCount) member\(club.memberCount == 1 ? "" : "s") · \(club.isPublic ? "Public" : "Private")")
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
            }

            if let desc = club.description, !desc.isEmpty {
                Text(desc)
                    .font(RQTypography.body)
                    .foregroundColor(RQColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, RQSpacing.lg)
            }
        }
    }

    // MARK: - Members

    @ViewBuilder
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.sm) {
            Text("MEMBERS")
                .font(RQTypography.label)
                .tracking(1.5)
                .foregroundColor(RQColors.textSecondary)

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView().tint(RQColors.accent)
                    Spacer()
                }
                .padding(.vertical, RQSpacing.xl)
            } else if members.isEmpty {
                Text("No members yet")
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RQSpacing.lg)
            } else {
                ForEach(members) { member in
                    memberRow(member)
                }
            }
        }
    }

    private func memberRow(_ member: ClubMember) -> some View {
        let name = member.memberProfile?.username ?? "User"

        return RQCard {
            HStack(spacing: RQSpacing.md) {
                Circle()
                    .fill(RQColors.accent.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(RQColors.accent)
                    )

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(name)
                        .font(RQTypography.body)
                        .foregroundColor(RQColors.textPrimary)
                    if member.role != .member {
                        Text(member.role.rawValue.uppercased())
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(1)
                            .foregroundColor(RQColors.warning)
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Action

    @ViewBuilder
    private var actionButton: some View {
        if isOwner {
            Text("You own this club. Leaving will leave it ownerless — use the destructive flow if you really want out.")
                .font(RQTypography.footnote)
                .foregroundColor(RQColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, RQSpacing.lg)
        } else if isMember {
            Button(role: .destructive) {
                Task { await leave() }
            } label: {
                actionLabel(text: "Leave Club", color: RQColors.error, isLoading: isMutating)
            }
        } else {
            Button {
                Task { await join() }
            } label: {
                actionLabel(text: "Join Club", color: RQColors.accent, isLoading: isMutating)
            }
        }
    }

    private func actionLabel(text: String, color: Color, isLoading: Bool) -> some View {
        HStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: color == RQColors.accent ? RQColors.background : color))
                    .scaleEffect(0.7)
            } else {
                Text(text)
                    .font(RQTypography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(color == RQColors.accent ? RQColors.background : color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, RQSpacing.md)
        .background(color == RQColors.accent ? color : color.opacity(0.12))
        .cornerRadius(RQRadius.medium)
    }

    // MARK: - Actions

    private func loadMembers() async {
        isLoading = true
        defer { isLoading = false }
        do {
            members = try await service.fetchClubMembers(clubId: club.id)
        } catch {
            members = []
        }
    }

    private func join() async {
        guard let uid = viewModel.currentUserId else { return }
        isMutating = true
        defer { isMutating = false }
        do {
            try await service.joinClub(clubId: club.id, userId: uid)
            await loadMembers()
            onChange()
        } catch {
            // Silently fail — service is best-effort. A future iteration
            // should surface this via an inline error banner.
        }
    }

    private func leave() async {
        guard let uid = viewModel.currentUserId else { return }
        isMutating = true
        defer { isMutating = false }
        do {
            try await service.leaveClub(clubId: club.id, userId: uid)
            onChange()
            dismiss()
        } catch {}
    }
}
