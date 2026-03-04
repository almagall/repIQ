import SwiftUI

struct WorkoutDayPickerView: View {
    let template: Template
    let onDaySelected: (WorkoutDay) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RQSpacing.md) {
                    // Template info
                    VStack(spacing: RQSpacing.xs) {
                        Text(template.name)
                            .font(RQTypography.title3)
                            .foregroundColor(RQColors.textPrimary)

                        Text("Select a workout day")
                            .font(RQTypography.subheadline)
                            .foregroundColor(RQColors.textSecondary)
                    }
                    .padding(.bottom, RQSpacing.md)

                    // Day cards
                    if let days = template.workoutDays {
                        ForEach(days.sorted(by: { $0.sortOrder < $1.sortOrder })) { day in
                            Button {
                                onDaySelected(day)
                                dismiss()
                            } label: {
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
            .navigationTitle("Choose Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(RQColors.textSecondary)
                }
            }
        }
    }

    private func dayCard(_ day: WorkoutDay) -> some View {
        RQCard {
            HStack {
                VStack(alignment: .leading, spacing: RQSpacing.xs) {
                    Text(day.name)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)

                    if let exercises = day.exercises {
                        let exerciseNames = exercises
                            .sorted(by: { $0.sortOrder < $1.sortOrder })
                            .compactMap { $0.exercise?.name }
                            .prefix(3)
                            .joined(separator: ", ")
                        let remaining = exercises.count - min(exercises.count, 3)

                        Text(exerciseNames + (remaining > 0 ? " +\(remaining) more" : ""))
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                            .lineLimit(1)
                    }

                    Text("\(day.exercises?.count ?? 0) exercises")
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(RQColors.textTertiary)
            }
        }
    }
}
