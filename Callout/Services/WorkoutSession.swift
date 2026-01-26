import Foundation
import Combine

/// Manages the active workout session state
/// Handles exercise context, set logging, and "same" command resolution
@Observable
final class WorkoutSession {
    
    // MARK: - Singleton
    
    static let shared = WorkoutSession()
    
    // MARK: - State
    
    enum State: Equatable {
        case idle
        case active
        case finished
    }
    
    private(set) var state: State = .idle
    private(set) var currentWorkout: Workout?
    private(set) var currentExercise: Exercise?
    private(set) var currentExerciseSession: ExerciseSession?
    private(set) var lastLoggedSet: WorkSet?
    private(set) var restStartTime: Date?
    private(set) var ghostSet: GhostSet?
    
    // MARK: - Computed
    
    var currentSetNumber: Int {
        (currentExerciseSession?.sets.count ?? 0) + 1
    }
    
    var restElapsed: TimeInterval {
        guard let start = restStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }
    
    var isActive: Bool {
        state == .active
    }
    
    // MARK: - Dependencies
    
    private let persistence = PersistenceManager.shared
    private let parser = GrammarParser.shared
    private let haptics = HapticManager.shared
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Session Lifecycle
    
    /// Start a new workout session
    func startSession() {
        guard state == .idle else { return }
        
        currentWorkout = Workout()
        state = .active
        restStartTime = Date()
        
        haptics.tap()
    }
    
    /// End the current workout session
    func endSession() {
        guard state == .active, var workout = currentWorkout else { return }
        
        // Finalize current exercise if any
        finalizeCurrentExercise()
        
        workout.endedAt = Date()
        currentWorkout = workout
        
        // Save to persistence
        do {
            try persistence.save(workout: workout)
        } catch {
            print("Failed to save workout: \(error)")
        }
        
        state = .finished
        haptics.workoutCompleted()
    }
    
    /// Reset session to idle (after viewing receipt, etc.)
    func reset() {
        state = .idle
        currentWorkout = nil
        currentExercise = nil
        currentExerciseSession = nil
        lastLoggedSet = nil
        restStartTime = nil
        ghostSet = nil
    }
    
    // MARK: - Voice Command Processing
    
    /// Process a voice transcription and execute the appropriate action
    @discardableResult
    func processVoiceInput(_ transcription: String) -> ProcessResult {
        // Auto-start session if needed
        if state == .idle {
            startSession()
        }
        
        let parseResult = parser.parse(transcription)
        
        switch parseResult {
        case .exerciseChanged(let exerciseName):
            setExercise(named: exerciseName)
            return .exerciseChanged(exerciseName)
            
        case .setLogged(let data):
            let set = logSet(
                weight: data.weight,
                reps: data.reps,
                rpe: data.rpe,
                isWarmup: data.isWarmup
            )
            return .setLogged(set)
            
        case .warmup(let data):
            let set = logSet(
                weight: data.weight,
                reps: data.reps,
                rpe: data.rpe,
                isWarmup: true
            )
            return .setLogged(set)
            
        case .sameAgain:
            if let set = logSameAgain() {
                return .setLogged(set)
            } else {
                return .error("No previous set to repeat")
            }
            
        case .addFlag(let flag):
            if addFlagToLastSet(flag) {
                return .flagAdded(flag)
            } else {
                return .error("No set to add flag to")
            }
            
        case .unknown(let text):
            return .notUnderstood(text)
            
        case .empty:
            return .empty
        }
    }
    
    enum ProcessResult {
        case exerciseChanged(String)
        case setLogged(WorkSet)
        case flagAdded(SetFlag)
        case notUnderstood(String)
        case error(String)
        case empty
    }
    
    // MARK: - Exercise Management
    
    /// Set the current exercise context
    func setExercise(named name: String) {
        // Finalize previous exercise if different
        if let current = currentExercise, current.name != name {
            finalizeCurrentExercise()
        }
        
        // Create or find exercise
        let exercise = Exercise(name: name)
        currentExercise = exercise
        currentExerciseSession = ExerciseSession(exercise: exercise)
        
        // Load ghost data
        ghostSet = persistence.getLastPerformance(for: name)
        
        restStartTime = Date()
        haptics.exerciseChanged()
    }
    
    private func finalizeCurrentExercise() {
        guard let session = currentExerciseSession,
              !session.sets.isEmpty else { return }
        
        currentWorkout?.exercises.append(session)
        currentExerciseSession = nil
    }
    
    // MARK: - Set Logging
    
    /// Log a set with the given parameters
    @discardableResult
    func logSet(
        weight: Double,
        reps: Int,
        rpe: Double? = nil,
        isWarmup: Bool = false,
        flags: [SetFlag] = []
    ) -> WorkSet {
        // Auto-create exercise session if needed
        if currentExerciseSession == nil {
            let exercise = currentExercise ?? Exercise(name: "Unknown Exercise")
            currentExercise = exercise
            currentExerciseSession = ExerciseSession(exercise: exercise)
        }
        
        let set = WorkSet(
            weight: weight,
            reps: reps,
            rpe: rpe,
            isWarmup: isWarmup,
            flags: flags
        )
        
        currentExerciseSession?.sets.append(set)
        lastLoggedSet = set
        restStartTime = Date()
        
        haptics.setLogged()
        
        return set
    }
    
    /// Log the same set as last time
    @discardableResult
    func logSameAgain() -> WorkSet? {
        guard let last = lastLoggedSet else { return nil }
        
        return logSet(
            weight: last.weight,
            reps: last.reps,
            rpe: last.rpe,
            isWarmup: last.isWarmup
        )
    }
    
    /// Add a flag to the most recent set
    @discardableResult
    func addFlagToLastSet(_ flag: SetFlag) -> Bool {
        guard var sets = currentExerciseSession?.sets,
              !sets.isEmpty else { return false }
        
        var lastSet = sets.removeLast()
        if !lastSet.flags.contains(flag) {
            lastSet.flags.append(flag)
        }
        sets.append(lastSet)
        currentExerciseSession?.sets = sets
        lastLoggedSet = lastSet
        
        haptics.tap()
        return true
    }
    
    // MARK: - Warmup Detection (Automatic)
    
    /// Check if a weight is likely a warmup based on history
    func isLikelyWarmup(weight: Double, for exercise: String) -> Bool {
        guard let ghost = persistence.getLastPerformance(for: exercise) else {
            return false
        }
        
        // If weight is less than 60% of last working weight, probably warmup
        return weight < ghost.weight * 0.6
    }
}

// MARK: - Session Auto-Close

extension WorkoutSession {
    /// Check for inactivity and auto-close if needed
    func checkInactivityTimeout(threshold: TimeInterval = 30 * 60) -> Bool {
        guard state == .active,
              let rest = restStartTime else { return false }
        
        return Date().timeIntervalSince(rest) > threshold
    }
}
