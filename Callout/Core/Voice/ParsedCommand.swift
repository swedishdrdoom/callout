//
//  ParsedCommand.swift
//  Callout
//
//  Voice grammar command types for gym workout logging.
//  Handles structured output from natural language voice input.
//

import Foundation

// MARK: - Core Command Protocol

/// Base protocol for all parsed voice commands.
/// Provides common interface for command handling and validation.
public protocol ParsedCommand: Sendable, Equatable, CustomStringConvertible {
    /// Confidence score from 0.0 to 1.0 indicating parse certainty
    var confidence: Double { get }
    
    /// Original raw input that produced this command
    var rawInput: String { get }
}

// MARK: - Weight & Rep Types

/// Represents a weight value with optional unit specification.
/// Handles both metric (kg) and imperial (lbs) units.
public struct Weight: Sendable, Equatable, CustomStringConvertible {
    public let value: Double
    public let unit: WeightUnit?
    
    public init(value: Double, unit: WeightUnit? = nil) {
        self.value = value
        self.unit = unit
    }
    
    public var description: String {
        if let unit = unit {
            return "\(Weight.formatNumber(value)) \(unit.rawValue)"
        }
        return Weight.formatNumber(value)
    }
    
    /// Formats numbers nicely - no decimal for whole numbers
    private static func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

/// Supported weight units in gym context
public enum WeightUnit: String, Sendable, Equatable, CaseIterable {
    case kilograms = "kg"
    case pounds = "lbs"
    case plates = "plates"  // For "add a plate" style commands
    
    /// All recognized string representations for each unit
    public static func from(_ string: String) -> WeightUnit? {
        let lowercased = string.lowercased()
        switch lowercased {
        case "kg", "kgs", "kilo", "kilos", "kilogram", "kilograms":
            return .kilograms
        case "lb", "lbs", "pound", "pounds":
            return .pounds
        case "plate", "plates":
            return .plates
        default:
            return nil
        }
    }
}

/// Represents rep count with optional "reps" suffix acknowledgment
public struct Reps: Sendable, Equatable, CustomStringConvertible {
    public let count: Int
    
    public init(_ count: Int) {
        self.count = count
    }
    
    public var description: String {
        return "\(count) rep\(count == 1 ? "" : "s")"
    }
}

// MARK: - Modifier Types

/// RPE (Rate of Perceived Exertion) scale value
public struct RPE: Sendable, Equatable, CustomStringConvertible {
    public let value: Double
    
    public init(_ value: Double) {
        // Clamp to valid RPE range (1-10, allowing half values)
        self.value = min(10, max(1, value))
    }
    
    public var description: String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "RPE \(Int(value))"
        }
        return "RPE \(value)"
    }
}

/// Body parts that can be associated with pain/discomfort
public enum BodyPart: String, Sendable, Equatable, CaseIterable {
    case shoulder
    case back
    case knee
    case elbow
    case wrist
    case hip
    case neck
    case chest
    case lower_back = "lower back"
    
    public static func from(_ string: String) -> BodyPart? {
        let lowercased = string.lowercased()
        
        // Direct match first
        if let direct = BodyPart(rawValue: lowercased) {
            return direct
        }
        
        // Handle variations
        switch lowercased {
        case "shoulders": return .shoulder
        case "backs", "lowerback": return .back
        case "knees": return .knee
        case "elbows": return .elbow
        case "wrists": return .wrist
        case "hips": return .hip
        case "necks": return .neck
        default: return nil
        }
    }
}

/// All possible set modifiers that can be attached to a logged set
public enum SetModifier: Sendable, Equatable, CustomStringConvertible {
    /// Set was failed at a specific rep, or generally failed
    case failed(atRep: Int?)
    
    /// Subjective difficulty rating
    case easy
    case hard
    
    /// Rate of Perceived Exertion score
    case rpe(RPE)
    
    /// Marks set as warmup (not counted in working sets)
    case warmup
    
    /// Pain/discomfort noted at body part
    case pain(BodyPart)
    
    public var description: String {
        switch self {
        case .failed(let rep):
            if let rep = rep {
                return "failed at rep \(rep)"
            }
            return "failed"
        case .easy:
            return "easy"
        case .hard:
            return "hard"
        case .rpe(let rpe):
            return rpe.description
        case .warmup:
            return "warmup"
        case .pain(let part):
            return "\(part.rawValue) pain"
        }
    }
}

// MARK: - Command Types

/// Logs a complete set with exercise, weight, reps, and optional modifiers.
/// Example: "Bench 225 for 5 hard" or "135 for 8 warmup"
public struct LogSetCommand: ParsedCommand {
    /// Exercise name (nil if continuing previous exercise)
    public let exercise: String?
    
    /// Weight lifted
    public let weight: Weight
    
    /// Number of reps completed
    public let reps: Reps
    
    /// Optional modifiers (failed, easy, hard, warmup, etc.)
    public let modifiers: [SetModifier]
    
    public let confidence: Double
    public let rawInput: String
    
