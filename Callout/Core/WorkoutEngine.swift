//
//  WorkoutEngine.swift
//  Callout
//
//  Core workout state management and command processing
//

import Foundation
import SwiftData
import Observation

/// The core engine that manages workout state and processes voice commands
@Observable
@MainActor
final class WorkoutEngine {
    // MARK: - State
    
    /// Current exercise context
    private(set) var currentExercise: String?
    
    /// Last logged set
    private(set) var lastSet: SetCard?
    
    /// Whether a workout is currently active
    private(set) var isWorkoutActive: Bool = false
    
    /// Current session ID
    private(set) var currentSessionId: UUID?
    
    /// Time since last set (for rest timer)
    var restTime: TimeInterval {
        guard let lastSet = lastSet else { return 0 }
        return Date().timeIntervalSince(lastSet.timestamp)
    }
    
    /// Formatted rest time string
    var restTimeFormatted: String {
        let minutes = Int(restTime) / 60
        let seconds = Int(restTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Dependencies
    
    private let modelContext: ModelContext
    private let profile: UserProfile
    
    // MARK: - Callbacks
    
    /// Called when a set is logged
    var onSetLogged: ((SetCard) -> Void)?
    
    /// Called when exercise context changes
    var onExerciseChanged: ((String) -> Void)?
    
    /// Called when an error occurs
    var onError: ((WorkoutError) -> Void)?
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, profile: UserProfile) {
        self.modelContext = modelContext
        self.profile = profile
        
        // Load last session state if recent
        loadRecentState()
    }
    
    // MARK: - Command Processing
    
    /// Process a parsed voice command
    func process(_ command: ParsedCommand) {
        switch command {
        case .logSet(let exercise, let weight, let reps, let modifiers):
            logSet(
                exercise: exercise,
                weight: weight,
                reps: reps,
                modifiers: modifiers
            )
            
        case .sameAgain:
            logSameAgain()
            
        case .weightDelta(let delta):
            logWithWeightDelta(delta)
            
        case .repChange(let reps):
            logWithRepChange(reps)
            
        case .exerciseChange(let exercise):
            changeExercise(to: exercise)
            
        case .modifier(let modifier):
            applyModifier(modifier)
            
        case .endWorkout:
            endWorkout()
            
        case .unknown(let transcript):
            handleUnknown(transcript)
        }
    }
    
    // MARK: - Set Logging
    
    /// Log a new set
    private func logSet(
        exercise: String?,
        weight: Double,
        reps: Int,
        modifiers: [SetModifier]
    ) {
        // Resolve exercise
        let resolvedExercise: String
        if let exercise = exercise {
            resolvedExercise = profile.resolveExercise(exercise)
            currentExercise = resolvedExercise
        } else if let current = currentExercise {
            resolvedExercise = current
        } else {
            onError?(.noExerciseContext)
            return
        }
        
        // Create set
        let set = SetCard(
            exercise: resolvedExercise,
            weight: weight,
            weightUnit: profile.preferredUnit,
            reps: reps,
            sessionId: ensureSession()
        )
        
        // Apply modifiers
        for modifier in modifiers {
            applyModifier(modifier, to: set)
        }
        
        // Save
        modelContext.insert(set)
        saveContext()
        
        // Update state
        lastSet = set
        isWorkoutActive = true
        
        // Callback
        onSetLogged?(set)
    }
    
    /// Log "same again" - repeat the last set
    private func logSameAgain() {
        guard let last = lastSet else {
            onError?(.noLastSet)
            return
        }
        
        let set = SetCard.copy(from: last)
        set.sessionId = ensureSession()
        
        modelContext.insert(set)
        saveContext()
        
        lastSet = set
        onSetLogged?(set)
    }
    
    /// Log with a weight delta from the last set
    private func logWithWeightDelta(_ delta: Double) {
        guard let last = lastSet else {
            onError?(.noLastSet)
            return
        }
        
        let set = SetCard.withWeightDelta(from: last, delta: delta)
        set.sessionId = ensureSession()
        
        modelContext.insert(set)
        saveContext()
        
        lastSet = set
        onSetLogged?(set)
    }
    
    /// Log with different reps from the last set
    private func logWithRepChange(_ reps: Int) {
        guard let last = lastSet else {
            onError?(.noLastSet)
            return
        }
        
        let set = SetCard.withReps(from: last, reps: reps)
        set.sessionId = ensureSession()
        
        modelContext.insert(set)
        saveContext()
        
        lastSet = set
        onSetLogged?(set)
    }
    
    // MARK: - Exercise Management
    
    /// Change the current exercise context
    private func changeExercise(to exercise: String) {
        let resolved = profile.resolveExercise(exercise)
        currentExercise = resolved
        onExerciseChanged?(resolved)
        
        // Try to load the last set for this exercise
        loadLastSetForExercise(resolved)
    }
    
    /// Load the last set for an exercise (for context/ghost data)
    private func loadLastSetForExercise(_ exercise: String) {
        let descriptor = FetchDescriptor<SetCard>(
            predicate: #Predicate { $0.exercise == exercise && !$0.isWarmup },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            var limitedDescriptor = descriptor
            limitedDescriptor.fetchLimit = 1
            let sets = try modelContext.fetch(limitedDescriptor)
            // Don't overwrite lastSet if we're mid-workout, just use for ghost data
            // This would be exposed via a separate property
        } catch {
            print("Failed to load last set: \(error)")
        }
    }
    
    // MARK: - Modifiers
    
    /// Apply a modifier to the last set
    private func applyModifier(_ modifier: SetModifier) {
        guard let set = lastSet else {
            onError?(.noLastSet)
            return
        }
        applyModifier(modifier, to: set)
        saveContext()
    }
    
    /// Apply a modifier to a specific set
    private func applyModifier(_ modifier: SetModifier, to set: SetCard) {
        switch modifier {
        case .failed(let atRep):
            set.failed = true
            set.failedAtRep = atRep
            
        case .easy:
            set.rpe = 6
            
        case .hard:
            set.rpe = 9
            
        case .rpe(let value):
            set.rpe = value
            
        case .warmup:
            set.isWarmup = true
            
        case .pain(let location):
            set.painFlag = location
        }
    }
    
    // MARK: - Session Management
    
    /// Ensure a session exists for the current workout
    private func ensureSession() -> UUID {
        if let id = currentSessionId {
            return id
        }
        
        let id = UUID()
        currentSessionId = id
        
        let session = Session(id: id)
        modelContext.insert(session)
        
        return id
    }
    
    /// End the current workout
    func endWorkout() {
        guard let sessionId = currentSessionId else { return }
        
        // Update session end time
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.id == sessionId }
        )
        
