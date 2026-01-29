import XCTest
@testable import Callout

/// Tests for WorkoutModels - data structures and computed properties
@MainActor
final class WorkoutModelsTests: XCTestCase {
    
    // MARK: - WorkSet Tests
    
    func testWorkSetVolume() {
        let set = WorkSet(weight: 100, reps: 5)
        XCTAssertEqual(set.volume, 500)
    }
    
    func testWorkSetVolumeDecimal() {
        let set = WorkSet(weight: 102.5, reps: 8)
        XCTAssertEqual(set.volume, 820)
    }
    
    func testWorkSetDefaultValues() {
        let set = WorkSet(weight: 100, reps: 5)
        XCTAssertNil(set.rpe)
        XCTAssertNil(set.rir)
        XCTAssertFalse(set.isWarmup)
        XCTAssertFalse(set.isPending)
        XCTAssertTrue(set.flags.isEmpty)
    }
    
    func testWorkSetWithFlags() {
        let set = WorkSet(weight: 100, reps: 5, flags: [.pain, .failure])
        XCTAssertEqual(set.flags.count, 2)
        XCTAssertTrue(set.flags.contains(.pain))
        XCTAssertTrue(set.flags.contains(.failure))
    }
    
    func testWorkSetWarmup() {
        let set = WorkSet(weight: 60, reps: 10, isWarmup: true)
        XCTAssertTrue(set.isWarmup)
    }
    
    func testWorkSetPending() {
        let set = WorkSet(weight: 0, reps: 0, isPending: true)
        XCTAssertTrue(set.isPending)
    }
    
    // MARK: - ExerciseSession Tests
    
    func testExerciseSessionTotalVolume() {
        let exercise = Exercise(name: "Bench Press")
        var session = ExerciseSession(exercise: exercise)
        
        session.sets = [
            WorkSet(weight: 100, reps: 5),  // 500
            WorkSet(weight: 100, reps: 5),  // 500
            WorkSet(weight: 100, reps: 5),  // 500
        ]
        
        XCTAssertEqual(session.totalVolume, 1500)
    }
    
    func testExerciseSessionTopSet() {
        let exercise = Exercise(name: "Squat")
        var session = ExerciseSession(exercise: exercise)
        
        session.sets = [
            WorkSet(weight: 100, reps: 5),   // 500
            WorkSet(weight: 120, reps: 3),   // 360
            WorkSet(weight: 110, reps: 5),   // 550 - highest volume
        ]
        
        let topSet = session.topSet
        XCTAssertNotNil(topSet)
        XCTAssertEqual(topSet?.weight, 110)
        XCTAssertEqual(topSet?.reps, 5)
    }
    
    func testExerciseSessionTopSetEmpty() {
        let exercise = Exercise(name: "Deadlift")
        let session = ExerciseSession(exercise: exercise)
        
        XCTAssertNil(session.topSet)
    }
    
    // MARK: - Workout Tests
    
    func testWorkoutTotalVolume() {
        var workout = Workout()
        
        let bench = Exercise(name: "Bench Press")
        var benchSession = ExerciseSession(exercise: bench)
        benchSession.sets = [
            WorkSet(weight: 100, reps: 5),  // 500
            WorkSet(weight: 100, reps: 5),  // 500
        ]
        
        let squat = Exercise(name: "Squat")
        var squatSession = ExerciseSession(exercise: squat)
        squatSession.sets = [
            WorkSet(weight: 140, reps: 5),  // 700
        ]
        
        workout.exercises = [benchSession, squatSession]
        
        XCTAssertEqual(workout.totalVolume, 1700)
    }
    
    func testWorkoutTotalSets() {
        var workout = Workout()
        
        let bench = Exercise(name: "Bench Press")
        var benchSession = ExerciseSession(exercise: bench)
        benchSession.sets = [
            WorkSet(weight: 100, reps: 5),
            WorkSet(weight: 100, reps: 5),
            WorkSet(weight: 100, reps: 5),
        ]
        
        let squat = Exercise(name: "Squat")
        var squatSession = ExerciseSession(exercise: squat)
        squatSession.sets = [
            WorkSet(weight: 140, reps: 5),
            WorkSet(weight: 140, reps: 5),
        ]
        
        workout.exercises = [benchSession, squatSession]
        
        XCTAssertEqual(workout.totalSets, 5)
    }
    
