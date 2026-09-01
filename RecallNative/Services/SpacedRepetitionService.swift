import Foundation

struct SchedulingResult {
    let state: String
    let step: Int
    let repetitions: Int
    let interval: Int
    let ease: Double
    let dueAt: Date
}

enum SpacedRepetitionService {
    static let day: TimeInterval = 86_400
    static let minEase = 1.3
    static let maxEase = 3.0
    static let relearnMin: TimeInterval = 60
    static let learningSteps: [TimeInterval] = [60, 10 * 60]
    private static let hardMultiplier = 1.2
    private static let easyBoost = 1.3

    static func schedule(state: String, step: Int, repetitions: Int, interval: Int, ease: Double, grade: Int, now: Date = .now) -> SchedulingResult {
        var state = state
        var step = step
        var reps = repetitions
        var interval = interval
        var ease = ease

        if grade == 0 {
            ease = max(minEase, ease - 0.2)
            if state == "review" {
                state = "relearning"; step = 0; reps = 0; interval = 0
                return .init(state: state, step: step, repetitions: reps, interval: interval, ease: ease, dueAt: now.addingTimeInterval(relearnMin))
            }
            state = "learning"; step = 0; reps = 0; interval = 0
            return .init(state: state, step: step, repetitions: reps, interval: interval, ease: ease, dueAt: now.addingTimeInterval(learningSteps[0]))
        }

        if state == "review" {
            reps += 1
            if grade == 1 {
                interval = max(1, Int((Double(max(interval, 1)) * hardMultiplier).rounded()))
            } else if grade == 2 {
                interval = graduatedInterval(reps: reps, interval: interval, ease: ease, easy: false)
                ease = min(maxEase, ease + 0.1)
            } else {
                interval = graduatedInterval(reps: reps, interval: interval, ease: ease, easy: true)
                ease = min(maxEase, ease + 0.15)
            }
            return .init(state: state, step: step, repetitions: reps, interval: interval, ease: ease, dueAt: now.addingTimeInterval(Double(interval) * day))
        }

        if grade == 1 {
            state = "learning"
            return .init(state: state, step: step, repetitions: reps, interval: interval, ease: ease, dueAt: now.addingTimeInterval(learningSteps[min(step, learningSteps.count - 1)]))
        }
        if grade == 3 || step + 1 >= learningSteps.count {
            state = "review"; step = 0; reps += 1
            interval = graduatedInterval(reps: reps, interval: interval, ease: ease, easy: grade == 3)
            ease = min(maxEase, ease + (grade == 3 ? 0.15 : 0.1))
            return .init(state: state, step: step, repetitions: reps, interval: interval, ease: ease, dueAt: now.addingTimeInterval(Double(interval) * day))
        }
        state = "learning"; step += 1
        return .init(state: state, step: step, repetitions: reps, interval: interval, ease: ease, dueAt: now.addingTimeInterval(learningSteps[step]))
    }

    static func isDue(dueAt: Date, now: Date = .now) -> Bool {
        dueAt <= now
    }

    static func daysUntilDue(dueAt: Date, now: Date = .now) -> Int {
        Int(ceil(dueAt.timeIntervalSince(now) / day))
    }

    private static func graduatedInterval(reps: Int, interval: Int, ease: Double, easy: Bool) -> Int {
        if reps == 1 { return 1 }
        if reps == 2 { return 6 }
        let base = Double(max(interval, 1))
        return max(1, Int((base * ease * (easy ? easyBoost : 1.0)).rounded()))
    }
}
