import SwiftUI

struct SessionDetailView: View {
    @Bindable var viewModel: ProgressDashboardViewModel
    let sessionId: UUID

    @State private var isEditing = false
    @State private var editedSets: [UUID: EditableSet] = [:]
    @State private var isSaving = false

    private let workoutService = WorkoutService()

    struct EditableSet {
        var weight: String
        var reps: String
        var rpe: String
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoadingDetail {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                    .frame(maxWidth: .infinity, minHeight: 300)
            } else if let detail = viewModel.sessionDetail {
                VStack(spacing: RQSpacing.xl) {
                    // Stats row
                    HStack(spacing: RQSpacing.lg) {
                        statCard(
                            label: "Duration",
                            value: formatDuration(detail.session.durationSeconds ?? 0),
                            icon: "clock"
                        )
                        statCard(
                            label: "Sets",
                            value: "\(detail.totalSets)",
                            icon: "number"
                        )
                        statCard(
                            label: "Volume",
                            value: formatVolume(detail.totalVolume),
                            icon: "scalemass"
                        )
                    }

                    // Exercise Breakdown
                    if !detail.setsByExercise.isEmpty {
                        VStack(alignment: .leading, spacing: RQSpacing.md) {
                            Text("Exercise Breakdown")
                                .font(RQTypography.label)
                                .textCase(.uppercase)
                                .tracking(1.5)
                                .foregroundColor(RQColors.textSecondary)

                            ForEach(detail.setsByExercise, id: \.exerciseId) { group in
                                exerciseCard(name: group.name, sets: group.sets)
                            }
                        }
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.top, RQSpacing.lg)
                .padding(.bottom, RQSpacing.xxxl)
            }
        }
        .background(RQColors.background)
        .navigationTitle("Session Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isEditing {
                    Button {
                        Task { await saveEdits() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                                .foregroundColor(RQColors.accent)
                        }
                    }
                    .disabled(isSaving)
                } else {
                    Menu {
                        Button {
                            enterEditMode()
                        } label: {
                            Label("Edit Workout", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(RQColors.textSecondary)
                    }
                }
            }

            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isEditing = false
                        editedSets = [:]
                    }
                    .foregroundColor(RQColors.textSecondary)
                }
            }
        }
        .task {
            await viewModel.loadSessionDetail(sessionId: sessionId)
        }
    }

    // MARK: - Edit Mode

    private func enterEditMode() {
        guard let detail = viewModel.sessionDetail else { return }
        editedSets = [:]
        for set in detail.sets {
            editedSets[set.id] = EditableSet(
                weight: formatWeight(set.weight),
                reps: "\(set.reps)",
                rpe: set.rpe.map { formatRPE($0) } ?? ""
            )
        }
        isEditing = true
    }

    private func saveEdits() async {
        isSaving = true
        for (setId, edited) in editedSets {
            let weight = Double(edited.weight) ?? 0
            let reps = Int(edited.reps) ?? 0
            let rpe = Double(edited.rpe)

            do {
                try await workoutService.updateSet(id: setId, weight: weight, reps: reps, rpe: rpe)
            } catch {
                // Continue saving other sets
            }
        }
        // Reload to reflect changes
        await viewModel.loadSessionDetail(sessionId: sessionId)
        isEditing = false
        editedSets = [:]
        isSaving = false
    }

    // MARK: - Stat Card

    private func statCard(label: String, value: String, icon: String) -> some View {
        RQCard {
            VStack(spacing: RQSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(RQColors.accent)

                Text(value)
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)

                Text(label)
                    .font(RQTypography.label)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(RQColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Exercise Card

    private func exerciseCard(name: String, sets: [WorkoutSet]) -> some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.md) {
                // Exercise header
                HStack {
                    Text(name)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)

                    Spacer()

                    let exerciseVolume = sets.reduce(0.0) { $0 + $1.volume }
                    VStack(alignment: .trailing, spacing: RQSpacing.xxs) {
                        Text(formatVolume(exerciseVolume))
                            .font(RQTypography.numbersSmall)
                            .foregroundColor(RQColors.accent)
                        Text("volume")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }
                }

                Divider().background(RQColors.surfaceTertiary)

                // Column headers
                HStack(spacing: RQSpacing.sm) {
                    Text("SET")
                        .frame(width: 30, alignment: .center)
                    Text("TYPE")
                        .frame(width: 40, alignment: .center)
                    Text("LBS")
                        .frame(width: 56, alignment: .center)
                    Text("REPS")
                        .frame(width: 40, alignment: .center)
                    Text("RPE")
                        .frame(width: 40, alignment: .center)
                    Spacer()
                }
                .font(RQTypography.caption)
                .foregroundColor(RQColors.textTertiary)

                // Set rows
                ForEach(sets) { set in
                    if isEditing {
                        editableSetRow(set)
                    } else {
                        setRow(set)
                    }
                }
            }
        }
    }

    // MARK: - Set Row (Read-only)

    private func setRow(_ set: WorkoutSet) -> some View {
        HStack(spacing: RQSpacing.sm) {
            Text("\(set.setNumber)")
                .font(RQTypography.numbersSmall)
                .foregroundColor(RQColors.textPrimary)
                .frame(width: 30, alignment: .center)

            Text(set.setType.shortName)
                .font(RQTypography.caption)
                .foregroundColor(colorForSetType(set.setType))
                .frame(width: 40, alignment: .center)

            Text(formatWeight(set.weight))
                .font(RQTypography.numbersSmall)
                .foregroundColor(RQColors.textPrimary)
                .frame(width: 56, alignment: .center)

            Text("\(set.reps)")
                .font(RQTypography.numbersSmall)
                .foregroundColor(RQColors.textPrimary)
                .frame(width: 40, alignment: .center)

            Text(set.rpe.map { formatRPE($0) } ?? "—")
                .font(RQTypography.numbersSmall)
                .foregroundColor(set.rpe != nil ? RQColors.textSecondary : RQColors.textTertiary)
                .frame(width: 40, alignment: .center)

            Spacer()

            if set.isPR {
                Text("PR")
                    .font(RQTypography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(RQColors.warning)
            }
        }
        .padding(.vertical, RQSpacing.xxs)
    }

    // MARK: - Set Row (Editable)

    private func editableSetRow(_ set: WorkoutSet) -> some View {
        HStack(spacing: RQSpacing.sm) {
            Text("\(set.setNumber)")
                .font(RQTypography.numbersSmall)
                .foregroundColor(RQColors.textPrimary)
                .frame(width: 30, alignment: .center)

            Text(set.setType.shortName)
                .font(RQTypography.caption)
                .foregroundColor(colorForSetType(set.setType))
                .frame(width: 40, alignment: .center)

            // Editable weight
            TextField("0", text: editBinding(for: set.id, keyPath: \.weight))
                .font(RQTypography.numbersSmall)
                .foregroundColor(RQColors.textPrimary)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .frame(width: 56)
                .padding(.vertical, 4)
                .background(RQColors.surfaceTertiary)
                .cornerRadius(RQRadius.small)

            // Editable reps
            TextField("0", text: editBinding(for: set.id, keyPath: \.reps))
                .font(RQTypography.numbersSmall)
                .foregroundColor(RQColors.textPrimary)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .frame(width: 40)
                .padding(.vertical, 4)
                .background(RQColors.surfaceTertiary)
                .cornerRadius(RQRadius.small)

            // Editable RPE
            TextField("—", text: editBinding(for: set.id, keyPath: \.rpe))
                .font(RQTypography.numbersSmall)
                .foregroundColor(RQColors.textSecondary)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .frame(width: 40)
                .padding(.vertical, 4)
                .background(RQColors.surfaceTertiary)
                .cornerRadius(RQRadius.small)

            Spacer()

            if set.isPR {
                Text("PR")
                    .font(RQTypography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(RQColors.warning)
            }
        }
        .padding(.vertical, RQSpacing.xxs)
    }

    private func editBinding(for setId: UUID, keyPath: WritableKeyPath<EditableSet, String>) -> Binding<String> {
        Binding(
            get: { editedSets[setId]?[keyPath: keyPath] ?? "" },
            set: { editedSets[setId]?[keyPath: keyPath] = $0 }
        )
    }

    // MARK: - Helpers

    private func colorForSetType(_ type: SetType) -> Color {
        switch type {
        case .warmup: return RQColors.warmup
        case .working: return RQColors.working
        case .cooldown: return RQColors.cooldown
        case .drop: return RQColors.dropSet
        case .failure: return RQColors.failure
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }

    private func formatRPE(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
