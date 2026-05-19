import SwiftUI

/// Friend detail screen reached by tapping a friend card. Surfaces the
/// friend's public social stats (league tier, IQ, streak) and the actions
/// — Progression Race, Challenge, Remove — that were otherwise unreachable
/// from the friend list.
struct FriendProfileView: View {
    @Bindable var viewModel: SocialViewModel
    let friendship: Friendship

    @State private var profile: SocialProfile?
    @State private var isLoading = true
    @State private var showCreateChallenge = false
    @State private var sharedTemplates: [Template] = []
    @State private var cloningTemplateId: UUID?
    @State private var cloneSuccessTemplate: Template?
    @Environment(\.dismiss) private var dismiss

    private let service = SocialService()
    private let templateService = TemplateService()

    private var displayName: String {
        friendship.friendProfile?.username ?? "User"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.lg) {
                header

                if isLoading {
                    ProgressView()
                        .tint(RQColors.accent)
                        .padding(.top, RQSpacing.xxl)
                } else {
                    statsRow
                    actionsSection
                    if !sharedTemplates.isEmpty {
                        sharedTemplatesSection
                    }
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.lg)
        }
        .background(RQColors.background)
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProfile()
            await loadSharedTemplates()
        }
        .sheet(isPresented: $showCreateChallenge) {
            CreateChallengeView(viewModel: viewModel, preselectedFriend: friendship)
        }
        .alert("Template copied",
               isPresented: Binding(
                get: { cloneSuccessTemplate != nil },
                set: { if !$0 { cloneSuccessTemplate = nil } }
               ),
               presenting: cloneSuccessTemplate
        ) { _ in
            Button("OK") { cloneSuccessTemplate = nil }
        } message: { template in
            Text("\"\(template.name) (Copy)\" is now in your templates.")
        }
    }

    // MARK: - Shared templates

    private var sharedTemplatesSection: some View {
        VStack(alignment: .leading, spacing: RQSpacing.sm) {
            HStack(spacing: RQSpacing.xs) {
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 12))
                    .foregroundColor(RQColors.accent)
                Text("SHARED TEMPLATES")
                    .font(RQTypography.label)
                    .tracking(1.5)
                    .foregroundColor(RQColors.textSecondary)
            }

            ForEach(sharedTemplates) { template in
                RQCard {
                    HStack(spacing: RQSpacing.md) {
                        VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                            Text(template.name)
                                .font(RQTypography.headline)
                                .foregroundColor(RQColors.textPrimary)
                            if let desc = template.description, !desc.isEmpty {
                                Text(desc)
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        Button {
                            Task { await cloneTemplate(template) }
                        } label: {
                            if cloningTemplateId == template.id {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: RQColors.background))
                                    .scaleEffect(0.7)
                                    .padding(.horizontal, RQSpacing.md)
                                    .padding(.vertical, RQSpacing.sm)
                                    .background(RQColors.accent)
                                    .cornerRadius(RQRadius.large)
                            } else {
                                Text("Try It")
                                    .font(RQTypography.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(RQColors.background)
                                    .padding(.horizontal, RQSpacing.md)
                                    .padding(.vertical, RQSpacing.sm)
                                    .background(RQColors.accent)
                                    .cornerRadius(RQRadius.large)
                            }
                        }
                        .disabled(cloningTemplateId != nil)
                    }
                }
            }
        }
    }

    private func loadSharedTemplates() async {
        do {
            sharedTemplates = try await templateService.fetchSharedTemplates(of: friendship.friendId)
        } catch {
            sharedTemplates = []
        }
    }

    private func cloneTemplate(_ template: Template) async {
        guard let uid = viewModel.currentUserId else { return }
        cloningTemplateId = template.id
        defer { cloningTemplateId = nil }
        do {
            let copy = try await templateService.duplicateTemplate(
                templateId: template.id,
                userId: uid
            )
            cloneSuccessTemplate = copy
        } catch {
            // Silently fail — surfacing this would need an error toast,
            // which we don't have a primitive for yet.
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: RQSpacing.md) {
            Circle()
                .fill(RQColors.accent.opacity(0.2))
                .frame(width: 84, height: 84)
                .overlay(
                    Text(String(displayName.prefix(1)).uppercased())
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(RQColors.accent)
                )

            VStack(spacing: RQSpacing.xxs) {
                Text(displayName)
                    .font(RQTypography.largeTitle)
                    .foregroundColor(RQColors.textPrimary)
                if let username = friendship.friendProfile?.username {
                    Text("@\(username)")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }
            }

            if let bio = profile?.bio, !bio.isEmpty {
                Text(bio)
                    .font(RQTypography.body)
                    .foregroundColor(RQColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, RQSpacing.lg)
            }
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        RQCard {
            HStack(spacing: RQSpacing.lg) {
                statBlock(value: "\(profile?.totalIQ ?? 0)",
                          label: "IQ POINTS",
                          color: RQColors.accent)
                Divider().frame(height: 36).overlay(RQColors.surfaceTertiary)
                statBlock(value: profile?.leagueTier?.displayName ?? "—",
                          label: "LEAGUE",
                          color: tierColor(profile?.leagueTier))
                Divider().frame(height: 36).overlay(RQColors.surfaceTertiary)
                statBlock(value: "\(profile?.currentStreak ?? 0)",
                          label: "STREAK",
                          color: RQColors.warning)
            }
        }
    }

    private func statBlock(value: String, label: String, color: Color) -> some View {
        VStack(spacing: RQSpacing.xxs) {
            Text(value)
                .font(RQTypography.numbers)
                .foregroundColor(color)
            Text(label)
                .font(RQTypography.label)
                .tracking(1.5)
                .foregroundColor(RQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func tierColor(_ tier: LeagueTier?) -> Color {
        switch tier {
        case .elite, .diamond: return RQColors.accent
        case .platinum, .gold: return RQColors.warning
        default: return RQColors.textSecondary
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: RQSpacing.sm) {
            NavigationLink(value: SocialDestination.progressionRace(friendship)) {
                actionRow(icon: "chart.line.uptrend.xyaxis",
                          title: "Progression Race",
                          subtitle: "Compare your gains side-by-side")
            }

            Button {
                showCreateChallenge = true
            } label: {
                actionRow(icon: "flag.checkered",
                          title: "Start a Challenge",
                          subtitle: "Head-to-head over 7 days")
            }

            Button(role: .destructive) {
                Task {
                    await viewModel.removeFriend(friendship)
                    dismiss()
                }
            } label: {
                actionRow(icon: "person.badge.minus",
                          title: "Remove Friend",
                          subtitle: nil,
                          destructive: true)
            }
        }
    }

    private func actionRow(icon: String, title: String, subtitle: String?, destructive: Bool = false) -> some View {
        RQCard {
            HStack(spacing: RQSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(destructive ? RQColors.error : RQColors.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(title)
                        .font(RQTypography.headline)
                        .foregroundColor(destructive ? RQColors.error : RQColors.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }
                }

                Spacer()

                if !destructive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(RQColors.textTertiary)
                }
            }
        }
    }

    // MARK: - Load

    private func loadProfile() async {
        isLoading = true
        do {
            profile = try await service.fetchSocialProfile(userId: friendship.friendId)
        } catch {
            profile = nil
        }
        isLoading = false
    }
}
