//
//  SetCard.swift
//  Callout
//
//  The atomic unit of workout logging
//

import Foundation
import SwiftData

/// A single logged set — the atomic unit of Callout
@Model
final class SetCard {
    // MARK: - Primary Fields
    
    /// Unique identifier
    var id: UUID
    
    /// Exercise name (normalized)
    var exercise: String
    
    /// Weight lifted
    var weight: Double
    
    /// Unit for the weight
    var weightUnit: WeightUnit
    
    /// Number of reps completed
    var reps: Int
    
    /// When this set was logged
    var timestamp: Date
    
    // MARK: - Optional Modifiers
    
    /// Rate of Perceived Exertion (1-10)
    var rpe: Int?
    
    /// Whether the set was a failure
    var failed: Bool
    
    /// If failed, which rep did they fail at?
    var failedAtRep: Int?
    
    /// Pain flag with optional body part
    var painFlag: String?
    
    /// Is this a warm-up set?
    var isWarmup: Bool
    
    /// Free-form notes
    var notes: String?
    
    /// Raw voice transcript (for debugging/review)
    var rawTranscript: String?
    
    // MARK: - Session Grouping (Inferred)
    
    /// Session this set belongs to (set by inference engine)
    var sessionId: UUID?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        exercise: String,
        weight: Double,
        weightUnit: WeightUnit,
        reps: Int,
        timestamp: Date = Date(),
        rpe: Int? = nil,
        failed: Bool = false,
        failedAtRep: Int? = nil,
        painFlag: String? = nil,
        isWarmup: Bool = false,
        notes: String? = nil,
        rawTranscript: String? = nil,
        sessionId: UUID? = nil
    ) {
        self.id = id
        self.exercise = exercise
        self.weight = weight
        self.weightUnit = weightUnit
        self.reps = reps
        self.timestamp = timestamp
        self.rpe = rpe
        self.failed = failed
        self.failedAtRep = failedAtRep
        self.painFlag = painFlag
        self.isWarmup = isWarmup
        self.notes = notes
        self.rawTranscript = rawTranscript
        self.sessionId = sessionId
    }
    
    // MARK: - Computed Properties
    
    /// Volume for this set (weight × reps)
    var volume: Double {
        weight * Double(reps)
    }
    
    /// Effective reps (accounts for failure)
    var effectiveReps: Int {
        if failed, let failedAt = failedAtRep {
            return failedAt
        }
        return reps
    }
    
    /// Display string for the set (e.g., "100kg × 5")
    var displayString: String {
        let weightStr = weight.truncatingRemainder(dividingBy: 1) == 0 
            ? String(format: "%.0f", weight) 
            : String(format: "%.1f", weight)
        var str = "\(weightStr)\(weightUnit.shortName) × \(reps)"
        if failed {
            str += " (F)"
        }
        if isWarmup {
            str += " [W]"
        }
        return str
    }
    
    /// Short display for widgets (e.g., "100 × 5")
    var shortDisplayString: String {
        let weightStr = weight.truncatingRemainder(dividingBy: 1) == 0 
            ? String(format: "%.0f", weight) 
            : String(format: "%.1f", weight)
        return "\(weightStr) × \(reps)"
    }
}

// MARK: - Convenience Initializers

extension SetCard {
    /// Create a set by copying another and adjusting weight
    static func withWeightDelta(from set: SetCard, delta: Double) -> SetCard {
        SetCard(
            exercise: set.exercise,
            weight: set.weight + delta,
            weightUnit: set.weightUnit,
            reps: set.reps
        )
    }
    
    /// Create a set by copying another with different reps
    static func withReps(from set: SetCard, reps: Int) -> SetCard {
        SetCard(
            exercise: set.exercise,
            weight: set.weight,
            weightUnit: set.weightUnit,
            reps: reps
        )
    }
    
    /// Create an exact copy of a set (new timestamp and ID)
    static func copy(from set: SetCard) -> SetCard {
        SetCard(
            exercise: set.exercise,
            weight: set.weight,
            weightUnit: set.weightUnit,
            reps: set.reps
        )
    }
}