    func testWorkoutEmptyTotals() {
        let workout = Workout()
        
        XCTAssertEqual(workout.totalVolume, 0)
        XCTAssertEqual(workout.totalSets, 0)
    }
    
    // MARK: - Exercise Tests
    
    func testExerciseEquatable() {
        let exercise1 = Exercise(name: "Bench Press")
        let exercise2 = Exercise(name: "Bench Press")
        
        // Different IDs, so not equal by default
        XCTAssertNotEqual(exercise1.id, exercise2.id)
        
        // But names match
        XCTAssertEqual(exercise1.name, exercise2.name)
    }
    
    func testExerciseDefaultCategory() {
        let exercise = Exercise(name: "Custom Exercise")
        XCTAssertEqual(exercise.category, .other)
        XCTAssertFalse(exercise.isCustom)
    }
    
    // MARK: - SetFlag Tests
    
    func testSetFlagDisplayNames() {
        XCTAssertEqual(SetFlag.pain.displayName, "Pain")
        XCTAssertEqual(SetFlag.failure.displayName, "Failure")
        XCTAssertEqual(SetFlag.partialReps.displayName, "Partials")
        XCTAssertEqual(SetFlag.dropSet.displayName, "Drop Set")
        XCTAssertEqual(SetFlag.paused.displayName, "Paused")
    }
    
    func testSetFlagEmojis() {
        XCTAssertEqual(SetFlag.pain.emoji, "⚠️")
        XCTAssertEqual(SetFlag.failure.emoji, "💀")
        XCTAssertEqual(SetFlag.partialReps.emoji, "½")
        XCTAssertEqual(SetFlag.dropSet.emoji, "⬇️")
        XCTAssertEqual(SetFlag.paused.emoji, "⏸️")
    }
    
    // MARK: - ExerciseCategory Tests
    
    func testExerciseCategoryDisplayNames() {
        XCTAssertEqual(ExerciseCategory.chest.displayName, "Chest")
        XCTAssertEqual(ExerciseCategory.back.displayName, "Back")
        XCTAssertEqual(ExerciseCategory.shoulders.displayName, "Shoulders")
        XCTAssertEqual(ExerciseCategory.legs.displayName, "Legs")
    }
    
    func testExerciseCategoryCaseIterable() {
        // Ensure we have all expected categories
        let categories = ExerciseCategory.allCases
        XCTAssertTrue(categories.contains(.chest))
        XCTAssertTrue(categories.contains(.back))
        XCTAssertTrue(categories.contains(.shoulders))
        XCTAssertTrue(categories.contains(.biceps))
        XCTAssertTrue(categories.contains(.triceps))
        XCTAssertTrue(categories.contains(.legs))
        XCTAssertTrue(categories.contains(.core))
        XCTAssertTrue(categories.contains(.cardio))
        XCTAssertTrue(categories.contains(.other))
    }
    
    // MARK: - Codable Tests
    
    func testWorkSetCodable() throws {
        let set = WorkSet(weight: 100, reps: 5, rpe: 8.5, isWarmup: false, flags: [.pain])
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(set)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WorkSet.self, from: data)
        
        XCTAssertEqual(decoded.weight, set.weight)
        XCTAssertEqual(decoded.reps, set.reps)
        XCTAssertEqual(decoded.rpe, set.rpe)
        XCTAssertEqual(decoded.isWarmup, set.isWarmup)
        XCTAssertEqual(decoded.flags, set.flags)
    }
    
    func testWorkoutCodable() throws {
        var workout = Workout()
        let exercise = Exercise(name: "Test Exercise")
        var session = ExerciseSession(exercise: exercise)
        session.sets = [WorkSet(weight: 100, reps: 5)]
        workout.exercises = [session]
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(workout)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Workout.self, from: data)
        
        XCTAssertEqual(decoded.exercises.count, 1)
        XCTAssertEqual(decoded.exercises[0].exercise.name, "Test Exercise")
        XCTAssertEqual(decoded.exercises[0].sets.count, 1)
    }
}
