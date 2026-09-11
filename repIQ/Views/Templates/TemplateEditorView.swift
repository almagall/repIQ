import SwiftUI

struct TemplateEditorView: View {
    @Bindable var viewModel: TemplateEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddDay = false
    @State private var newDayName = ""
    @State private var newDayDescription = ""
    @State private var dayToDelete: WorkoutDay?
    @State private var showDeleteDayConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xl) {
                // Template Info
                RQCard {
                    VStack(alignment: .leading, spacing: RQSpacing.lg) {
                        HStack {
                            Text("Template Info")
                                .font(RQTypography.label)
                                .textCase(.uppercase)
                                .tracking(1.5)
                                .foregroundColor(RQColors.textSecondary)

                            Spacer()

                            // Auto-save status indicator
                            saveStatusView
                        }

                        VStack(alignment: .leading, spacing: RQSpacing.sm) {
                            Text("Name")
                                .font(RQTypography.subheadline)
                                .foregroundColor(RQColors.textSecondary)
                            RQTextField(
                                placeholder: "e.g. Push Pull Legs",
                                text: $viewModel.templateName
                            )
                        }

                        VStack(alignment: .leading, spacing: RQSpacing.sm) {
                            Text("Description (optional)")
                                .font(RQTypography.subheadline)
                                .foregroundColor(RQColors.textSecondary)
                            RQTextField(
                                placeholder: "Brief description of this program",
                                text: $viewModel.templateDescription
                            )
                        }
                    }
                }

                // Workout Days — always visible
                VStack(alignment: .leading, spacing: RQSpacing.md) {
                    HStack {
                        Text("Workout Days")
                            .font(RQTypography.label)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(RQColors.textSecondary)
                        Spacer()
                        Button {
                            if viewModel.isFormValid {
                                showAddDay = true
                            } else {
                                viewModel.errorMessage = "Please enter a template name first."
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(viewModel.isFormValid ? RQColors.accent : RQColors.textTertiary)
                        }
                    }

                    if viewModel.workoutDays.isEmpty {
                        RQCard {
                            Text("No workout days yet. Tap + to add your first day.")
                                .font(RQTypography.subheadline)
                                .foregroundColor(RQColors.textSecondary)
                        }
                    } else {
                        ForEach(viewModel.workoutDays) { day in
                            SwipeToDeleteWrapper {
                                NavigationLink {
                                    WorkoutDayEditorView(
                                        day: day,
                                        viewModel: viewModel
                                    )
                                } label: {
                                    workoutDayCard(day)
                                }
                            } onDelete: {
                                dayToDelete = day
                                showDeleteDayConfirmation = true
                            }
                        }
                    }
                }

                // Error
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(RQTypography.footnote)
                        .foregroundColor(RQColors.error)
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.top, RQSpacing.lg)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .background(RQColors.background)
        .navigationTitle(viewModel.isSaved ? viewModel.templateName : "New Template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    Task {
                        await viewModel.flushSave()
                        dismiss()
                    }
                }
                .foregroundColor(RQColors.accent)
            }
        }
        .alert("Add Workout Day", isPresented: $showAddDay) {
            TextField("Day name (e.g. Push Day)", text: $newDayName)
            TextField("Description (optional)", text: $newDayDescription)
            Button("Add") {
                Task {
                    await viewModel.addWorkoutDay(
                        name: newDayName,
                        description: newDayDescription.isEmpty ? nil : newDayDescription
                    )
                    newDayName = ""
                    newDayDescription = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newDayName = ""
                newDayDescription = ""
            }
        }
        .alert("Delete Workout Day?", isPresented: $showDeleteDayConfirmation) {
            Button("Delete", role: .destructive) {
                if let day = dayToDelete {
                    Task { await viewModel.deleteWorkoutDay(day) }
                }
                dayToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                dayToDelete = nil
            }
        } message: {
            if let day = dayToDelete {
                let count = day.exercises?.count ?? 0
                if count > 0 {
                    Text("This will permanently delete \"\(day.name)\" and its \(count) exercise\(count == 1 ? "" : "s").")
                } else {
                    Text("This will permanently delete \"\(day.name)\".")
                }
            } else {
                Text("Are you sure you want to delete this workout day?")
            }
        }
    }

    // MARK: - Save Status Indicator

    @ViewBuilder
    private var saveStatusView: some View {
        switch viewModel.saveStatus {
        case .idle:
            EmptyView()
        case .saving:
            HStack(spacing: RQSpacing.xxs) {
                ProgressView()
                    .scaleEffect(0.6)
                Text("Saving…")
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textTertiary)
            }
        case .saved:
            HStack(spacing: RQSpacing.xxs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                Text("Saved")
                    .font(RQTypography.caption)
            }
            .foregroundColor(RQColors.success)
        case .error(let message):
            HStack(spacing: RQSpacing.xxs) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10))
                Text(message)
                    .font(RQTypography.caption)
            }
            .foregroundColor(RQColors.error)
        }
    }

    // MARK: - Day Card

    private func workoutDayCard(_ day: WorkoutDay) -> some View {
        RQCard {
            HStack {
                VStack(alignment: .leading, spacing: RQSpacing.xs) {
                    Text(day.name)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)
                    if let desc = day.description, !desc.isEmpty {
                        Text(desc)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }
                    let exerciseCount = day.exercises?.count ?? 0
                    Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                        .font(RQTypography.footnote)
                        .foregroundColor(RQColors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(RQColors.textTertiary)
            }
        }
    }
}
