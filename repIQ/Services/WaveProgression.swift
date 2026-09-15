import Foundation

/// Wendler's 5/3/1, as a pure function of (training max, wave index). No
/// network, no session history: the wave decides every set, and performance
/// matters only at the cycle boundary, where `cycleVerdict` moves the TM.
///
/// The book's rules are the baseline (percentages, +5/+10 per cycle, a 10%
/// reset after missed reps). The one addition is at the boundary: the AMRAP
/// sets give an e1RM at 1-5 reps, exactly where the estimate is trustworthy,
/// so a TM that has drifted above or well below real strength is caught
/// before it stalls the lifter. Those deviations are applied and then offered
/// back with the book's alternative — never silent, never mid-cycle.
enum WaveProgression {

    struct Wave: Sendable {
        let name: String
        let steps: [(percent: Double, reps: Int)]
        let isDeload: Bool
    }

    static let waves: [Wave] = [
        Wave(name: "5s", steps: [(0.65, 5), (0.75, 5), (0.85, 5)], isDeload: false),
        Wave(name: "3s", steps: [(0.70, 3), (0.80, 3), (0.90, 3)], isDeload: false),
        Wave(name: "5/3/1", steps: [(0.75, 5), (0.85, 3), (0.95, 1)], isDeload: false),
        Wave(name: "Deload", steps: [(0.40, 5), (0.50, 5), (0.60, 5)], isDeload: true),
    ]

    static let setsPerWave = 3

    static func wave(at index: Int) -> Wave {
        waves[((index % waves.count) + waves.count) % waves.count]
    }

    struct SetPrescription: Sendable {
        let weight: Double
        let reps: Int
        let percent: Double
        /// The last set of a non-deload wave: the prescribed reps are a minimum.
        let isAMRAP: Bool
    }

    // MARK: - Prescription

    static func prescribe(trainingMax: Double, waveIndex: Int, equipment: String) -> [SetPrescription] {
        let w = wave(at: waveIndex)
        let increment = ProgressionService.weightIncrement(for: equipment)
        return w.steps.enumerated().map { i, step in
            SetPrescription(
                weight: round(trainingMax * step.percent, to: increment),
                reps: step.reps,
                percent: step.percent,
                isAMRAP: !w.isDeload && i == w.steps.count - 1
            )
        }
    }

    /// The book's warm-up ramp. Guidance only — warm-ups are never prefilled.
    static func warmups(trainingMax: Double, equipment: String) -> [SetPrescription] {
        let increment = ProgressionService.weightIncrement(for: equipment)
        return [(0.40, 5), (0.50, 5), (0.60, 3)].map { pct, reps in
            SetPrescription(weight: round(trainingMax * pct, to: increment), reps: reps, percent: pct, isAMRAP: false)
        }
    }

    /// TM = 90% of a true or estimated 1RM, on the equipment's increment.
    static func trainingMax(fromOneRepMax oneRM: Double, equipment: String) -> Double {
        round(oneRM * 0.90, to: ProgressionService.weightIncrement(for: equipment))
    }

    /// The book bumps squat and deadlift by 10 lb per cycle and press and bench
    /// by 5. The library files the deadlift under `back`, so lower-body is
    /// muscle group *or* name.
    static func cycleBump(exerciseName: String, muscleGroup: String, equipment: String) -> Double {
        let increment = ProgressionService.weightIncrement(for: equipment)
        let lowerBody: Set<String> = ["quads", "hamstrings", "glutes", "legs"]
        let isLower = lowerBody.contains(muscleGroup.lowercased())
            || exerciseName.lowercased().contains("deadlift")
        return isLower ? increment * 2 : increment
    }

    // MARK: - Cycle-end verdict

    struct AMRAPResult: Sendable {
        let waveIndex: Int
        let weight: Double
        let reps: Int

        var minimumReps: Int { wave(at: waveIndex).steps.last?.reps ?? 1 }
        var missed: Bool { reps < minimumReps }
        var estimated1RM: Double { reps > 0 ? weight * (1.0 + Double(reps) / 30.0) : weight }
    }

    enum Verdict: Sendable {
        case bump(to: Double)
        case hold(at: Double)
        case reset(to: Double)
        case recalibrate(to: Double)

        var newTrainingMax: Double {
            switch self {
            case .bump(let v), .hold(let v), .reset(let v), .recalibrate(let v): return v
            }
        }

        var source: TrainingMax.Source {
            switch self {
            case .bump: return .bump
            case .hold: return .hold
            case .reset: return .reset
            case .recalibrate: return .recalibrated
            }
        }

