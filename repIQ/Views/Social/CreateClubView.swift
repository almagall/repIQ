import SwiftUI

/// Sheet for creating a new club. Owner-only at creation time (no roster
/// invites here); members join later via the discover list.
struct CreateClubView: View {
    @Bindable var viewModel: SocialViewModel
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var clubDescription = ""
    @State private var isPublic = true
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let service = ChallengeService()

    private var canCreate: Bool {
        name.trimmingCharacters(in: .whitespaces).count >= 3 && !isCreating
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RQSpacing.xl) {
                    field(title: "NAME", subtitle: "3–40 characters") {
                        TextField("Push Pull Legs Crew", text: $name)
                            .textFieldStyle(.plain)
                            .font(RQTypography.body)
                            .foregroundColor(RQColors.textPrimary)
                            .padding(RQSpacing.md)
                            .background(RQColors.surfacePrimary)
                            .cornerRadius(RQRadius.medium)
                            .onChange(of: name) { _, newValue in
                                if newValue.count > 40 {
                                    name = String(newValue.prefix(40))
                                }
                            }
                    }

                    field(title: "DESCRIPTION", subtitle: "What's the shared goal?") {
                        TextEditor(text: $clubDescription)
                            .font(RQTypography.body)
                            .foregroundColor(RQColors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 100)
                            .padding(RQSpacing.md)
                            .background(RQColors.surfacePrimary)
                            .cornerRadius(RQRadius.medium)
                            .onChange(of: clubDescription) { _, newValue in
                                if newValue.count > 200 {
                                    clubDescription = String(newValue.prefix(200))
                                }
                            }
                    }

                    field(title: "VISIBILITY", subtitle: nil) {
                        VStack(spacing: RQSpacing.sm) {
                            visibilityRow(
                                title: "Public",
                                subtitle: "Anyone can find and join your club.",
                                icon: "globe",
                                value: true
                            )
                            visibilityRow(
                                title: "Private",
                                subtitle: "Only people you share the club with can join.",
                                icon: "lock.fill",
                                value: false
                            )
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.vertical, RQSpacing.lg)
            }
            .background(RQColors.background)
            .navigationTitle("New Club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(RQColors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await create() }
                    } label: {
                        if isCreating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                                .scaleEffect(0.7)
                        } else {
                            Text("Create")
                                .font(RQTypography.headline)
                                .foregroundColor(canCreate ? RQColors.accent : RQColors.textTertiary)
                        }
                    }
                    .disabled(!canCreate)
                }
            }
        }
    }

    // MARK: - Components

    private func field<Content: View>(title: String, subtitle: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.sm) {
            HStack {
                Text(title)
                    .font(RQTypography.label)
                    .tracking(1.5)
                    .foregroundColor(RQColors.textSecondary)
                if let subtitle {
                    Spacer()
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(RQColors.textTertiary)
                }
            }
            content()
        }
    }

    private func visibilityRow(title: String, subtitle: String, icon: String, value: Bool) -> some View {
        Button {
            isPublic = value
        } label: {
            HStack(spacing: RQSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isPublic == value ? RQColors.accent : RQColors.textTertiary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(title)
                        .font(RQTypography.body)
                        .foregroundColor(RQColors.textPrimary)
                    Text(subtitle)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }

                Spacer()

                Image(systemName: isPublic == value ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isPublic == value ? RQColors.accent : RQColors.textTertiary)
            }
            .padding(RQSpacing.md)
            .background(isPublic == value ? RQColors.accent.opacity(0.1) : RQColors.surfacePrimary)
            .cornerRadius(RQRadius.medium)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action

    private func create() async {
        guard let uid = viewModel.currentUserId else {
            errorMessage = "Not signed in."
            return
        }
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }
        do {
            _ = try await service.createClub(
                ownerId: uid,
                name: name.trimmingCharacters(in: .whitespaces),
                description: clubDescription.trimmingCharacters(in: .whitespaces),
                isPublic: isPublic
            )
            onCreated()
            dismiss()
        } catch {
            errorMessage = "Could not create club. Try again."
        }
    }
}
