import Foundation
import Combine

// MARK: - WorkoutSession

/// Manages the active workout session state
/// Handles exercise context, set logging, and "same" command resolution
@Observable
final class WorkoutSession {
    
    // MARK: - Singleton
    
    static let shared = WorkoutSession()
    
    // MARK: - Types
    
    /// Session state machine
    enum State: Equatable {
        case idle
        case active
        case finished
    }
    
    // MARK: - Published State
    
    private(set) var state: State = .idle
    var currentWorkout: Workout?
    private(set) var currentExercise: Exercise?
    private var _currentExerciseSession: ExerciseSession?
    private(set) var lastLoggedSet: WorkSet?
    private(set) var restStartTime: Date?
    private(set) var ghostSet: GhostSet?
    
    // MARK: - Computed Properties
    
    /// Current set number (1-indexed)
    var currentSetNumber: Int {
        (_currentExerciseSession?.sets.count ?? 0) + 1
    }
    
    /// Time elapsed since last action (for rest timer)
    var restElapsed: TimeInterval {
        guard let start = restStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }
    
    /// Whether a workout session is currently active
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
        guard state == .idle || state == .finished else { return }
        
        currentWorkout = Workout()
        _currentExerciseSession = nil
        currentExercise = nil
        lastLoggedSet = nil
        ghostSet = nil
        state = .active
        restStartTime = Date()
        
        haptics.tap()
        #if DEBUG
        print("[WorkoutSession] Started new session")
        #endif
    }
    
    /// End the current workout session
    func endSession() {
        guard state == .active else { return }
        guard var workout = currentWorkout else { return }
        
        // Finalize current exercise if any
        finalizeCurrentExercise()
        
        workout.endedAt = Date()
        workout.exercises = currentWorkout?.exercises ?? []
        currentWorkout = workout
        
        // Save to persistence (on background queue for performance)
        let workoutToSave = workout
        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                try self?.persistence.save(workout: workoutToSave)
                #if DEBUG
                print("[WorkoutSession] Saved workout with \(workoutToSave.exercises.count) exercises")
                #endif
            } catch {
                #if DEBUG
                print("[WorkoutSession] Failed to save workout: \(error)")
                #endif
            }
        }
        
        state = .finished
        haptics.workoutCompleted()
    }
    
    /// Reset session to idle (after viewing receipt, etc.)
    func reset() {
        state = .idle
        currentWorkout = nil
        currentExercise = nil
        _currentExerciseSession = nil
        lastLoggedSet = nil
        restStartTime = nil
        ghostSet = nil
        #if DEBUG
        print("[WorkoutSession] Reset")
        #endif
    }
    
    // MARK: - Voice Command Processing
    
    /// Process a voice transcription and execute the appropriate action
    @discardableResult
    func processVoiceInput(_ transcription: String) -> ProcessResult {
        // Auto-start session if needed
        if state == .idle || state == .finished {
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
        _currentExerciseSession = ExerciseSession(exercise: exercise)
        
        // Load ghost data
        ghostSet = persistence.getLastPerformance(for: name)
        
        restStartTime = Date()
        haptics.exerciseChanged()
        #if DEBUG
        print("[WorkoutSession] Set exercise: \(name)")
        #endif
    }
    
    private func finalizeCurrentExercise() {
        guard let session = _currentExerciseSession else { return }
        guard !session.sets.isEmpty else { return }
        
        if currentWorkout == nil {
            currentWorkout = Workout()
        }
        currentWorkout?.exercises.append(session)
        #if DEBUG
        print("[WorkoutSession] Finalized exercise: \(session.exercise.name) with \(session.sets.count) sets")
        #endif
        _currentExerciseSession = nil
    }
    
    // MARK: - Set Logging
    
    /// Log a set with the given parameters
    /// - Parameters:
    ///   - weight: Weight lifted
    ///   - reps: Number of repetitions
    ///   - rpe: Rate of perceived exertion (optional, 1-10)
    ///   - isWarmup: Whether this is a warmup set
    ///   - flags: Any flags to attach (pain, failure, etc.)
    /// - Returns: The logged WorkSet
    @discardableResult
    func logSet(
        weight: Double,
        reps: Int,
        rpe: Double? = nil,
        isWarmup: Bool = false,
        flags: [SetFlag] = []
    ) -> WorkSet {
        // Auto-start session if needed
        if state != .active {
            startSession()
        }
        
        // Auto-create exercise session if needed
        if _currentExerciseSession == nil {
            let exercise = currentExercise ?? Exercise(name: "Unknown Exercise")
            currentExercise = exercise
            _currentExerciseSession = ExerciseSession(exercise: exercise)
        }
        
        let set = WorkSet(
            weight: weight,
            reps: reps,
            rpe: rpe,
            isWarmup: isWarmup,
            flags: flags
        )
        
        // Safely append to the session
        _currentExerciseSession?.sets.append(set)
        lastLoggedSet = set
        restStartTime = Date()
        
        haptics.setLogged()
        #if DEBUG
        let setCount = _currentExerciseSession?.sets.count ?? 0
        print("[WorkoutSession] Logged set: \(weight) x \(reps) - Total sets now: \(setCount)")
        #endif
        
        return set
    }
    
    /// Log the same set as last time (repeat previous weight/reps)
    /// - Returns: The logged WorkSet, or nil if no previous set exists
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
    /// - Parameter flag: The flag to add (pain, failure, etc.)
    /// - Returns: Whether the flag was successfully added
    @discardableResult
    func addFlagToLastSet(_ flag: SetFlag) -> Bool {
        guard var session = _currentExerciseSession,
              !session.sets.isEmpty else { return false }
        
        let lastIndex = session.sets.count - 1
        if !session.sets[lastIndex].flags.contains(flag) {
            session.sets[lastIndex].flags.append(flag)
            _currentExerciseSession = session
        }
        lastLoggedSet = _currentExerciseSession?.sets[lastIndex]
        
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