        var decision: ProgressionDecision {
            switch self {
            case .bump, .recalibrate: return .increaseWeight
            case .hold: return .maintain
            case .reset: return .deload
            }
        }
    }

    /// Thresholds, as TM ÷ best e1RM across the cycle's AMRAP sets:
    /// - any AMRAP below its minimum → reset 10% (the book's rule, no override)
    /// - e1RM below the TM (only the minimums came) → hold, the stall is next
    /// - e1RM above TM ÷ 0.85 (≈12+ on the 5s day) → recalibrate to 90% of e1RM
    /// - otherwise the standard bump
    static func cycleVerdict(
        trainingMax tm: Double,
        amrapSets: [AMRAPResult],
        bump: Double,
        equipment: String
    ) -> Verdict {
        let increment = ProgressionService.weightIncrement(for: equipment)
        if amrapSets.contains(where: \.missed) {
            let reset = round(tm * 0.90, to: increment)
            return .reset(to: min(reset, tm - increment))
        }
        guard let best = amrapSets.map(\.estimated1RM).max(), best > 0 else {
            return .bump(to: tm + bump)
        }
        if best < tm {
            return .hold(at: tm)
        }
        if best > tm / 0.85 {
            let recalibrated = round(best * 0.90, to: increment)
            if recalibrated > tm + bump {
                return .recalibrate(to: recalibrated)
            }
        }
        return .bump(to: tm + bump)
    }

    // MARK: - Journal row

    /// The `progression_log` row written when a wave session completes: the
    /// prescription for the *next* session (its top set) plus the wave to run.
    /// Mid-cycle rows carry `.wave`; the cycle-end row carries the verdict.
    static func nextTarget(
        exerciseId: UUID,
        completedWaveIndex: Int,
        trainingMax: Double,
        nextTrainingMax: Double,
        amrap: AMRAPResult?,
        verdict: Verdict?,
        equipment: String
    ) -> ProgressionTarget {
        let nextIndex = (completedWaveIndex + 1) % waves.count
        let next = wave(at: nextIndex)
        let top = prescribe(trainingMax: nextTrainingMax, waveIndex: nextIndex, equipment: equipment).last!
        let reps = top.reps

        let reasoning: String
        let decision: ProgressionDecision
        if let verdict {
            decision = verdict.decision
            let tmText = format(nextTrainingMax)
            switch verdict {
            case .bump:
                reasoning = "Cycle complete. Training max up to \(tmText) — 5s week next: \(format(top.weight)) × \(reps)+."
            case .hold:
                reasoning = "Cycle complete. Your + sets only reached the minimums, so the training max holds at \(tmText) instead of bumping — a bump now usually stalls next cycle."
            case .reset:
                reasoning = "You missed the minimum on a + set this cycle. Training max reset to \(tmText) (−10%), as the program prescribes."
            case .recalibrate:
                reasoning = "Your + sets estimate a max well above the training max. Recalibrated to \(tmText) (90% of that) instead of the standard bump."
            }
        } else {
            decision = .wave
            let stepText = next.steps.map { "\(format(round(nextTrainingMax * $0.percent, to: ProgressionService.weightIncrement(for: equipment)))) × \($0.reps)" }
            let last = next.isDeload ? stepText.last! : stepText.last! + "+"
            reasoning = "\(next.name) week next: " + (stepText.dropLast() + [last]).joined(separator: ", ") + ". Training max stays at \(format(trainingMax)) until the cycle ends."
        }

        return ProgressionTarget(
            exerciseId: exerciseId,
            trainingMode: .strength,
            targetWeight: top.weight,
            targetRepsLow: reps,
            targetRepsHigh: reps,
            targetRPE: TrainingMode.strength.targetRPE,
            decision: decision,
            reasoning: reasoning,
            previousWeight: amrap?.weight,
            previousReps: amrap?.reps,
            previousRPE: nil,
            estimatedOneRM: amrap?.estimated1RM,
            programWeek: nextIndex
        )
    }

    // MARK: - Helpers

    /// Nearest increment, the way 5/3/1 tables are written (the engine rounds
    /// down; a 202.5 TM reading as 200 vs 205 is a coin flip, and nearest keeps
    /// the printed percentages closest to the truth).
    static func round(_ weight: Double, to increment: Double) -> Double {
        guard increment > 0 else { return weight }
        return (weight / increment).rounded() * increment
    }

    static func format(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(weight)) : String(format: "%.1f", weight)
    }
}
