import SwiftUI

struct TemplateDetailView: View {
    let template: Template
    @State private var editorViewModel = TemplateEditorViewModel()
    @State private var showDeleteConfirmation = false
    @State private var showDayPicker = false
    var onDelete: (() -> Void)?

    @Environment(WorkoutCoordinator.self) private var workoutCoordinator

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.lg) {
                // Template Header
                RQCard {
                    VStack(alignment: .leading, spacing: RQSpacing.sm) {
                        Text(template.name)
                            .font(RQTypography.title2)
                            .foregroundColor(RQColors.textPrimary)
                        if let desc = template.description, !desc.isEmpty {
                            Text(desc)
                                .font(RQTypography.subheadline)
                                .foregroundColor(RQColors.textSecondary)
                        }
                        let dayCount = template.workoutDays?.count ?? 0
                        Text("\(dayCount) workout day\(dayCount == 1 ? "" : "s")")
                            .font(RQTypography.footnote)
                            .foregroundColor(RQColors.textTertiary)
                    }
                }

                // Start Workout Button
                RQButton(title: "Start Workout") {
                    startWorkout()
                }

                // Workout Days
                if let days = template.workoutDays, !days.isEmpty {
                    VStack(alignment: .leading, spacing: RQSpacing.md) {
                        Text("Workout Days")
                            .font(RQTypography.title3)
                            .foregroundColor(RQColors.textPrimary)

                        ForEach(days) { day in
                            dayCard(day)
                        }
                    }
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.top, RQSpacing.lg)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .background(RQColors.background)
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    NavigationLink {
                        TemplateEditorView(viewModel: editorViewModel)
                            .onAppear {
                                editorViewModel.loadTemplate(template)
                            }
                    } label: {
                        Label("Edit Template", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Template", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(RQColors.accent)
                }
            }
        }
        .sheet(isPresented: $showDayPicker) {
            WorkoutDayPickerView(template: template) { day in
                workoutCoordinator.startWorkout(template: template, day: day)
            }
        }
        .alert("Delete Template?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \"\(template.name)\" and all its workout days. This cannot be undone.")
        }
    }

    // MARK: - Start Workout

    private func startWorkout() {
        guard let days = template.workoutDays, !days.isEmpty else { return }
        showDayPicker = true
    }

    private func dayCard(_ day: WorkoutDay) -> some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.md) {
                Text(day.name)
                    .font(RQTypography.headline)
                    .foregroundColor(RQColors.textPrimary)

                if let exercises = day.exercises, !exercises.isEmpty {
                    ForEach(exercises) { dayExercise in
                        HStack(spacing: RQSpacing.md) {
                            // Mode indicator bar
                            RoundedRectangle(cornerRadius: 1)
                                .fill(dayExercise.trainingMode == .hypertrophy ? RQColors.hypertrophy : RQColors.strength)
                                .frame(width: 3, height: 32)

                            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                                Text(dayExercise.exercise?.name ?? "Unknown")
                                    .font(RQTypography.body)
                                    .foregroundColor(RQColors.textPrimary)
                                HStack(spacing: RQSpacing.sm) {
                                    Text("\(dayExercise.targetSets) sets")
                                        .font(RQTypography.caption)
                                        .foregroundColor(RQColors.textTertiary)
                                    Text("·")
                                        .foregroundColor(RQColors.textTertiary)
                                    Text(dayExercise.trainingMode.displayName)
                                        .font(RQTypography.caption)
                                        .foregroundColor(
                                            dayExercise.trainingMode == .hypertrophy
                                                ? RQColors.hypertrophy
                                                : RQColors.strength
                                        )
                                    let range = dayExercise.trainingMode.repRange
                                    Text("(\(range.lowerBound)-\(range.upperBound) reps)")
                                        .font(RQTypography.caption)
                                        .foregroundColor(RQColors.textTertiary)
                                }
                            }
                            Spacer()
                        }
                    }
                } else {
                    Text("No exercises")
                        .font(RQTypography.footnote)
                        .foregroundColor(RQColors.textTertiary)
                }
            }
        }
    }
}
