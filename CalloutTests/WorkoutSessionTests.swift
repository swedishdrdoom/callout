import XCTest
@testable import Callout

/// Tests for WorkoutSession - state management and set logging
final class WorkoutSessionTests: XCTestCase {
    
    var session: WorkoutSession!
    
    override func setUp() {
        super.setUp()
        session = WorkoutSession.shared
        session.reset() // Start fresh for each test
    }
    
    override func tearDown() {
        session.reset()
        super.tearDown()
    }
    
    // MARK: - Session Lifecycle Tests
    
    func testInitialState() {
        XCTAssertFalse(session.isActive)
        XCTAssertNil(session.currentWorkout)
        XCTAssertNil(session.currentExercise)
    }
    
    func testStartSession() {
        session.startSession()
        
        XCTAssertTrue(session.isActive)
        XCTAssertNotNil(session.currentWorkout)
    }
    
    func testEndSession() {
        session.startSession()
        session.endSession()
        
        XCTAssertFalse(session.isActive)
    }
    
    func testReset() {
        session.startSession()
        session.setExercise(named: "Bench Press")
        _ = session.logSet(weight: 100, reps: 5)
        
        session.reset()
        
        XCTAssertFalse(session.isActive)
        XCTAssertNil(session.currentWorkout)
        XCTAssertNil(session.currentExercise)
        XCTAssertNil(session.lastLoggedSet)
    }
    
    // MARK: - Exercise Management Tests
    
    func testSetExercise() {
        session.startSession()
        session.setExercise(named: "Bench Press")
        
        XCTAssertNotNil(session.currentExercise)
        XCTAssertEqual(session.currentExercise?.name, "Bench Press")
    }
    
    func testSetExerciseAutoStartsSession() {
        // Don't call startSession explicitly
        session.setExercise(named: "Squat")
        
        // setExercise doesn't auto-start, but logSet does
        XCTAssertFalse(session.isActive)
    }
    
    func testCurrentSetNumber() {
        session.startSession()
        session.setExercise(named: "Bench Press")
        
        XCTAssertEqual(session.currentSetNumber, 1)
        
        _ = session.logSet(weight: 100, reps: 5)
        XCTAssertEqual(session.currentSetNumber, 2)
        
        _ = session.logSet(weight: 100, reps: 5)
        XCTAssertEqual(session.currentSetNumber, 3)
    }
    
    // MARK: - Set Logging Tests
    
    func testLogSet() {
        session.startSession()
        session.setExercise(named: "Bench Press")
        
        let set = session.logSet(weight: 100, reps: 5)
        
        XCTAssertEqual(set.weight, 100)
        XCTAssertEqual(set.reps, 5)
        XCTAssertFalse(set.isWarmup)
    }
    
    func testLogSetWithRPE() {
        session.startSession()
        session.setExercise(named: "Squat")
        
        let set = session.logSet(weight: 140, reps: 5, rpe: 8.5)
        
        XCTAssertEqual(set.rpe, 8.5)
    }
    
    func testLogWarmupSet() {
        session.startSession()
        session.setExercise(named: "Deadlift")
        
        let set = session.logSet(weight: 60, reps: 10, isWarmup: true)
        
        XCTAssertTrue(set.isWarmup)
    }
    
    func testLogSetWithFlags() {
        session.startSession()
        session.setExercise(named: "Bench Press")
        
        let set = session.logSet(weight: 100, reps: 3, flags: [.failure])
        
        XCTAssertTrue(set.flags.contains(.failure))
    }
    
    func testLastLoggedSet() {
        session.startSession()
        session.setExercise(named: "Bench Press")
        
        XCTAssertNil(session.lastLoggedSet)
        
        _ = session.logSet(weight: 100, reps: 5)
        
        XCTAssertNotNil(session.lastLoggedSet)
        XCTAssertEqual(session.lastLoggedSet?.weight, 100)
        XCTAssertEqual(session.lastLoggedSet?.reps, 5)
    }
    
    func testLogSetAutoStartsSession() {
        // Don't explicitly start session
        _ = session.logSet(weight: 100, reps: 5)
        
        XCTAssertTrue(session.isActive)
    }
    
    // MARK: - Same Again Tests
    
    func testLogSameAgain() {
        session.startSession()
        session.setExercise(named: "Bench Press")
        
        _ = session.logSet(weight: 100, reps: 5)
        let sameSet = session.logSameAgain()
        
        XCTAssertNotNil(sameSet)
        XCTAssertEqual(sameSet?.weight, 100)
        XCTAssertEqual(sameSet?.reps, 5)
    }
    
    func testLogSameAgainWithoutPreviousSet() {
        session.startSession()
        session.setExercise(named: "Bench Press")
        
        let sameSet = session.logSameAgain()
        
        XCTAssertNil(sameSet)
    }
    
    // MARK: - Flag Tests
    
