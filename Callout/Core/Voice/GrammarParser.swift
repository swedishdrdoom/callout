//
//  GrammarParser.swift
//  Callout
//
//  Voice grammar parser for gym workout logging.
//  Converts natural language voice input into structured commands.
//
//  Grammar Rules:
//  SetLog     := Exercise? Weight "for" Reps Modifier*
//             | "same" "again"?
//             | Delta
//             | Modifier
//  Exercise   := KnownExercise | UnknownWord+
//  Weight     := Number Unit?
//  Reps       := Number "reps"?
//  Delta      := ("plus" | "add" | "minus" | "drop") Number
//  Modifier   := "failed" ("at" Number)? | "easy" | "hard" | "rpe" Number | "warmup" | BodyPart "pain"
//

import Foundation

// MARK: - Token Types

/// Represents a single token from the input stream
internal enum Token: Equatable, CustomStringConvertible {
    case number(Double)
    case word(String)
    case keyword(Keyword)
    
    var description: String {
        switch self {
        case .number(let n):
            if n.truncatingRemainder(dividingBy: 1) == 0 {
                return "num(\(Int(n)))"
            }
            return "num(\(n))"
        case .word(let w):
            return "word(\(w))"
        case .keyword(let k):
            return "kw(\(k.rawValue))"
        }
    }
}

/// Reserved keywords in the grammar
internal enum Keyword: String, CaseIterable {
    // Connectors
    case `for` = "for"
    case at = "at"
    
    // Same again
    case same = "same"
    case again = "again"
    
    // Delta operations
    case plus = "plus"
    case add = "add"
    case minus = "minus"
    case drop = "drop"
    
    // Modifiers
    case failed = "failed"
    case failure = "failure"
    case easy = "easy"
    case hard = "hard"
    case rpe = "rpe"
    case warmup = "warmup"
    case warm = "warm"
    case up = "up"
    case pain = "pain"
    
    // Rep indicator
    case reps = "reps"
    case rep = "rep"
}

// MARK: - Tokenizer

/// Breaks raw input into a stream of tokens
internal struct Tokenizer {
    
    /// Tokenizes the input string into an array of tokens
    /// - Parameter input: Raw voice transcription
    /// - Returns: Array of tokens preserving order
    static func tokenize(_ input: String) -> [Token] {
        var tokens: [Token] = []
        
        // Normalize input: lowercase, remove punctuation except decimal points
        let normalized = input
            .lowercased()
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "'", with: "")
        
        // Split on whitespace
        let words = normalized.split(separator: " ", omittingEmptySubsequences: true)
        
        for word in words {
            let wordStr = String(word)
            
            // Try to parse as number first
            if let number = parseNumber(wordStr) {
                tokens.append(.number(number))
            }
            // Check if it's a keyword
            else if let keyword = Keyword(rawValue: wordStr) {
                tokens.append(.keyword(keyword))
            }
            // Otherwise it's a word
            else {
                tokens.append(.word(wordStr))
            }
        }
        
        return tokens
    }
    
    /// Attempts to parse a string as a number
    /// Handles: integers, decimals, spoken numbers
    private static func parseNumber(_ string: String) -> Double? {
        // Direct numeric parsing
        if let value = Double(string) {
            return value
        }
        
        // Handle spoken numbers
        let spokenNumbers: [String: Double] = [
            "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4,
            "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9,
            "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13,
            "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17,
            "eighteen": 18, "nineteen": 19, "twenty": 20
        ]
        
        if let spoken = spokenNumbers[string.lowercased()] {
            return spoken
        }
        
        return nil
    }
}

// MARK: - Parser

/// Main grammar parser for gym voice commands
public final class GrammarParser: Sendable {
    
    /// Known exercise names for higher confidence matching
    /// These are matched case-insensitively
    private static let knownExercises: Set<String> = [
        // Chest
        "bench", "bench press", "incline", "incline bench", "decline", "decline bench",
        "dumbbell press", "chest press", "flies", "flyes", "pec deck", "pushups", "push ups",
        "cable flies", "cable crossover",
        
        // Back
        "deadlift", "deadlifts", "row", "rows", "barbell row", "dumbbell row",
        "lat pulldown", "pulldown", "pull ups", "pullups", "chin ups", "chinups",
        "cable row", "seated row", "t-bar row", "bent over row",
        
        // Shoulders
        "overhead press", "ohp", "military press", "shoulder press",
        "lateral raise", "lateral raises", "front raise", "rear delt",
        "face pulls", "shrugs",
        
        // Legs
        "squat", "squats", "back squat", "front squat", "leg press",
        "lunges", "lunge", "leg extension", "leg curl", "hamstring curl",
        "calf raise", "calf raises", "romanian deadlift", "rdl",
        "hip thrust", "goblet squat",
        
        // Arms
        "curl", "curls", "bicep curl", "bicep curls", "hammer curl",
        "tricep", "triceps", "tricep pushdown", "tricep extension",
        "skull crusher", "skull crushers", "preacher curl",
        "cable curl", "concentration curl",
        
        // Core
        "plank", "crunches", "sit ups", "situps", "leg raises",
        "ab wheel", "cable crunch", "hanging leg raise"
    ]
    
