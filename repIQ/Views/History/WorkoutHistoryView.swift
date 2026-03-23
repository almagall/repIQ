import SwiftUI
import Supabase

struct WorkoutHistoryView: View {
    @State private var sessions: [WorkoutSession] = []
    @State private var isLoading = true
    @State private var progressViewModel = ProgressDashboardViewModel()
    @State private var isExportingCSV = false
    @State private var csvData: String?
    @State private var showCSVShare = false
    @State private var exportError: String?

    private let workoutService = WorkoutService()
    private let exportService = ExportService()

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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await exportCSV() }
                } label: {
                    if isExportingCSV {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(RQColors.accent)
                    }
                }
                .disabled(isExportingCSV || sessions.isEmpty)
            }
        }
        .sheet(isPresented: $showCSVShare) {
            if let csvData {
                let url = saveToTemp(data: Data(csvData.utf8), filename: "repiq-export.csv")
                ShareSheet(items: [url])
            }
        }
    }

    private func exportCSV() async {
        isExportingCSV = true
        exportError = nil
        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            csvData = try await exportService.generateCSV(userId: userId)
            showCSVShare = true
        } catch {
            exportError = "Failed to generate CSV."
        }
        isExportingCSV = false
    }

    private func saveToTemp(data: Data, filename: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return url
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
