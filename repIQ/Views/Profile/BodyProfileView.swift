import SwiftUI

/// Editable body & injury profile. Captured at onboarding (step 7) and
/// editable here afterward. All fields are optional; the underlying
/// `profiles` columns are nullable. Storage is canonical metric (kg, cm);
/// the UI displays in the user's preferred unit (lbs/inches when
/// `weight_unit == lbs`, kg/cm when `weight_unit == kg`).
struct BodyProfileView: View {
    @Bindable var viewModel: ProfileViewModel

    @State private var sex: BodySex?
    @State private var hasBirthDate: Bool = false
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var heightInput: String = ""
    @State private var weightInput: String = ""
    @State private var selectedInjuries: Set<InjuryType> = []
    @State private var isSaving = false
    @State private var savedToastVisible = false
    @State private var saveErrorMessage: String?

    @Environment(\.dismiss) private var dismiss

    private var weightUnit: WeightUnit { viewModel.profile?.safeWeightUnit ?? .lbs }
    private var heightUnitLabel: String { weightUnit == .lbs ? "in" : "cm" }
    private var weightUnitLabel: String { weightUnit.displayName }

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xl) {
                introCard

                bodySexCard
                heightCard
                weightCard
                birthDateCard
                injuriesCard

                if let saveErrorMessage {
                    Text(saveErrorMessage)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                RQButton(title: "Save Changes", isLoading: isSaving) {
                    Task { await save() }
                }
                .padding(.top, RQSpacing.md)
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(RQColors.background)
        .navigationTitle("Body & Health")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .overlay(alignment: .top) {
            if savedToastVisible {
                savedToast
                    .padding(.top, RQSpacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task {
            // Loads the latest profile in case the parent didn't refresh.
            if viewModel.profile == nil {
                await viewModel.loadProfile()
            }
            seedFieldsFromProfile()
        }
    }

    // MARK: - Cards

    private var introCard: some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.xs) {
                Text("ABOUT YOU")
                    .font(RQTypography.label)
                    .tracking(1.5)
                    .foregroundColor(RQColors.textSecondary)
                Text("Optional. Helps tailor recovery suggestions and unlocks future relative-strength insights. None of this is shared.")
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var bodySexCard: some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                fieldLabel("Sex")
                HStack(spacing: RQSpacing.sm) {
                    ForEach(BodySex.allCases, id: \.self) { value in
                        Button { sex = (sex == value) ? nil : value } label: {
                            Text(value.displayName)
                                .font(RQTypography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(sex == value ? RQColors.background : RQColors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, RQSpacing.sm)
                                .background(sex == value ? RQColors.accent : RQColors.surfaceSecondary)
                                .cornerRadius(RQRadius.medium)
                        }
                    }
                }
            }
        }
    }

    private var heightCard: some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                fieldLabel("Height")
                HStack {
                    TextField(weightUnit == .lbs ? "e.g. 70" : "e.g. 178", text: $heightInput)
                        .keyboardType(.decimalPad)
                        .font(RQTypography.numbersSmall)
                        .padding(RQSpacing.md)
                        .background(RQColors.surfaceSecondary)
                        .cornerRadius(RQRadius.medium)
                        .foregroundColor(RQColors.textPrimary)
                    Text(heightUnitLabel)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                        .padding(.leading, RQSpacing.xs)
                }
            }
        }
    }

    private var weightCard: some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                fieldLabel("Body Weight")
                HStack {
                    TextField(weightUnit == .lbs ? "e.g. 175" : "e.g. 80", text: $weightInput)
                        .keyboardType(.decimalPad)
                        .font(RQTypography.numbersSmall)
                        .padding(RQSpacing.md)
                        .background(RQColors.surfaceSecondary)
                        .cornerRadius(RQRadius.medium)
                        .foregroundColor(RQColors.textPrimary)
                    Text(weightUnitLabel)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textTertiary)
                        .padding(.leading, RQSpacing.xs)
                }
            }
        }
    }

    private var birthDateCard: some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                HStack {
                    fieldLabel("Birth Date")
                    Spacer()
                    Toggle("", isOn: $hasBirthDate)
                        .tint(RQColors.accent)
                        .labelsHidden()
                }

                if hasBirthDate {
                    DatePicker(
                        "Birth Date",
                        selection: $birthDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(RQColors.accent)
                    .padding(RQSpacing.sm)
                    .background(RQColors.surfaceSecondary)
                    .cornerRadius(RQRadius.medium)
                }
            }
        }
    }

    private var injuriesCard: some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                fieldLabel("Active Injuries")
                Text("Tap any that apply. Used to flag risky exercises later.")
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 110), spacing: RQSpacing.sm)],
                    alignment: .leading,
                    spacing: RQSpacing.sm
                ) {
                    ForEach(InjuryType.allCases, id: \.self) { injury in
                        Button {
                            if selectedInjuries.contains(injury) {
                                selectedInjuries.remove(injury)
                            } else {
                                selectedInjuries.insert(injury)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: injury.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(injury.displayName)
                                    .font(RQTypography.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(selectedInjuries.contains(injury) ? RQColors.background : RQColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, RQSpacing.sm)
                            .background(selectedInjuries.contains(injury) ? RQColors.accent : RQColors.surfaceSecondary)
                            .cornerRadius(RQRadius.large)
                        }
                    }
                }
            }
        }
    }

    private var savedToast: some View {
        Text("Saved")
            .font(RQTypography.caption)
            .fontWeight(.semibold)
            .foregroundColor(RQColors.background)
            .padding(.horizontal, RQSpacing.lg)
            .padding(.vertical, RQSpacing.sm)
            .background(RQColors.success, in: Capsule())
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(RQTypography.label)
            .tracking(1.5)
            .foregroundColor(RQColors.textSecondary)
    }

    // MARK: - Seeding & Saving

    private func seedFieldsFromProfile() {
        guard let p = viewModel.profile else { return }
        sex = BodySex(rawValue: p.sex ?? "")
        if let bd = p.birthDate {
            birthDate = bd
            hasBirthDate = true
        }
        heightInput = formatNumberInput(displayHeight(p.heightCm))
        weightInput = formatNumberInput(displayWeight(p.bodyWeightKg))
        selectedInjuries = Set((p.injuries ?? []).compactMap { InjuryType(rawValue: $0) })
    }

    @MainActor
    private func save() async {
        isSaving = true
        saveErrorMessage = nil

        // Convert displayed inputs back to canonical metric.
        let heightCm: Double? = parsedHeightToCm()
        let weightKg: Double? = parsedWeightToKg()
        let injuries = selectedInjuries.isEmpty
            ? nil
            : Array(selectedInjuries.map(\.rawValue)).sorted()

        do {
            try await viewModel.updateBodyProfile(
                sex: sex?.rawValue,
                birthDate: hasBirthDate ? birthDate : nil,
                heightCm: heightCm,
                bodyWeightKg: weightKg,
                injuries: injuries
            )
            withAnimation(.easeOut(duration: 0.2)) { savedToastVisible = true }
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeIn(duration: 0.25)) { savedToastVisible = false }
        } catch {
            saveErrorMessage = (error as NSError).localizedDescription
        }
        isSaving = false
    }

    // MARK: - Unit conversions

    private func displayHeight(_ cm: Double?) -> Double? {
        guard let cm else { return nil }
        return weightUnit == .lbs ? cm / 2.54 : cm
    }

    private func displayWeight(_ kg: Double?) -> Double? {
        guard let kg else { return nil }
        return weightUnit == .lbs ? kg / 0.45359237 : kg
    }

    private func parsedHeightToCm() -> Double? {
        guard let raw = Double(heightInput.trimmingCharacters(in: .whitespaces)), raw > 0 else { return nil }
        return weightUnit == .lbs ? raw * 2.54 : raw
    }

    private func parsedWeightToKg() -> Double? {
        guard let raw = Double(weightInput.trimmingCharacters(in: .whitespaces)), raw > 0 else { return nil }
        return weightUnit == .lbs ? raw * 0.45359237 : raw
    }

    private func formatNumberInput(_ value: Double?) -> String {
        guard let value else { return "" }
        // Display whole numbers as integers, otherwise one decimal place.
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}
