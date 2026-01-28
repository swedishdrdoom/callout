import Foundation

// MARK: - Core Models

struct Workout: Identifiable, Codable, Sendable {
    let id: UUID
    var startedAt: Date
    var endedAt: Date?
    var exercises: [ExerciseSession]
    var notes: String?
    
    init(id: UUID = UUID(), startedAt: Date = Date()) {
        self.id = id
        self.startedAt = startedAt
        self.exercises = []
    }
    
    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.totalVolume }
    }
    
    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
}

struct ExerciseSession: Identifiable, Codable, Sendable {
    let id: UUID
    let exercise: Exercise
    var sets: [WorkSet]
    
    init(id: UUID = UUID(), exercise: Exercise, sets: [WorkSet] = []) {
        self.id = id
        self.exercise = exercise
        self.sets = sets
    }
    
    var totalVolume: Double {
        sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
    
    var topSet: WorkSet? {
        sets.max(by: { ($0.weight * Double($0.reps)) < ($1.weight * Double($1.reps)) })
    }
}

struct Exercise: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var category: ExerciseCategory
    var isCustom: Bool
    
    init(id: UUID = UUID(), name: String, category: ExerciseCategory = .other, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.category = category
        self.isCustom = isCustom
    }
}

enum ExerciseCategory: String, Codable, CaseIterable {
    case chest, back, shoulders, biceps, triceps, legs, core, cardio, other
    
    var displayName: String {
        rawValue.capitalized
    }
}

struct WorkSet: Identifiable, Codable, Sendable {
    let id: UUID
    var weight: Double
    var reps: Int
    var rpe: Double?
    var rir: Int?
    var isWarmup: Bool
    var isPending: Bool  // True until backend confirms interpretation
    var timestamp: Date
    var flags: [SetFlag]
    
    init(
        id: UUID = UUID(),
        weight: Double,
        reps: Int,
        rpe: Double? = nil,
        rir: Int? = nil,
        isWarmup: Bool = false,
        isPending: Bool = false,
        timestamp: Date = Date(),
        flags: [SetFlag] = []
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.rir = rir
        self.isWarmup = isWarmup
        self.isPending = isPending
        self.timestamp = timestamp
        self.flags = flags
    }
    
    var volume: Double {
        weight * Double(reps)
    }
}

enum SetFlag: String, Codable, CaseIterable {
    case pain
    case failure
    case partialReps
    case dropSet
    case paused
    
    var displayName: String {
        switch self {
        case .pain: return "Pain"
        case .failure: return "Failure"
        case .partialReps: return "Partials"
        case .dropSet: return "Drop Set"
        case .paused: return "Paused"
        }
    }
    
    var emoji: String {
        switch self {
        case .pain: return "⚠️"
        case .failure: return "💀"
        case .partialReps: return "½"
        case .dropSet: return "⬇️"
        case .paused: return "⏸️"
        }
    }
}

// MARK: - Ghost Data (Previous Session)

struct GhostSet {
    let weight: Double
    let reps: Int
    let wasPersonalRecord: Bool
}

// MARK: - Sample Data

extension Exercise {
    static let benchPress = Exercise(name: "Bench Press", category: .chest)
    static let squat = Exercise(name: "Squat", category: .legs)
    static let deadlift = Exercise(name: "Deadlift", category: .back)
    static let overheadPress = Exercise(name: "Overhead Press", category: .shoulders)
    static let barbellRow = Exercise(name: "Barbell Row", category: .back)
    static let pullUp = Exercise(name: "Pull Up", category: .back)
    
    static let commonExercises: [Exercise] = [
        .benchPress, .squat, .deadlift, .overheadPress, .barbellRow, .pullUp
    ]
}