    public init(
        exercise: String?,
        weight: Weight,
        reps: Reps,
        modifiers: [SetModifier] = [],
        confidence: Double = 1.0,
        rawInput: String = ""
    ) {
        self.exercise = exercise
        self.weight = weight
        self.reps = reps
        self.modifiers = modifiers
        self.confidence = confidence
        self.rawInput = rawInput
    }
    
    public var description: String {
        var parts: [String] = []
        if let exercise = exercise {
            parts.append(exercise)
        }
        parts.append(weight.description)
        parts.append("for")
        parts.append(reps.description)
        parts.append(contentsOf: modifiers.map { $0.description })
        return parts.joined(separator: " ")
    }
}

/// Repeats the previous set exactly.
/// Example: "Same again" or just "Same"
public struct SameAgainCommand: ParsedCommand {
    public let confidence: Double
    public let rawInput: String
    
    public init(confidence: Double = 1.0, rawInput: String = "") {
        self.confidence = confidence
        self.rawInput = rawInput
    }
    
    public var description: String {
        return "same again"
    }
}

/// Adjusts weight relative to previous set.
/// Example: "Plus 5" or "Drop 10 lbs"
public struct WeightDeltaCommand: ParsedCommand {
    public enum Direction: String, Sendable, Equatable {
        case add
        case subtract
    }
    
    public let direction: Direction
    public let delta: Weight
    
    public let confidence: Double
    public let rawInput: String
    
    public init(
        direction: Direction,
        delta: Weight,
        confidence: Double = 1.0,
        rawInput: String = ""
    ) {
        self.direction = direction
        self.delta = delta
        self.confidence = confidence
        self.rawInput = rawInput
    }
    
    public var description: String {
        let verb = direction == .add ? "plus" : "minus"
        return "\(verb) \(delta.description)"
    }
}

/// Changes rep count for subsequent sets.
/// Example: "5 reps" (when no weight context)
public struct RepChangeCommand: ParsedCommand {
    public let reps: Reps
    
    public let confidence: Double
    public let rawInput: String
    
    public init(reps: Reps, confidence: Double = 1.0, rawInput: String = "") {
        self.reps = reps
        self.confidence = confidence
        self.rawInput = rawInput
    }
    
    public var description: String {
        return reps.description
    }
}

/// Changes to a different exercise.
/// Example: "Switching to squats"
public struct ExerciseChangeCommand: ParsedCommand {
    public let exercise: String
    
    public let confidence: Double
    public let rawInput: String
    
    public init(exercise: String, confidence: Double = 1.0, rawInput: String = "") {
        self.exercise = exercise
        self.confidence = confidence
        self.rawInput = rawInput
    }
    
    public var description: String {
        return "switch to \(exercise)"
    }
}

/// Standalone modifier without set context.
/// Example: "Failed at 4" or "That was hard"
public struct ModifierCommand: ParsedCommand {
    public let modifier: SetModifier
    
    public let confidence: Double
    public let rawInput: String
    
    public init(modifier: SetModifier, confidence: Double = 1.0, rawInput: String = "") {
        self.modifier = modifier
        self.confidence = confidence
        self.rawInput = rawInput
    }
    
    public var description: String {
        return modifier.description
    }
}

/// Represents input that couldn't be parsed into a known command.
/// Preserves the original input for potential correction or learning.
public struct UnknownCommand: ParsedCommand {
    /// Best-effort interpretation of what the user might have meant
    public let possibleInterpretations: [String]
    
    public let confidence: Double
    public let rawInput: String
    
    public init(rawInput: String, possibleInterpretations: [String] = []) {
        self.rawInput = rawInput
        self.possibleInterpretations = possibleInterpretations
        self.confidence = 0.0
    }
    
    public var description: String {
        return "unknown: \"\(rawInput)\""
    }
}

// MARK: - Result Wrapper

/// Unified result type that can hold any parsed command
public enum ParseResult: Sendable, Equatable {
    case logSet(LogSetCommand)
    case sameAgain(SameAgainCommand)
    case weightDelta(WeightDeltaCommand)
    case repChange(RepChangeCommand)
    case exerciseChange(ExerciseChangeCommand)
    case modifier(ModifierCommand)
    case unknown(UnknownCommand)
    
    /// Underlying confidence score
    public var confidence: Double {
        switch self {
        case .logSet(let cmd): return cmd.confidence
        case .sameAgain(let cmd): return cmd.confidence
        case .weightDelta(let cmd): return cmd.confidence
        case .repChange(let cmd): return cmd.confidence
        case .exerciseChange(let cmd): return cmd.confidence
        case .modifier(let cmd): return cmd.confidence
        case .unknown(let cmd): return cmd.confidence
        }
    }
    
    /// Original raw input
    public var rawInput: String {
        switch self {
        case .logSet(let cmd): return cmd.rawInput
        case .sameAgain(let cmd): return cmd.rawInput
        case .weightDelta(let cmd): return cmd.rawInput
        case .repChange(let cmd): return cmd.rawInput
        case .exerciseChange(let cmd): return cmd.rawInput
        case .modifier(let cmd): return cmd.rawInput
        case .unknown(let cmd): return cmd.rawInput
        }
    }
}
