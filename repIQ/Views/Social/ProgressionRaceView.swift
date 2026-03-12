import SwiftUI
import Charts
import Supabase

/// Side-by-side chart comparing user vs friend E1RM progression on the same exercise.
struct ProgressionRaceView: View {
    @Bindable var viewModel: SocialViewModel
    let friend: Friendship

    @State private var selectedExerciseId: UUID?
    @State private var selectedExerciseName: String = ""
    @State private var raceData: ProgressionRaceData?
    @State private var isLoading = false
    @State private var commonExercises: [(id: UUID, name: String)] = []

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xl) {
                // Exercise picker
                exercisePicker

                // Race chart
                if let data = raceData {
                    raceChart(data)
                    statsComparison(data)
                } else if isLoading {
                    ProgressView()
                        .tint(RQColors.accent)
                        .padding(.top, RQSpacing.xxxl)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.vertical, RQSpacing.lg)
        }
        .background(RQColors.background)
        .navigationTitle("Progression Race")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadCommonExercises()
        }
    }

    // MARK: - Exercise Picker

    private var exercisePicker: some View {
        VStack(alignment: .leading, spacing: RQSpacing.sm) {
            Text("SELECT EXERCISE")
                .font(RQTypography.label)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(RQColors.textSecondary)

            if commonExercises.isEmpty && !isLoading {
                Text("No shared exercises found")
                    .font(RQTypography.footnote)
                    .foregroundColor(RQColors.textTertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: RQSpacing.sm) {
                        ForEach(commonExercises, id: \.id) { exercise in
                            Button {
                                selectedExerciseId = exercise.id
                                selectedExerciseName = exercise.name
                                Task { await loadRaceData(exerciseId: exercise.id, name: exercise.name) }
                            } label: {
                                Text(exercise.name)
                                    .font(RQTypography.caption)
                                    .fontWeight(selectedExerciseId == exercise.id ? .bold : .regular)
                                    .foregroundColor(selectedExerciseId == exercise.id ? RQColors.background : RQColors.textPrimary)
                                    .padding(.horizontal, RQSpacing.md)
                                    .padding(.vertical, RQSpacing.sm)
                                    .background(selectedExerciseId == exercise.id ? RQColors.accent : RQColors.surfacePrimary)
                                    .cornerRadius(RQRadius.large)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Race Chart

    private func raceChart(_ data: ProgressionRaceData) -> some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            Text(data.exerciseName.uppercased())
                .font(RQTypography.label)
                .tracking(1.5)
                .foregroundColor(RQColors.textSecondary)

            Text("Est. 1RM Progression")
                .font(RQTypography.headline)
                .foregroundColor(RQColors.textPrimary)

            RQCard {
                Chart {
                    // My data
                    ForEach(data.mySnapshots) { snapshot in
                        LineMark(
                            x: .value("Date", snapshot.date),
                            y: .value("E1RM", snapshot.estimated1RM),
                            series: .value("User", "You")
                        )
                        .foregroundStyle(RQColors.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Date", snapshot.date),
                            y: .value("E1RM", snapshot.estimated1RM)
                        )
                        .foregroundStyle(RQColors.accent)
                        .symbolSize(20)
                    }

                    // Friend data
                    ForEach(data.friendSnapshots) { snapshot in
                        LineMark(
                            x: .value("Date", snapshot.date),
                            y: .value("E1RM", snapshot.estimated1RM),
                            series: .value("User", friendName)
                        )
                        .foregroundStyle(RQColors.warning)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Date", snapshot.date),
                            y: .value("E1RM", snapshot.estimated1RM)
                        )
                        .foregroundStyle(RQColors.warning)
                        .symbolSize(20)
                    }
                }
                .chartForegroundStyleScale([
                    "You": RQColors.accent,
                    friendName: RQColors.warning
                ])
                .chartLegend(position: .bottom, alignment: .center)
                .chartYAxisLabel("lbs")
                .frame(height: 220)
            }
        }
    }

    // MARK: - Stats Comparison

    private func statsComparison(_ data: ProgressionRaceData) -> some View {
        VStack(spacing: RQSpacing.md) {
            Text("COMPARISON")
                .font(RQTypography.label)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(RQColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: RQSpacing.md) {
                // My stats
                RQCard {
                    VStack(spacing: RQSpacing.sm) {
                        Text("You")
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.accent)
                            .fontWeight(.bold)

                        Text(formatWeight(data.myCurrentE1RM))
                            .font(RQTypography.numbers)
                            .foregroundColor(RQColors.textPrimary)

                        Text("Current E1RM")
                            .font(RQTypography.label)
                            .foregroundColor(RQColors.textTertiary)

                        Divider().overlay(RQColors.surfaceTertiary)

                        HStack(spacing: RQSpacing.xxs) {
                            Image(systemName: data.myWeeklyGain >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10))
                            Text(String(format: "%+.1f lbs/wk", data.myWeeklyGain))
                                .font(RQTypography.numbersSmall)
                        }
                        .foregroundColor(data.myWeeklyGain >= 0 ? RQColors.success : RQColors.error)
                    }
                    .frame(maxWidth: .infinity)
                }

                // VS
                VStack {
                    Text("VS")
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textTertiary)
                }

                // Friend stats
                RQCard {
                    VStack(spacing: RQSpacing.sm) {
                        Text(friendName)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.warning)
                            .fontWeight(.bold)
                            .lineLimit(1)

                        Text(formatWeight(data.friendCurrentE1RM))
                            .font(RQTypography.numbers)
                            .foregroundColor(RQColors.textPrimary)

                        Text("Current E1RM")
                            .font(RQTypography.label)
                            .foregroundColor(RQColors.textTertiary)

                        Divider().overlay(RQColors.surfaceTertiary)

                        HStack(spacing: RQSpacing.xxs) {
                            Image(systemName: data.friendWeeklyGain >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10))
                            Text(String(format: "%+.1f lbs/wk", data.friendWeeklyGain))
                                .font(RQTypography.numbersSmall)
                        }
                        .foregroundColor(data.friendWeeklyGain >= 0 ? RQColors.success : RQColors.error)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Who's leading?
            let diff = data.myCurrentE1RM - data.friendCurrentE1RM
            if abs(diff) > 1 {
                RQCard {
                    HStack(spacing: RQSpacing.md) {
                        Image(systemName: diff > 0 ? "crown.fill" : "figure.strengthtraining.traditional")
                            .font(.system(size: 18))
                            .foregroundColor(diff > 0 ? RQColors.warning : RQColors.accent)

                        Text(diff > 0
                            ? "You're leading by \(formatWeight(abs(diff))) lbs!"
                            : "\(friendName) leads by \(formatWeight(abs(diff))) lbs. Time to catch up!"
                        )
                        .font(RQTypography.body)
                        .foregroundColor(RQColors.textPrimary)

                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: RQSpacing.lg) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(RQColors.textTertiary)
            Text("Select an exercise to compare")
                .font(RQTypography.headline)
                .foregroundColor(RQColors.textSecondary)
            Text("Pick a shared exercise to see your progression side by side.")
                .font(RQTypography.footnote)
                .foregroundColor(RQColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, RQSpacing.xxxl)
    }

    // MARK: - Helpers

    private var friendName: String {
        friend.friendProfile?.displayName ?? "Friend"
    }

    private func loadCommonExercises() async {
        guard let userId = viewModel.currentUserId else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch exercises performed by user
            struct ExRow: Decodable, Hashable {
                let exercise_id: UUID
            }

            let myExercises: [ExRow] = try await supabase.from("workout_sets")
                .select("exercise_id")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            let friendExercises: [ExRow] = try await supabase.from("workout_sets")
                .select("exercise_id")
                .eq("user_id", value: friend.friendId.uuidString)
                .execute()
                .value

            let myIds = Set(myExercises.map(\.exercise_id))
            let friendIds = Set(friendExercises.map(\.exercise_id))
            let sharedIds = myIds.intersection(friendIds)

            if !sharedIds.isEmpty {
                struct NameRow: Decodable {
                    let id: UUID
                    let name: String
                }

                let exercises: [NameRow] = try await supabase.from("exercises")
                    .select("id, name")
                    .in("id", values: Array(sharedIds).map(\.uuidString))
                    .order("name")
                    .execute()
                    .value

                commonExercises = exercises.map { (id: $0.id, name: $0.name) }

                // Auto-select first exercise
                if let first = commonExercises.first {
                    selectedExerciseId = first.id
                    selectedExerciseName = first.name
                    await loadRaceData(exerciseId: first.id, name: first.name)
                }
            }
        } catch {
            // Silently fail
        }
    }

    private func loadRaceData(exerciseId: UUID, name: String) async {
        guard let userId = viewModel.currentUserId else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let matchmakingService = MatchmakingService()
            raceData = try await matchmakingService.fetchProgressionRace(
                userId: userId,
                friendId: friend.friendId,
                exerciseId: exerciseId,
                exerciseName: name
            )
        } catch {
            // Silently fail
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }
}