        do {
            let sessions = try modelContext.fetch(descriptor)
            if let session = sessions.first {
                session.endTime = Date()
                session.isActive = false
            }
        } catch {
            print("Failed to end session: \(error)")
        }
        
        // Reset state
        currentSessionId = nil
        isWorkoutActive = false
        currentExercise = nil
        lastSet = nil
        
        saveContext()
    }
    
    // MARK: - State Management
    
    /// Load recent state if there's an active session
    private func loadRecentState() {
        // Check for recent sets (within session gap)
        let cutoff = Date().addingTimeInterval(-SessionInferenceEngine.maxGapSeconds)
        let descriptor = FetchDescriptor<SetCard>(
            predicate: #Predicate { $0.timestamp > cutoff },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            var limitedDescriptor = descriptor
            limitedDescriptor.fetchLimit = 1
            let sets = try modelContext.fetch(limitedDescriptor)
            
            if let recentSet = sets.first {
                // Resume the session
                lastSet = recentSet
                currentExercise = recentSet.exercise
                currentSessionId = recentSet.sessionId
                isWorkoutActive = true
            }
        } catch {
            print("Failed to load recent state: \(error)")
        }
    }
    
    /// Handle unknown input
    private func handleUnknown(_ transcript: String) {
        // Create a placeholder set with just the transcript for later review
        guard let exercise = currentExercise else {
            onError?(.noExerciseContext)
            return
        }
        
        // We could create a flagged set or just notify the user
        onError?(.couldNotParse(transcript))
    }
    
    /// Save the model context
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}

// MARK: - Supporting Types

/// Errors that can occur during workout operations
enum WorkoutError: Error {
    case noExerciseContext
    case noLastSet
    case couldNotParse(String)
    
    var message: String {
        switch self {
        case .noExerciseContext:
            return "Say an exercise name first"
        case .noLastSet:
            return "No previous set to reference"
        case .couldNotParse(let transcript):
            return "Couldn't understand: \(transcript)"
        }
    }
}

/// Modifiers that can be applied to a set
enum SetModifier: Equatable {
    case failed(atRep: Int?)
    case easy
    case hard
    case rpe(Int)
    case warmup
    case pain(String)
}

/// Parsed command from voice input
enum ParsedCommand {
    case logSet(exercise: String?, weight: Double, reps: Int, modifiers: [SetModifier])
    case sameAgain
    case weightDelta(Double)
    case repChange(Int)
    case exerciseChange(String)
    case modifier(SetModifier)
    case endWorkout
    case unknown(String)
}
