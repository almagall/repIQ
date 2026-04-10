import SwiftUI
import Supabase

/// A form for creating a custom exercise that gets added to the user's
/// personal exercise library alongside the built-in exercises.
struct CreateCustomExerciseView: View {
    let onCreated: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedMuscleGroup: MuscleGroup = .chest
    @State private var selectedEquipment: Equipment = .barbell
    @State private var isCompound = false
    @State private var notes = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let service = ExerciseLibraryService()

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RQSpacing.xl) {
                    // Name
                    VStack(alignment: .leading, spacing: RQSpacing.xs) {
                        Text("EXERCISE NAME")
                            .font(RQTypography.label)
                            .tracking(1)
                            .foregroundColor(RQColors.textSecondary)

                        TextField("e.g. Chest Press Machine", text: $name)
                            .font(RQTypography.body)
                            .foregroundColor(RQColors.textPrimary)
                            .padding(RQSpacing.md)
                            .background(RQColors.surfaceTertiary)
                            .cornerRadius(RQRadius.medium)
                            .autocorrectionDisabled()
                    }

                    // Muscle Group
                    VStack(alignment: .leading, spacing: RQSpacing.xs) {
                        Text("MUSCLE GROUP")
                            .font(RQTypography.label)
                            .tracking(1)
                            .foregroundColor(RQColors.textSecondary)

                        muscleGroupPicker
                    }

                    // Equipment
                    VStack(alignment: .leading, spacing: RQSpacing.xs) {
                        Text("EQUIPMENT")
                            .font(RQTypography.label)
                            .tracking(1)
                            .foregroundColor(RQColors.textSecondary)

                        equipmentPicker
                    }

                    // Compound Toggle
                    RQCard {
                        HStack {
                            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                                Text("Compound Exercise")
                                    .font(RQTypography.body)
                                    .foregroundColor(RQColors.textPrimary)
                                Text("Uses multiple joints and muscle groups")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                            }
                            Spacer()
                            Toggle("", isOn: $isCompound)
                                .tint(RQColors.accent)
                                .labelsHidden()
                        }
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: RQSpacing.xs) {
                        Text("NOTES (OPTIONAL)")
                            .font(RQTypography.label)
                            .tracking(1)
                            .foregroundColor(RQColors.textSecondary)

                        TextEditor(text: $notes)
                            .font(RQTypography.body)
                            .foregroundColor(RQColors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 80)
                            .padding(RQSpacing.sm)
                            .background(RQColors.surfaceTertiary)
                            .cornerRadius(RQRadius.medium)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.error)
                    }

                    // Create Button
                    Button {
                        Task { await createExercise() }
                    } label: {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: RQColors.background))
                                    .scaleEffect(0.8)
                            }
                            Text("Create Exercise")
                                .font(RQTypography.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RQSpacing.md)
                        .background(isFormValid ? RQColors.accent : RQColors.textTertiary.opacity(0.3))
                        .foregroundColor(isFormValid ? RQColors.background : RQColors.textTertiary)
                        .cornerRadius(RQRadius.medium)
                    }
                    .disabled(!isFormValid || isCreating)
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.top, RQSpacing.lg)
                .padding(.bottom, RQSpacing.xxxl)
            }
            .background(RQColors.background)
            .navigationTitle("Custom Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(RQColors.accent)
                }
            }
        }
    }

    // MARK: - Pickers

    private var muscleGroupPicker: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: RQSpacing.sm) {
            ForEach(MuscleGroup.allCases, id: \.self) { group in
                Button {
                    selectedMuscleGroup = group
                } label: {
                    Text(group.displayName)
                        .font(RQTypography.label)
                        .tracking(0.5)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RQSpacing.sm)
                        .foregroundColor(selectedMuscleGroup == group ? RQColors.background : RQColors.textSecondary)
                        .background(selectedMuscleGroup == group ? RQColors.accent : Color.clear)
                        .cornerRadius(RQRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: RQRadius.small)
                                .stroke(
                                    selectedMuscleGroup == group ? RQColors.accent : RQColors.textTertiary,
                                    lineWidth: 1
                                )
                        )
                }
            }
        }
    }

    private var equipmentPicker: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: RQSpacing.sm) {
            ForEach(Equipment.allCases, id: \.self) { equip in
                Button {
                    selectedEquipment = equip
                } label: {
                    Text(equip.displayName)
                        .font(RQTypography.label)
                        .tracking(0.5)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RQSpacing.sm)
                        .foregroundColor(selectedEquipment == equip ? RQColors.background : RQColors.textSecondary)
                        .background(selectedEquipment == equip ? RQColors.accent : Color.clear)
                        .cornerRadius(RQRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: RQRadius.small)
                                .stroke(
                                    selectedEquipment == equip ? RQColors.accent : RQColors.textTertiary,
                                    lineWidth: 1
                                )
                        )
                }
            }
        }
    }

    // MARK: - Create

    private func createExercise() async {
        guard isFormValid else { return }
        isCreating = true
        errorMessage = nil

        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                errorMessage = "Not authenticated."
                isCreating = false
                return
            }

            let exercise = try await service.createCustomExercise(
                userId: userId,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                muscleGroup: selectedMuscleGroup.rawValue,
                equipment: selectedEquipment.rawValue,
                isCompound: isCompound,
                notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            onCreated(exercise)
            dismiss()
        } catch {
            errorMessage = "Failed to create exercise. Please try again."
        }
        isCreating = false
    }
}