    // MARK: - Public Interface
    
    public init() {}
    
    /// Parses voice input into a structured command
    /// - Parameter input: Raw voice transcription string
    /// - Returns: ParseResult containing the appropriate command type
    public func parse(_ input: String) -> ParseResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .unknown(UnknownCommand(rawInput: input))
        }
        
        let tokens = Tokenizer.tokenize(trimmed)
        
        guard !tokens.isEmpty else {
            return .unknown(UnknownCommand(rawInput: input))
        }
        
        // Try each grammar rule in order of specificity
        
        // 1. "Same again" - most specific
        if let result = parseSameAgain(tokens, rawInput: input) {
            return result
        }
        
        // 2. Delta commands (plus/minus)
        if let result = parseDelta(tokens, rawInput: input) {
            return result
        }
        
        // 3. Full set log (Exercise? Weight for Reps Modifier*)
        if let result = parseSetLog(tokens, rawInput: input) {
            return result
        }
        
        // 4. Standalone modifier
        if let result = parseStandaloneModifier(tokens, rawInput: input) {
            return result
        }
        
        // 5. Standalone rep count (e.g., "5 reps")
        if let result = parseStandaloneReps(tokens, rawInput: input) {
            return result
        }
        
        // 6. Exercise change (just exercise name)
        if let result = parseExerciseChange(tokens, rawInput: input) {
            return result
        }
        
        // Fall through to unknown
        return .unknown(UnknownCommand(
            rawInput: input,
            possibleInterpretations: suggestInterpretations(tokens)
        ))
    }
    
    // MARK: - Grammar Rules
    
    /// Parses "same" or "same again"
    private func parseSameAgain(_ tokens: [Token], rawInput: String) -> ParseResult? {
        guard let first = tokens.first,
              case .keyword(let kw) = first,
              kw == .same else {
            return nil
        }
        
        // "same" or "same again"
        let confidence: Double
        if tokens.count == 1 {
            confidence = 0.95
        } else if tokens.count == 2,
                  case .keyword(.again) = tokens[1] {
            confidence = 1.0
        } else {
            // "same" followed by something unexpected - still valid but lower confidence
            confidence = 0.8
        }
        
        return .sameAgain(SameAgainCommand(confidence: confidence, rawInput: rawInput))
    }
    
    /// Parses delta commands: "plus 5", "add 2.5 kg", "minus 10", "drop 5"
    private func parseDelta(_ tokens: [Token], rawInput: String) -> ParseResult? {
        guard tokens.count >= 2,
              case .keyword(let kw) = tokens[0] else {
            return nil
        }
        
        let direction: WeightDeltaCommand.Direction
        switch kw {
        case .plus, .add:
            direction = .add
        case .minus, .drop:
            direction = .subtract
        default:
            return nil
        }
        
        // Expect a number next
        guard case .number(let value) = tokens[1] else {
            return nil
        }
        
        // Optional unit
        var unit: WeightUnit? = nil
        var confidence = 0.95
        
        if tokens.count >= 3 {
            if case .word(let unitStr) = tokens[2] {
                unit = WeightUnit.from(unitStr)
                if unit != nil {
                    confidence = 1.0
                }
            }
        }
        
        let delta = Weight(value: value, unit: unit)
        return .weightDelta(WeightDeltaCommand(
            direction: direction,
            delta: delta,
            confidence: confidence,
            rawInput: rawInput
        ))
    }
    
    /// Parses full set log: Exercise? Weight "for" Reps Modifier*
    private func parseSetLog(_ tokens: [Token], rawInput: String) -> ParseResult? {
        var index = 0
        var exercise: String? = nil
        var exerciseWords: [String] = []
        var weight: Weight? = nil
        var reps: Reps? = nil
        var modifiers: [SetModifier] = []
        var confidence = 1.0
        
        // Scan for the pattern: ... Number ... "for" Number ...
        // Find "for" keyword first to orient ourselves
        var forIndex: Int? = nil
        for (i, token) in tokens.enumerated() {
            if case .keyword(.for) = token {
                forIndex = i
                break
            }
        }
        
        // Must have "for" to be a set log
        guard let foundForAt = forIndex,
              foundForAt > 0,
              foundForAt < tokens.count - 1 else {
            return nil
        }
        
        // Weight should be immediately before "for"
        guard case .number(let weightValue) = tokens[foundForAt - 1] else {
            return nil
        }
        
        // Check for unit before weight number
        var weightUnit: WeightUnit? = nil
        var weightStartIndex = foundForAt - 1
        
        // Actually, unit comes AFTER number typically: "135 lbs for 5"
        // Let's look between number and "for" - but there's nothing there
        // Unit would be: "135 kg for 5" - so we need to look after weight num
        // Wait, that puts unit AT forIndex... let me reconsider
        
        // Pattern: "bench 135 lbs for 5" or "bench 135 for 5"
        // If there's a unit, it's between weight number and "for"
        // But our forIndex points to "for", so if there's a unit, the structure is:
        // tokens[foundForAt-2] = weight number, tokens[foundForAt-1] = unit, tokens[foundForAt] = "for"
        
        // Let me re-examine: with "135 lbs for 5":
        // tokens = [num(135), word(lbs), kw(for), num(5)]
        // foundForAt = 2
        // foundForAt - 1 = 1 = word(lbs), not number!
        
        // Need to find weight number that precedes "for", possibly with unit between
        var actualWeightIndex: Int? = nil
        for i in stride(from: foundForAt - 1, through: 0, by: -1) {
            if case .number(_) = tokens[i] {
                actualWeightIndex = i
                break
            }
        }
        
        guard let weightIdx = actualWeightIndex,
              case .number(let actualWeight) = tokens[weightIdx] else {
            return nil
        }
        
        // Check for unit between weight and "for"
        if weightIdx < foundForAt - 1 {
            if case .word(let possibleUnit) = tokens[weightIdx + 1] {
                weightUnit = WeightUnit.from(possibleUnit)
            }
        }
        
        weight = Weight(value: actualWeight, unit: weightUnit)
        
        // Reps should be after "for"
        guard case .number(let repCount) = tokens[foundForAt + 1] else {
            return nil
        }
        reps = Reps(Int(repCount))
        
        // Exercise is everything before the weight (as words)
        for i in 0..<weightIdx {
            switch tokens[i] {
            case .word(let w):
                exerciseWords.append(w)
            case .number(let n):
                // Number in exercise position is unusual, lower confidence
                exerciseWords.append(String(Int(n)))
                confidence -= 0.1
            case .keyword(let kw):
                // Keywords in exercise position - could be part of exercise name
                exerciseWords.append(kw.rawValue)
            }
        }
        
        if !exerciseWords.isEmpty {
            exercise = exerciseWords.joined(separator: " ")
            
            // Boost confidence for known exercises
            if Self.isKnownExercise(exercise!) {
                confidence = min(1.0, confidence + 0.1)
            }
        }
        
        // Parse modifiers after reps
        var modifierIndex = foundForAt + 2
        
        // Skip optional "reps" keyword
        if modifierIndex < tokens.count {
            if case .keyword(let kw) = tokens[modifierIndex],
               kw == .reps || kw == .rep {
                modifierIndex += 1
            }
        }
        
        // Parse remaining tokens as modifiers
        while modifierIndex < tokens.count {
            if let (modifier, consumed) = parseModifier(tokens, startingAt: modifierIndex) {
                modifiers.append(modifier)
                modifierIndex += consumed
            } else {
                // Unknown token in modifier position, lower confidence but continue
                confidence -= 0.1
                modifierIndex += 1
            }
        }
        
        guard let finalWeight = weight, let finalReps = reps else {
            return nil
        }
        
        return .logSet(LogSetCommand(
            exercise: exercise,
            weight: finalWeight,
            reps: finalReps,
            modifiers: modifiers,
            confidence: max(0.5, confidence),
            rawInput: rawInput
        ))
    }
    
    /// Parses standalone modifier: "failed", "failed at 4", "easy", "hard", "warmup", etc.
    private func parseStandaloneModifier(_ tokens: [Token], rawInput: String) -> ParseResult? {
        guard let (modifier, consumed) = parseModifier(tokens, startingAt: 0) else {
            return nil
        }
        
        // Should consume most/all tokens for high confidence
        let confidence = consumed >= tokens.count ? 1.0 : 0.8
        
        return .modifier(ModifierCommand(
            modifier: modifier,
            confidence: confidence,
            rawInput: rawInput
        ))
    }
    
    /// Parses a modifier at the given position
    /// - Returns: Tuple of (modifier, tokens consumed) or nil
    private func parseModifier(_ tokens: [Token], startingAt index: Int) -> (SetModifier, Int)? {
        guard index < tokens.count else { return nil }
        
        let token = tokens[index]
        
        switch token {
        case .keyword(let kw):
            switch kw {
            case .failed, .failure:
                // Check for "at N"
                if index + 2 < tokens.count,
                   case .keyword(.at) = tokens[index + 1],
                   case .number(let rep) = tokens[index + 2] {
                    return (.failed(atRep: Int(rep)), 3)
                }
                return (.failed(atRep: nil), 1)
                
            case .easy:
                return (.easy, 1)
                
            case .hard:
                return (.hard, 1)
                
            case .rpe:
                // Expect number after
                if index + 1 < tokens.count,
                   case .number(let value) = tokens[index + 1] {
                    return (.rpe(RPE(value)), 2)
                }
                return nil
                
            case .warmup:
                return (.warmup, 1)
                
            case .warm:
                // Check for "warm up" (two words)
                if index + 1 < tokens.count,
                   case .keyword(.up) = tokens[index + 1] {
                    return (.warmup, 2)
                }
                return nil
                
            default:
                return nil
            }
            
        case .word(let w):
            // Check for body part pain: "shoulder pain", etc.
            if let bodyPart = BodyPart.from(w) {
                if index + 1 < tokens.count,
                   case .keyword(.pain) = tokens[index + 1] {
                    return (.pain(bodyPart), 2)
                }
            }
            return nil
            
        case .number(_):
            return nil
        }
    }
    
    /// Parses standalone rep count: "5 reps"
    private func parseStandaloneReps(_ tokens: [Token], rawInput: String) -> ParseResult? {
        guard tokens.count >= 1,
              tokens.count <= 2,
              case .number(let count) = tokens[0] else {
            return nil
        }
        
        // Must have "reps" to distinguish from just a number
        guard tokens.count == 2,
              case .keyword(let kw) = tokens[1],
              kw == .reps || kw == .rep else {
            return nil
        }
        
        return .repChange(RepChangeCommand(
            reps: Reps(Int(count)),
            confidence: 0.9,
            rawInput: rawInput
        ))
    }
    
    /// Parses exercise change when input is just an exercise name
    private func parseExerciseChange(_ tokens: [Token], rawInput: String) -> ParseResult? {
        // Collect all words
        var words: [String] = []
        
        for token in tokens {
            switch token {
            case .word(let w):
                words.append(w)
            case .keyword(let kw):
                words.append(kw.rawValue)
            case .number(_):
                // Numbers in exercise name is suspicious
                return nil
            }
        }
        
        guard !words.isEmpty else { return nil }
        
        let exercise = words.joined(separator: " ")
        
        // Only high confidence if it's a known exercise
        let confidence = Self.isKnownExercise(exercise) ? 0.85 : 0.5
        
        // Too low confidence means we should return unknown instead
        guard confidence >= 0.6 else { return nil }
        
        return .exerciseChange(ExerciseChangeCommand(
            exercise: exercise,
            confidence: confidence,
            rawInput: rawInput
        ))
    }
    
    // MARK: - Helpers
    
    /// Checks if the given string matches a known exercise
    private static func isKnownExercise(_ name: String) -> Bool {
        let normalized = name.lowercased()
        
        // Direct match
        if knownExercises.contains(normalized) {
            return true
        }
        
        // Partial match - exercise name contains or is contained by known
        for known in knownExercises {
            if normalized.contains(known) || known.contains(normalized) {
                return true
            }
        }
        
        return false
    }
    
    /// Suggests possible interpretations for unknown input
    private func suggestInterpretations(_ tokens: [Token]) -> [String] {
        var suggestions: [String] = []
        
        // Check if there are numbers that might be weight/reps
        let numbers = tokens.compactMap { token -> Double? in
            if case .number(let n) = token { return n }
            return nil
        }
        
        if numbers.count >= 2 {
            suggestions.append("Did you mean '\(Int(numbers[0])) for \(Int(numbers[1]))'?")
        } else if numbers.count == 1 {
            suggestions.append("Did you mean 'plus \(Int(numbers[0]))'?")
            suggestions.append("Did you mean '\(Int(numbers[0])) reps'?")
        }
        
        // Check for exercise-like words
        let words = tokens.compactMap { token -> String? in
            if case .word(let w) = token { return w }
            return nil
        }
        
        for word in words {
            if Self.isKnownExercise(word) {
                suggestions.append("Did you mean to log a set of \(word)?")
            }
        }
        
        return suggestions
    }
}

// MARK: - Convenience Extensions

public extension GrammarParser {
    
    /// Parses input and returns LogSetCommand if that's what was parsed
    func parseAsSet(_ input: String) -> LogSetCommand? {
        if case .logSet(let cmd) = parse(input) {
            return cmd
        }
        return nil
    }
    
    /// Parses input and returns WeightDeltaCommand if that's what was parsed
    func parseAsDelta(_ input: String) -> WeightDeltaCommand? {
        if case .weightDelta(let cmd) = parse(input) {
            return cmd
        }
        return nil
    }
    
    /// Checks if input appears to be a "same again" command
    func isSameAgain(_ input: String) -> Bool {
        if case .sameAgain(_) = parse(input) {
            return true
        }
        return false
    }
}
