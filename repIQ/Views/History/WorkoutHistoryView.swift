import SwiftUI
import Supabase

struct WorkoutHistoryView: View {
    @State private var sessions: [WorkoutSession] = []
    @State private var isLoading = true
    @State private var progressViewModel = ProgressDashboardViewModel()

    private let workoutService = WorkoutService()

    var body: some View {
        Group {
            if isLoading && sessions.isEmpty {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sessions.isEmpty {
                ScrollView {
                    EmptyStateView(
                        icon: "clock.arrow.circlepath",
                        title: "No Workouts Yet",
                        message: "Complete your first workout to see your history here."
                    )
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: RQSpacing.md) {
                        ForEach(sessions) { session in
                            NavigationLink {
                                SessionDetailView(viewModel: progressViewModel, sessionId: session.id)
                            } label: {
                                sessionCard(session)
                            }
                        }
                    }
                    .padding(.horizontal, RQSpacing.screenHorizontal)
                    .padding(.top, RQSpacing.lg)
                    .padding(.bottom, RQSpacing.xxxl)
                }
            }
        }
        .background(RQColors.background)
        .navigationTitle("Workout History")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await loadSessions()
        }
        .refreshable {
            await loadSessions()
        }
    }

    private func loadSessions() async {
        isLoading = true
        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            sessions = try await workoutService.fetchAllSessions(userId: userId)
        } catch {
            // Silently handle
        }
        isLoading = false
    }

    private func sessionCard(_ session: WorkoutSession) -> some View {
        RQCard {
            HStack {
                VStack(alignment: .leading, spacing: RQSpacing.xs) {
                    // Date
                    Text(session.completedAt?.shortDisplay ?? session.startedAt.shortDisplay)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)

                    // Time ago
                    if let completedAt = session.completedAt {
                        Text(completedAt.relativeDisplay)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                    }

                    // Duration
                    if let duration = session.durationSeconds {
                        HStack(spacing: RQSpacing.sm) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundColor(RQColors.textTertiary)
                            Text("\(duration / 60) min")
                                .font(RQTypography.footnote)
                                .foregroundColor(RQColors.textSecondary)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(RQColors.textTertiary)
            }
        }
    }
}
