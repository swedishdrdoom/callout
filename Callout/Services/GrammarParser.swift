import Foundation

/// Parses gym shorthand voice commands into structured data
/// Handles: "bench 100 for 5", "same", "squat", "add pain", etc.
@Observable
final class GrammarParser {
    static let shared = GrammarParser()
    
    // MARK: - Configuration
    
    /// User's preferred weight unit
    var defaultUnit: WeightUnit = .kg
    
    /// Known exercise aliases (expanded over time)
    private var exerciseAliases: [String: String] = [
        // Bench variations
        "bench": "Bench Press",
        "bench press": "Bench Press",
        "flat bench": "Bench Press",
        "incline": "Incline Bench Press",
        "incline bench": "Incline Bench Press",
        "decline": "Decline Bench Press",
        "dumbbell bench": "Dumbbell Bench Press",
        "db bench": "Dumbbell Bench Press",
        
        // Squat variations
        "squat": "Squat",
        "squats": "Squat",
        "back squat": "Back Squat",
        "front squat": "Front Squat",
        "goblet": "Goblet Squat",
        "goblet squat": "Goblet Squat",
        
        // Deadlift variations
        "deadlift": "Deadlift",
        "dead": "Deadlift",
        "deads": "Deadlift",
        "sumo": "Sumo Deadlift",
        "conventional": "Conventional Deadlift",
        "rdl": "Romanian Deadlift",
        "romanian": "Romanian Deadlift",
        "stiff leg": "Stiff Leg Deadlift",
        
        // Press variations
        "ohp": "Overhead Press",
        "overhead": "Overhead Press",
        "overhead press": "Overhead Press",
        "shoulder press": "Overhead Press",
        "military": "Military Press",
        "military press": "Military Press",
        
        // Row variations
        "row": "Barbell Row",
        "rows": "Barbell Row",
        "barbell row": "Barbell Row",
        "bent over row": "Barbell Row",
        "dumbbell row": "Dumbbell Row",
        "db row": "Dumbbell Row",
        "cable row": "Cable Row",
        "seated row": "Seated Cable Row",
        
        // Pull variations
        "pull up": "Pull Up",
        "pullup": "Pull Up",
        "pull ups": "Pull Up",
        "chin up": "Chin Up",
        "chinup": "Chin Up",
        "chin ups": "Chin Up",
        "lat pulldown": "Lat Pulldown",
        "pulldown": "Lat Pulldown",
        
        // Arm exercises
        "curl": "Barbell Curl",
        "curls": "Barbell Curl",
        "bicep curl": "Barbell Curl",
        "dumbbell curl": "Dumbbell Curl",
        "hammer curl": "Hammer Curl",
        "tricep": "Tricep Extension",
        "triceps": "Tricep Extension",
        "pushdown": "Tricep Pushdown",
        "skull crusher": "Skull Crusher",
        
        // Leg exercises
        "leg press": "Leg Press",
        "leg extension": "Leg Extension",
        "leg curl": "Leg Curl",
        "hamstring curl": "Leg Curl",
        "calf raise": "Calf Raise",
        "calves": "Calf Raise",
        "lunge": "Lunges",
        "lunges": "Lunges",
        
        // Other
        "dip": "Dips",
        "dips": "Dips",
        "shrug": "Shrugs",
        "shrugs": "Shrugs",
        "face pull": "Face Pull",
        "lateral raise": "Lateral Raise",
        "laterals": "Lateral Raise",
    ]
    
    // MARK: - Parsing Result
    
    enum ParseResult {
        case setLogged(SetData)
        case exerciseChanged(String)
        case sameAgain
        case addFlag(SetFlag)
        case warmup(SetData)
        case unknown(String)
        case empty
        
        struct SetData {
            let weight: Double
            let reps: Int
            let unit: WeightUnit?
            let rpe: Double?
            let isWarmup: Bool
        }
    }
    
    // MARK: - Main Parse Method
    
    /// Parse a voice transcription into a structured command
    func parse(_ input: String) -> ParseResult {
        let text = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !text.isEmpty else { return .empty }
        
        // Check for "same" / "same again" / "again"
        if isSameCommand(text) {
            return .sameAgain
        }
        
        // Check for flag additions
        if let flag = parseFlag(text) {
            return .addFlag(flag)
        }
        
        // Check for warmup prefix
        let (isWarmup, cleanedText) = extractWarmupPrefix(text)
        
        // Try to parse as set data (weight × reps)
        if let setData = parseSetData(cleanedText, isWarmup: isWarmup) {
            return isWarmup ? .warmup(setData) : .setLogged(setData)
        }
        
        // Try to parse as exercise change
        if let exercise = parseExercise(cleanedText) {
            return .exerciseChanged(exercise)
        }
        
        return .unknown(text)
    }
    
    // MARK: - Same Command Detection
    
    private func isSameCommand(_ text: String) -> Bool {
        let samePatterns = [
            "same", "same again", "again", "repeat", "another",
            "one more", "same thing", "same set"
        ]
        return samePatterns.contains(text)
    }
    
