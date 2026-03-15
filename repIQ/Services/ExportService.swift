import Foundation
import Supabase
import UIKit

struct ExportService: Sendable {

    private let workoutService = WorkoutService()

    // MARK: - CSV Export

    func generateCSV(userId: UUID) async throws -> String {
        let sessions = try await workoutService.fetchAllSessions(userId: userId)
        guard !sessions.isEmpty else { return "No workout data to export." }

        // Fetch all sets for all sessions
        let sessionIds = sessions.map(\.id)
        let allSets = try await fetchAllSets(sessionIds: sessionIds)

        // Fetch exercise names
        let exerciseIds = Array(Set(allSets.map(\.exerciseId)))
        let exercises = try await fetchExerciseNames(ids: exerciseIds)

        var csv = "Date,Session Duration (min),Exercise,Set Number,Set Type,Weight,Reps,RPE,Volume\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for session in sessions {
            let sessionSets = allSets.filter { $0.sessionId == session.id }
                .sorted { $0.setNumber < $1.setNumber }
            let date = dateFormatter.string(from: session.completedAt ?? session.startedAt)
            let duration = (session.durationSeconds ?? 0) / 60

            for set in sessionSets {
                let exerciseName = exercises[set.exerciseId] ?? "Unknown"
                let rpeStr = set.rpe.map { String(format: "%.1f", $0) } ?? ""
                let volume = set.weight * Double(set.reps)
                csv += "\(date),\(duration),\"\(exerciseName)\",\(set.setNumber),\(set.setType.rawValue),\(set.weight),\(set.reps),\(rpeStr),\(volume)\n"
            }
        }

        return csv
    }

    // MARK: - PDF Export

    func generatePDFData(userId: UUID) async throws -> Data {
        let sessions = try await workoutService.fetchAllSessions(userId: userId)
        let sessionIds = sessions.map(\.id)
        let allSets = try await fetchAllSets(sessionIds: sessionIds)
        let exerciseIds = Array(Set(allSets.map(\.exerciseId)))
        let exercises = try await fetchExerciseNames(ids: exerciseIds)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        // Build PDF using UIKit
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), nil)

        var currentY: CGFloat = margin
        var pageStarted = false

        func startNewPage() {
            UIGraphicsBeginPDFPage()
            currentY = margin
            pageStarted = true
        }

        func checkPageBreak(needed: CGFloat) {
            if !pageStarted || currentY + needed > pageHeight - margin {
                startNewPage()
            }
        }

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.darkGray
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.black
        ]
        let captionAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.gray
        ]

        // Title page
        startNewPage()
        "repIQ Training Log".draw(at: CGPoint(x: margin, y: currentY), withAttributes: titleAttrs)
        currentY += 36
        "Exported \(dateFormatter.string(from: Date()))".draw(at: CGPoint(x: margin, y: currentY), withAttributes: captionAttrs)
        currentY += 14
        "\(sessions.count) sessions  |  \(allSets.count) sets".draw(at: CGPoint(x: margin, y: currentY), withAttributes: captionAttrs)
        currentY += 30

        // Sessions
        for session in sessions.prefix(100) {
            checkPageBreak(needed: 80)

            let date = dateFormatter.string(from: session.completedAt ?? session.startedAt)
            let duration = (session.durationSeconds ?? 0) / 60

            // Session header
            "\(date)  (\(duration) min)".draw(at: CGPoint(x: margin, y: currentY), withAttributes: headerAttrs)
            currentY += 20

            let sessionSets = allSets.filter { $0.sessionId == session.id }
            let grouped = Dictionary(grouping: sessionSets) { $0.exerciseId }

            for (exerciseId, sets) in grouped.sorted(by: { $0.value.first?.setNumber ?? 0 < $1.value.first?.setNumber ?? 0 }) {
                checkPageBreak(needed: 16)
                let name = exercises[exerciseId] ?? "Unknown"
                let setsDesc = sets.map { "\($0.weight)x\($0.reps)" }.joined(separator: "  ")
                "  \(name): \(setsDesc)".draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttrs)
                currentY += 16
            }

            currentY += 10
        }

        UIGraphicsEndPDFContext()
        return pdfData as Data
    }

    // MARK: - Helpers

    private func fetchAllSets(sessionIds: [UUID]) async throws -> [WorkoutSet] {
        guard !sessionIds.isEmpty else { return [] }
        // Fetch in batches to avoid URL length limits
        var allSets: [WorkoutSet] = []
        let batchSize = 50
        for i in stride(from: 0, to: sessionIds.count, by: batchSize) {
            let batch = Array(sessionIds[i..<min(i + batchSize, sessionIds.count)])
            let sets: [WorkoutSet] = try await supabase.from("workout_sets")
                .select()
                .in("session_id", values: batch.map(\.uuidString))
                .order("set_number")
                .execute()
                .value
            allSets.append(contentsOf: sets)
        }
        return allSets
    }

    private func fetchExerciseNames(ids: [UUID]) async throws -> [UUID: String] {
        guard !ids.isEmpty else { return [:] }
        let exercises: [Exercise] = try await supabase.from("exercises")
            .select("id, name")
            .in("id", values: ids.map(\.uuidString))
            .execute()
            .value
        return Dictionary(exercises.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
    }
}
