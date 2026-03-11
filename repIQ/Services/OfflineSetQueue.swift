import Foundation

/// Queues failed set saves for retry when network connectivity is restored.
/// Uses file-based persistence to survive app termination during a workout.
@Observable
final class OfflineSetQueue {
    static let shared = OfflineSetQueue()

    private(set) var pendingSets: [PendingSet] = []
    private(set) var isSyncing = false
    private(set) var lastSyncError: String?

    var hasPendingSets: Bool { !pendingSets.isEmpty }
    var pendingCount: Int { pendingSets.count }

    private let workoutService = WorkoutService()
    private let fileURL: URL

    private init() {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = documentsDir.appendingPathComponent("pending_sets.json")
        loadFromDisk()

        // Register for reconnect events
        NetworkMonitor.shared.onReconnect { [weak self] in
            await self?.syncPendingSets()
        }
    }

    // MARK: - Queue Management

    /// Enqueues a set that failed to save online.
    func enqueue(_ pendingSet: PendingSet) {
        pendingSets.append(pendingSet)
        saveToDisk()
    }

    /// Attempts to sync all pending sets with the server.
    func syncPendingSets() async {
        guard !pendingSets.isEmpty, !isSyncing else { return }
        guard NetworkMonitor.shared.isConnected else { return }

        isSyncing = true
        lastSyncError = nil

        var remaining: [PendingSet] = []

        for pendingSet in pendingSets {
            do {
                _ = try await workoutService.saveSet(
                    sessionId: pendingSet.sessionId,
                    exerciseId: pendingSet.exerciseId,
                    setNumber: pendingSet.setNumber,
                    setType: pendingSet.setType,
                    weight: pendingSet.weight,
                    reps: pendingSet.reps,
                    rpe: pendingSet.rpe
                )
                // Successfully saved — don't add to remaining
            } catch {
                // Still failing — keep in queue
                remaining.append(pendingSet)
                lastSyncError = error.localizedDescription
            }
        }

        pendingSets = remaining
        saveToDisk()
        isSyncing = false
    }

    /// Clears the entire queue (e.g. if workout is abandoned).
    func clearQueue() {
        pendingSets.removeAll()
        saveToDisk()
    }

    // MARK: - Persistence

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(pendingSets)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Best-effort persistence
        }
    }

    private func loadFromDisk() {
        do {
            let data = try Data(contentsOf: fileURL)
            pendingSets = try JSONDecoder().decode([PendingSet].self, from: data)
        } catch {
            pendingSets = []
        }
    }
}

/// A set that failed to persist online and is queued for retry.
struct PendingSet: Codable, Identifiable {
    let id: UUID
    let sessionId: UUID
    let exerciseId: UUID
    let setNumber: Int
    let setType: SetType
    let weight: Double
    let reps: Int
    let rpe: Double?
    let queuedAt: Date

    init(
        sessionId: UUID,
        exerciseId: UUID,
        setNumber: Int,
        setType: SetType,
        weight: Double,
        reps: Int,
        rpe: Double?
    ) {
        self.id = UUID()
        self.sessionId = sessionId
        self.exerciseId = exerciseId
        self.setNumber = setNumber
        self.setType = setType
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.queuedAt = Date()
    }
}
