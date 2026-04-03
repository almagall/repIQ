import SwiftUI
import Supabase

struct PrivacySettingsView: View {
    @State private var selectedPrivacy: PrivacyLevel = .friendsOnly
    @State private var isSaving = false
    @State private var saveSuccess = false
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.lg) {
                RQCard {
                    VStack(alignment: .leading, spacing: RQSpacing.lg) {
                        Text("Workout Visibility")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)

                        Text("Control who can see your workout activity, stats, and progress.")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)

                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, RQSpacing.md)
                        } else {
                            ForEach(PrivacyLevel.allCases, id: \.self) { level in
                                privacyOption(level)
                            }
                        }
                    }
                }

                if !isLoading {
                    // Save button
                    Button {
                        Task { await savePrivacy() }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(RQColors.background)
                            } else if saveSuccess {
                                Image(systemName: "checkmark")
                                Text("Saved")
                            } else {
                                Text("Save")
                            }
                        }
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RQSpacing.md)
                        .background(RQColors.accent)
                        .cornerRadius(RQRadius.medium)
                    }
                    .disabled(isSaving)
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.top, RQSpacing.lg)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .background(RQColors.background)
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await loadPrivacy()
        }
    }

    private func privacyOption(_ level: PrivacyLevel) -> some View {
        let isSelected = selectedPrivacy == level

        return Button {
            selectedPrivacy = level
            saveSuccess = false
        } label: {
            HStack(spacing: RQSpacing.md) {
                Image(systemName: privacyIcon(level))
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? RQColors.accent : RQColors.textTertiary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(level.displayName)
                        .font(RQTypography.body)
                        .foregroundColor(RQColors.textPrimary)

                    Text(privacyDescription(level))
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? RQColors.accent : RQColors.textTertiary)
            }
            .padding(.vertical, RQSpacing.xs)
        }
    }

    private func privacyIcon(_ level: PrivacyLevel) -> String {
        switch level {
        case .public_: return "globe"
        case .friendsOnly: return "person.2.fill"
        case .private_: return "lock.fill"
        }
    }

    private func privacyDescription(_ level: PrivacyLevel) -> String {
        switch level {
        case .public_: return "Anyone can see your workouts"
        case .friendsOnly: return "Only friends see your workouts"
        case .private_: return "Your workouts are hidden"
        }
    }

    // MARK: - Data

    private func loadPrivacy() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        struct Row: Decodable {
            let privacy_level: String?
        }

        if let row: Row = try? await supabase.from("profiles")
            .select("privacy_level")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value,
           let raw = row.privacy_level,
           let level = PrivacyLevel(rawValue: raw) {
            selectedPrivacy = level
        }
        isLoading = false
    }

    private func savePrivacy() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        isSaving = true
        saveSuccess = false

        struct Payload: Encodable {
            let privacy_level: String
        }

        do {
            try await supabase.from("profiles")
                .update(Payload(privacy_level: selectedPrivacy.rawValue))
                .eq("id", value: userId.uuidString)
                .execute()
            saveSuccess = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                saveSuccess = false
            }
        } catch {
            // Update failed — button stays on "Save"
        }
        isSaving = false
    }
}