    // MARK: - Flag Parsing
    
    private func parseFlag(_ text: String) -> SetFlag? {
        let flagPatterns: [(patterns: [String], flag: SetFlag)] = [
            (["pain", "painful", "hurts", "hurt", "ouch"], .pain),
            (["failure", "failed", "fail", "couldn't finish"], .failure),
            (["partial", "partials", "partial reps", "half reps"], .partialReps),
            (["drop set", "drop", "dropped"], .dropSet),
            (["paused", "pause", "pause reps"], .paused),
        ]
        
        for (patterns, flag) in flagPatterns {
            if patterns.contains(where: { text.contains($0) }) {
                return flag
            }
        }
        return nil
    }
    
    // MARK: - Warmup Detection
    
    private func extractWarmupPrefix(_ text: String) -> (isWarmup: Bool, cleaned: String) {
        let warmupPrefixes = ["warmup", "warm up", "warm-up", "warming up"]
        
        for prefix in warmupPrefixes {
            if text.hasPrefix(prefix) {
                let cleaned = text.dropFirst(prefix.count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (true, cleaned)
            }
        }
        return (false, text)
    }
    
    // MARK: - Set Data Parsing
    
    /// Parse patterns like:
    /// - "100 for 5"
    /// - "100 times 5"
    /// - "100 x 5"
    /// - "100 by 5"
    /// - "100 5" (weight reps)
    /// - "100kg for 5"
    /// - "225lbs for 8"
    /// - "100 for 5 at 8" (with RPE)
    /// - "100 for 5 rpe 8"
    private func parseSetData(_ text: String, isWarmup: Bool) -> ParseResult.SetData? {
        // Normalize separators
        var normalized = text
            .replacingOccurrences(of: "×", with: "x")
            .replacingOccurrences(of: "*", with: "x")
            .replacingOccurrences(of: " times ", with: " x ")
            .replacingOccurrences(of: " by ", with: " x ")
            .replacingOccurrences(of: " for ", with: " x ")
            .replacingOccurrences(of: " reps", with: "")
        
        // Extract unit if present
        var unit: WeightUnit? = nil
        if normalized.contains("kg") || normalized.contains("kilo") {
            unit = .kg
            normalized = normalized
                .replacingOccurrences(of: "kilograms", with: "")
                .replacingOccurrences(of: "kilos", with: "")
                .replacingOccurrences(of: "kilo", with: "")
                .replacingOccurrences(of: "kg", with: "")
        } else if normalized.contains("lb") || normalized.contains("pound") {
            unit = .lbs
            normalized = normalized
                .replacingOccurrences(of: "pounds", with: "")
                .replacingOccurrences(of: "pound", with: "")
                .replacingOccurrences(of: "lbs", with: "")
                .replacingOccurrences(of: "lb", with: "")
        }
        
        // Extract RPE if present
        var rpe: Double? = nil
        let rpePatterns = [
            #"(?:at|@|rpe)\s*(\d+(?:\.\d+)?)"#,
            #"rpe\s*(\d+(?:\.\d+)?)"#
        ]
        
        for pattern in rpePatterns {
            if let match = normalized.range(of: pattern, options: .regularExpression) {
                let rpeString = normalized[match]
                if let rpeValue = Double(rpeString.filter { $0.isNumber || $0 == "." }) {
                    rpe = min(10, max(1, rpeValue)) // Clamp to 1-10
                }
                normalized.removeSubrange(match)
            }
        }
        
        // Clean up
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to extract weight and reps
        // Pattern: number (x|space) number
        let numberPattern = #"(\d+(?:\.\d+)?)\s*[x\s]\s*(\d+)"#
        
        if let regex = try? NSRegularExpression(pattern: numberPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) {
            
            if let weightRange = Range(match.range(at: 1), in: normalized),
               let repsRange = Range(match.range(at: 2), in: normalized),
               let weight = Double(normalized[weightRange]),
               let reps = Int(normalized[repsRange]) {
                
                return ParseResult.SetData(
                    weight: weight,
                    reps: reps,
                    unit: unit,
                    rpe: rpe,
                    isWarmup: isWarmup
                )
            }
        }
        
        return nil
    }
    
    // MARK: - Exercise Parsing
    
    private func parseExercise(_ text: String) -> String? {
        // Direct match
        if let exercise = exerciseAliases[text] {
            return exercise
        }
        
        // Partial match (for compound phrases like "moving to bench")
        for (alias, exercise) in exerciseAliases {
            if text.contains(alias) {
                return exercise
            }
        }
        
        // If it looks like a single word or two-word phrase that could be an exercise,
        // return it as-is (custom exercise)
        let words = text.split(separator: " ")
        if words.count <= 3 && !text.contains(where: { $0.isNumber }) {
            return text.capitalized
        }
        
        return nil
    }
    
    // MARK: - Learning (Future)
    
    /// Add a custom exercise alias
    func learnAlias(_ alias: String, for exercise: String) {
        exerciseAliases[alias.lowercased()] = exercise
    }
}
