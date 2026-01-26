//
//  Session.swift
//  Callout
//
//  Inferred workout session from set clusters
//

import Foundation
import SwiftData

/// A workout session — inferred from set clusters, never explicitly created by user
@Model
final class Session {
    // MARK: - Primary Fields
    
    /// Unique identifier
    var id: UUID
    
    /// When the session started (first set timestamp)
    var startTime: Date
    
    /// When the session ended (last set timestamp + buffer, or explicit end)
    var endTime: Date?
    
    /// Whether this session is currently active
    var isActive: Bool
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.isActive = isActive
    }
}

// MARK: - Session Analysis (Computed from Sets)

extension Session {
    /// Calculate session statistics from a collection of sets
    struct Statistics {
        let totalSets: Int
        let totalVolume: Double
        let exercises: [String]
        let topSetsByExercise: [String: SetCard]
        let duration: TimeInterval
        let failedSets: Int
        let painFlags: [String]
        
        var exerciseCount: Int { exercises.count }
        var hasFailures: Bool { failedSets > 0 }
        var hasPainFlags: Bool { !painFlags.isEmpty }
    }
    
    /// Generate statistics from a collection of sets belonging to this session
    static func statistics(from sets: [SetCard]) -> Statistics {
        guard !sets.isEmpty else {
            return Statistics(
                totalSets: 0,
                totalVolume: 0,
                exercises: [],
                topSetsByExercise: [:],
                duration: 0,
                failedSets: 0,
                painFlags: []
            )
        }
        
        let sortedSets = sets.sorted { $0.timestamp < $1.timestamp }
        let exercises = Array(Set(sets.map { $0.exercise }))
        
        // Find top set for each exercise (highest weight × reps that wasn't a warmup)
        var topSets: [String: SetCard] = [:]
        for exercise in exercises {
            let exerciseSets = sets.filter { $0.exercise == exercise && !$0.isWarmup }
            if let topSet = exerciseSets.max(by: { $0.volume < $1.volume }) {
                topSets[exercise] = topSet
            }
        }
        
        let duration: TimeInterval
        if let first = sortedSets.first, let last = sortedSets.last {
            duration = last.timestamp.timeIntervalSince(first.timestamp)
        } else {
            duration = 0
        }
        
        return Statistics(
            totalSets: sets.count,
            totalVolume: sets.reduce(0) { $0 + $1.volume },
            exercises: exercises,
            topSetsByExercise: topSets,
            duration: duration,
            failedSets: sets.filter { $0.failed }.count,
            painFlags: sets.compactMap { $0.painFlag }
        )
    }
}

// MARK: - Session Inference Engine

/// Engine for inferring session boundaries from sets
struct SessionInferenceEngine {
    /// Maximum gap between sets before starting a new session (in seconds)
    static let maxGapSeconds: TimeInterval = 30 * 60 // 30 minutes
    
    /// Minimum gap to consider session ended
    static let minEndGapSeconds: TimeInterval = 15 * 60 // 15 minutes
    
    /// Group sets into sessions based on time gaps
    static func inferSessions(from sets: [SetCard]) -> [[SetCard]] {
        guard !sets.isEmpty else { return [] }
        
        let sortedSets = sets.sorted { $0.timestamp < $1.timestamp }
        var sessions: [[SetCard]] = []
        var currentSession: [SetCard] = []
        
        for set in sortedSets {
            if let lastSet = currentSession.last {
                let gap = set.timestamp.timeIntervalSince(lastSet.timestamp)
                if gap > maxGapSeconds {
                    // Start new session
                    sessions.append(currentSession)
                    currentSession = [set]
                } else {
                    currentSession.append(set)
                }
            } else {
                currentSession.append(set)
            }
        }
        
        // Don't forget the last session
        if !currentSession.isEmpty {
            sessions.append(currentSession)
        }
        
        return sessions
    }
    
    /// Check if a session should be considered complete
    static func isSessionComplete(_ sets: [SetCard]) -> Bool {
        guard let lastSet = sets.last else { return true }
        let gap = Date().timeIntervalSince(lastSet.timestamp)
        return gap > minEndGapSeconds
    }
}
