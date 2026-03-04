import SwiftUI

struct TemplateEditorView: View {
    @Bindable var viewModel: TemplateEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddDay = false
    @State private var newDayName = ""
    @State private var newDayDescription = ""

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xl) {
                // Template Info
                RQCard {
                    VStack(alignment: .leading, spacing: RQSpacing.lg) {
                        Text("Template Info")
                            .font(RQTypography.headline)
                            .foregroundColor(RQColors.textPrimary)

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

                // Save button (creates template so we can add days)
                if viewModel.workoutDays.isEmpty && !viewModel.isSaved {
                    RQButton(
                        title: "Save & Add Workout Days",
                        isLoading: viewModel.isLoading,
                        isDisabled: !viewModel.isFormValid
                    ) {
                        Task {
                            await viewModel.save()
                        }
                    }
                }

                // Workout Days
                if viewModel.isSaved || !viewModel.workoutDays.isEmpty {
                    VStack(alignment: .leading, spacing: RQSpacing.md) {
                        HStack {
                            Text("Workout Days")
                                .font(RQTypography.title3)
                                .foregroundColor(RQColors.textPrimary)
                            Spacer()
                            Button {
                                showAddDay = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(RQColors.accent)
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
                                NavigationLink {
                                    WorkoutDayEditorView(
                                        day: day,
                                        viewModel: viewModel
                                    )
                                } label: {
                                    workoutDayCard(day)
                                }
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
        .navigationTitle(viewModel.workoutDays.isEmpty ? "New Template" : viewModel.templateName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if viewModel.isSaved || !viewModel.workoutDays.isEmpty {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.save()
                            dismiss()
                        }
                    }
                    .foregroundColor(RQColors.accent)
                }
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
    }

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