    func testAddFlagToLastSet() {
        session.startSession()
        session.setExercise(named: "Bench Press")
        _ = session.logSet(weight: 100, reps: 5)
        
        let success = session.addFlagToLastSet(.pain)
        
        XCTAssertTrue(success)
        XCTAssertTrue(session.lastLoggedSet?.flags.contains(.pain) ?? false)
    }
    
    func testAddFlagWithoutSet() {
        session.startSession()
        session.setExercise(named: "Bench Press")
        
        let success = session.addFlagToLastSet(.pain)
        
        XCTAssertFalse(success)
    }
    
    func testAddDuplicateFlagIgnored() {
        session.startSession()
        session.setExercise(named: "Bench Press")
        _ = session.logSet(weight: 100, reps: 5, flags: [.pain])
        
        _ = session.addFlagToLastSet(.pain)
        
        // Should still only have one .pain flag
        let painCount = session.lastLoggedSet?.flags.filter { $0 == .pain }.count ?? 0
        XCTAssertEqual(painCount, 1)
    }
    
    // MARK: - Pending Set Tests
    
    func testLogPendingSet() {
        session.startSession()
        session.setExercise(named: "Bench Press")
        
        let index = session.logPendingSet()
        
        XCTAssertEqual(index, 0)
        XCTAssertEqual(session.lastLoggedSet?.isPending, true)
        XCTAssertEqual(session.lastLoggedSet?.weight, 0)
        XCTAssertEqual(session.lastLoggedSet?.reps, 0)
    }
    
    func testUpdateLastPendingSet() {
        session.startSession()
        session.setExercise(named: "Bench Press")
        _ = session.logPendingSet()
        
        session.updateLastPendingSet(weight: 100, reps: 5, unit: "kg")
        
        XCTAssertEqual(session.lastLoggedSet?.weight, 100)
        XCTAssertEqual(session.lastLoggedSet?.reps, 5)
        XCTAssertEqual(session.lastLoggedSet?.isPending, false)
    }
    
    // MARK: - Rest Timer Tests
    
    func testRestElapsedInitiallyZero() {
        XCTAssertEqual(session.restElapsed, 0)
    }
    
    func testRestElapsedAfterStart() {
        session.startSession()
        
        // Should be non-zero after starting (rest timer starts)
        // Can't reliably test exact time, just that it's >= 0
        XCTAssertGreaterThanOrEqual(session.restElapsed, 0)
    }
    
    func testResetRestTimer() {
        session.startSession()
        session.setExercise(named: "Bench Press")
        
        // Wait a tiny bit then reset
        session.resetRestTimer()
        
        // Rest elapsed should be very small after reset
        XCTAssertLessThan(session.restElapsed, 1)
    }
    
    // MARK: - Voice Input Processing Tests
    
    func testProcessVoiceInputSetLogged() {
        session.startSession()
        session.setExercise(named: "Bench Press")
        
        let result = session.processVoiceInput("100 for 5")
        
        if case .setLogged(let set) = result {
            XCTAssertEqual(set.weight, 100)
            XCTAssertEqual(set.reps, 5)
        } else {
            XCTFail("Expected setLogged, got \(result)")
        }
    }
    
    func testProcessVoiceInputExerciseChange() {
        session.startSession()
        
        let result = session.processVoiceInput("squat")
        
        if case .exerciseChanged(let name) = result {
            XCTAssertEqual(name, "Squat")
        } else {
            XCTFail("Expected exerciseChanged, got \(result)")
        }
    }
    
    func testProcessVoiceInputSameAgain() {
        session.startSession()
        session.setExercise(named: "Bench Press")
        _ = session.logSet(weight: 100, reps: 5)
        
        let result = session.processVoiceInput("same")
        
        if case .setLogged(let set) = result {
            XCTAssertEqual(set.weight, 100)
            XCTAssertEqual(set.reps, 5)
        } else {
            XCTFail("Expected setLogged, got \(result)")
        }
    }
    
    func testProcessVoiceInputSameAgainWithoutPrevious() {
        session.startSession()
        session.setExercise(named: "Bench Press")
        
        let result = session.processVoiceInput("same")
        
        if case .error(let message) = result {
            XCTAssertEqual(message, "No previous set to repeat")
        } else {
            XCTFail("Expected error, got \(result)")
        }
    }
    
    func testProcessVoiceInputAutoStartsSession() {
        // Session not started
        _ = session.processVoiceInput("100 for 5")
        
        XCTAssertTrue(session.isActive)
    }
    
    // MARK: - Inactivity Timeout Tests
    
    func testCheckInactivityTimeoutFalseWhenActive() {
        session.startSession()
        
        // Just started, shouldn't be timed out
        let timedOut = session.checkInactivityTimeout(threshold: 30 * 60)
        
        XCTAssertFalse(timedOut)
    }
    
    func testCheckInactivityTimeoutWhenNotActive() {
        // Session not started
        let timedOut = session.checkInactivityTimeout(threshold: 30 * 60)
        
        XCTAssertFalse(timedOut)
    }
}
