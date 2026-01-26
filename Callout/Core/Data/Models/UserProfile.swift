//
//  UserProfile.swift
//  Callout
//
//  User preferences and settings
//

import Foundation
import SwiftData

/// Voice trigger options for AirPods
enum VoiceTrigger: String, Codable, CaseIterable {
    case tapLeft = "tap_left"
    case tapRight = "tap_right"
    case holdLeft = "hold_left"
    case holdRight = "hold_right"
    
    var displayName: String {
        switch self {
        case .tapLeft: return "Tap Left AirPod"
        case .tapRight: return "Tap Right AirPod"
        case .holdLeft: return "Hold Left AirPod"
        case .holdRight: return "Hold Right AirPod"
        }
    }
    
    var shortDescription: String {
        switch self {
        case .tapLeft: return "Tap left"
        case .tapRight: return "Tap right"
        case .holdLeft: return "Hold left"
        case .holdRight: return "Hold right"
        }
    }
}

/// User profile containing preferences and learned shortcuts
@Model
final class UserProfile {
    // MARK: - Primary Settings
    
    /// Unique identifier
    var id: UUID
    
    /// Preferred weight unit
    var preferredUnit: WeightUnit
    
    /// How to trigger voice recording
    var voiceTrigger: VoiceTrigger
    
    /// Whether onboarding has been completed
    var hasCompletedOnboarding: Bool
    
    // MARK: - Exercise Aliases
    
    /// User's shorthand → canonical exercise name
    /// e.g., "bench" → "Bench Press", "dl" → "Deadlift"
    var exerciseAliases: [String: String]
    
    // MARK: - Timestamps
    
    /// When the profile was created
    var createdAt: Date
    
    /// When the profile was last modified
    var updatedAt: Date
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        preferredUnit: WeightUnit = .kg,
        voiceTrigger: VoiceTrigger = .tapLeft,
        hasCompletedOnboarding: Bool = false,
        exerciseAliases: [String: String] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.preferredUnit = preferredUnit
        self.voiceTrigger = voiceTrigger
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.exerciseAliases = exerciseAliases
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Default Exercise Aliases

extension UserProfile {
    /// Default set of exercise aliases
    static let defaultAliases: [String: String] = [
        // Bench variations
        "bench": "Bench Press",
        "flat bench": "Bench Press",
        "incline": "Incline Bench Press",
        "incline bench": "Incline Bench Press",
        "decline": "Decline Bench Press",
        "db bench": "Dumbbell Bench Press",
        "dumbbell bench": "Dumbbell Bench Press",
        
        // Squat variations
        "squat": "Barbell Squat",
        "squats": "Barbell Squat",
        "back squat": "Barbell Squat",
        "front squat": "Front Squat",
        "goblet": "Goblet Squat",
        "goblet squat": "Goblet Squat",
        
        // Deadlift variations
        "deadlift": "Deadlift",
        "dl": "Deadlift",
        "dead": "Deadlift",
        "sumo": "Sumo Deadlift",
        "rdl": "Romanian Deadlift",
        "romanian": "Romanian Deadlift",
        "stiff leg": "Stiff Leg Deadlift",
        
        // Press variations
        "ohp": "Overhead Press",
        "press": "Overhead Press",
        "overhead": "Overhead Press",
        "military": "Military Press",
        "shoulder press": "Overhead Press",
        "push press": "Push Press",
        
        // Row variations
        "row": "Barbell Row",
        "rows": "Barbell Row",
        "bent over row": "Barbell Row",
        "bb row": "Barbell Row",
        "db row": "Dumbbell Row",
        "dumbbell row": "Dumbbell Row",
        "cable row": "Cable Row",
        "seated row": "Seated Cable Row",
        
        // Pull variations
        "pullup": "Pull-up",
        "pullups": "Pull-up",
        "pull up": "Pull-up",
        "chinup": "Chin-up",
        "chin up": "Chin-up",
        "lat pulldown": "Lat Pulldown",
        "pulldown": "Lat Pulldown",
        
        // Arm exercises
        "curl": "Barbell Curl",
        "curls": "Barbell Curl",
        "bicep curl": "Barbell Curl",
        "db curl": "Dumbbell Curl",
        "hammer curl": "Hammer Curl",
        "tricep": "Tricep Extension",
        "triceps": "Tricep Extension",
        "pushdown": "Tricep Pushdown",
        "skull crusher": "Skull Crushers",
        "skullcrusher": "Skull Crushers",
        
        // Leg exercises
        "leg press": "Leg Press",
        "leg curl": "Leg Curl",
        "leg extension": "Leg Extension",
        "calf raise": "Calf Raise",
        "calf": "Calf Raise",
        "lunge": "Lunges",
        "lunges": "Lunges",
        "hip thrust": "Hip Thrust",
        
        // Other
        "dip": "Dips",
        "dips": "Dips",
        "shrug": "Shrugs",
        "shrugs": "Shrugs",
        "face pull": "Face Pulls",
        "lateral raise": "Lateral Raises",
        "lateral": "Lateral Raises",
        "rear delt": "Rear Delt Fly",
    ]
    
    /// Resolve an exercise name using aliases
    func resolveExercise(_ input: String) -> String {
        let normalized = input.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Check user's custom aliases first
        if let resolved = exerciseAliases[normalized] {
            return resolved
        }
        
        // Then check default aliases
        if let resolved = Self.defaultAliases[normalized] {
            return resolved
        }
        
        // If no match, return input with title case
        return input.capitalized
    }
}
