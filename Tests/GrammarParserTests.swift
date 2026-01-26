//
//  GrammarParserTests.swift
//  CalloutTests
//
//  Comprehensive tests for the voice grammar parser.
//

import XCTest
@testable import Callout

final class GrammarParserTests: XCTestCase {
    
    var parser: GrammarParser!
    
    override func setUp() {
        super.setUp()
        parser = GrammarParser()
    }
    
    override func tearDown() {
        parser = nil
        super.tearDown()
    }
    
    // MARK: - Full Set Log Tests
    
    func testBasicSetLog() {
        // "Bench 225 for 5"
        let result = parser.parse("Bench 225 for 5")
        
        guard case .logSet(let cmd) = result else {
            XCTFail("Expected LogSetCommand, got \(result)")
            return
        }
        
        XCTAssertEqual(cmd.exercise, "bench")
        XCTAssertEqual(cmd.weight.value, 225)
        XCTAssertNil(cmd.weight.unit)
        XCTAssertEqual(cmd.reps.count, 5)
        XCTAssertTrue(cmd.modifiers.isEmpty)
        XCTAssertGreaterThan(cmd.confidence, 0.9)
    }
    
    func testSetLogWithUnit() {
        // "Squat 100 kg for 8"
        let result = parser.parse("Squat 100 kg for 8")
        
        guard case .logSet(let cmd) = result else {
            XCTFail("Expected LogSetCommand, got \(result)")
            return
        }
        
        XCTAssertEqual(cmd.exercise, "squat")
        XCTAssertEqual(cmd.weight.value, 100)
        XCTAssertEqual(cmd.weight.unit, .kilograms)
        XCTAssertEqual(cmd.reps.count, 8)
    }
    
    func testSetLogWithPounds() {
        let result = parser.parse("Deadlift 315 lbs for 3")
        
        guard case .logSet(let cmd) = result else {
            XCTFail("Expected LogSetCommand")
            return
        }
        
        XCTAssertEqual(cmd.exercise, "deadlift")
        XCTAssertEqual(cmd.weight.value, 315)
        XCTAssertEqual(cmd.weight.unit, .pounds)
        XCTAssertEqual(cmd.reps.count, 3)
    }
    
    func testSetLogWithoutExercise() {
        // "135 for 10" (continuing previous exercise)
        let result = parser.parse("135 for 10")
        
        guard case .logSet(let cmd) = result else {
            XCTFail("Expected LogSetCommand")
            return
        }
        
        XCTAssertNil(cmd.exercise)
        XCTAssertEqual(cmd.weight.value, 135)
        XCTAssertEqual(cmd.reps.count, 10)
    }
    
    func testSetLogWithModifiers() {
        // "Bench 185 for 8 easy warmup"
        let result = parser.parse("Bench 185 for 8 easy warmup")
        
        guard case .logSet(let cmd) = result else {
            XCTFail("Expected LogSetCommand")
            return
        }
        
        XCTAssertEqual(cmd.exercise, "bench")
        XCTAssertEqual(cmd.weight.value, 185)
        XCTAssertEqual(cmd.reps.count, 8)
        XCTAssertEqual(cmd.modifiers.count, 2)
        XCTAssertTrue(cmd.modifiers.contains(.easy))
        XCTAssertTrue(cmd.modifiers.contains(.warmup))
    }
    
    func testSetLogWithFailed() {
        // "Bench 225 for 5 failed at 4"
        let result = parser.parse("Bench 225 for 5 failed at 4")
        
        guard case .logSet(let cmd) = result else {
            XCTFail("Expected LogSetCommand")
            return
        }
        
        XCTAssertEqual(cmd.reps.count, 5)
        XCTAssertEqual(cmd.modifiers.count, 1)
        
        guard case .failed(let atRep) = cmd.modifiers.first else {
            XCTFail("Expected failed modifier")
            return
        }
        XCTAssertEqual(atRep, 4)
    }
    
    func testSetLogWithRPE() {
        // "Squat 315 for 5 rpe 8"
        let result = parser.parse("Squat 315 for 5 rpe 8")
        
        guard case .logSet(let cmd) = result else {
            XCTFail("Expected LogSetCommand")
            return
        }
        
        XCTAssertEqual(cmd.modifiers.count, 1)
        guard case .rpe(let rpe) = cmd.modifiers.first else {
            XCTFail("Expected RPE modifier")
            return
        }
        XCTAssertEqual(rpe.value, 8)
    }
    
    func testSetLogWithHard() {
        let result = parser.parse("Bench 225 for 5 hard")
        
        guard case .logSet(let cmd) = result else {
            XCTFail("Expected LogSetCommand")
            return
        }
        
        XCTAssertTrue(cmd.modifiers.contains(.hard))
    }
    
    func testMultiWordExercise() {
        // "Incline bench press 185 for 8"
        let result = parser.parse("Incline bench press 185 for 8")
        
        guard case .logSet(let cmd) = result else {
            XCTFail("Expected LogSetCommand")
            return
        }
        
        XCTAssertEqual(cmd.exercise, "incline bench press")
        XCTAssertEqual(cmd.weight.value, 185)
    }
    
    func testSetLogWithRepsKeyword() {
        // "Bench 135 for 12 reps"
        let result = parser.parse("Bench 135 for 12 reps")
        
        guard case .logSet(let cmd) = result else {
            XCTFail("Expected LogSetCommand")
            return
        }
        
        XCTAssertEqual(cmd.reps.count, 12)
    }
    
    // MARK: - Same Again Tests
    
    func testSameAgain() {
        let result = parser.parse("Same again")
        
        guard case .sameAgain(let cmd) = result else {
            XCTFail("Expected SameAgainCommand, got \(result)")
            return
        }
        
        XCTAssertEqual(cmd.confidence, 1.0)
    }
    
    func testSameOnly() {
        let result = parser.parse("Same")
        
        guard case .sameAgain(let cmd) = result else {
            XCTFail("Expected SameAgainCommand")
            return
        }
        
        XCTAssertEqual(cmd.confidence, 0.95)
    }
    
    func testSameCaseInsensitive() {
        let result = parser.parse("SAME AGAIN")
        
        guard case .sameAgain(_) = result else {
            XCTFail("Expected SameAgainCommand")
            return
        }
    }
    
    // MARK: - Delta Command Tests
    
    func testPlusDelta() {
        let result = parser.parse("Plus 5")
        
        guard case .weightDelta(let cmd) = result else {
            XCTFail("Expected WeightDeltaCommand, got \(result)")
            return
        }
        
        XCTAssertEqual(cmd.direction, .add)
        XCTAssertEqual(cmd.delta.value, 5)
    }
    
    func testAddDelta() {
        let result = parser.parse("Add 2.5 kg")
        
        guard case .weightDelta(let cmd) = result else {
            XCTFail("Expected WeightDeltaCommand")
            return
        }
        
        XCTAssertEqual(cmd.direction, .add)
        XCTAssertEqual(cmd.delta.value, 2.5)
        XCTAssertEqual(cmd.delta.unit, .kilograms)
    }
    
    func testMinusDelta() {
        let result = parser.parse("Minus 10")
        
        guard case .weightDelta(let cmd) = result else {
            XCTFail("Expected WeightDeltaCommand")
            return
        }
        
        XCTAssertEqual(cmd.direction, .subtract)
        XCTAssertEqual(cmd.delta.value, 10)
    }
    
    func testDropDelta() {
        let result = parser.parse("Drop 20 lbs")
        
        guard case .weightDelta(let cmd) = result else {
            XCTFail("Expected WeightDeltaCommand")
            return
        }
        
        XCTAssertEqual(cmd.direction, .subtract)
        XCTAssertEqual(cmd.delta.value, 20)
        XCTAssertEqual(cmd.delta.unit, .pounds)
    }
    
    func testPlusDecimal() {
        let result = parser.parse("Plus 2.5")
        
        guard case .weightDelta(let cmd) = result else {
            XCTFail("Expected WeightDeltaCommand")
            return
        }
        
        XCTAssertEqual(cmd.delta.value, 2.5)
    }
    
    // MARK: - Standalone Modifier Tests
    
    func testFailedStandalone() {
        let result = parser.parse("Failed")
        
        guard case .modifier(let cmd) = result else {
            XCTFail("Expected ModifierCommand, got \(result)")
            return
        }
        
        guard case .failed(let atRep) = cmd.modifier else {
            XCTFail("Expected failed modifier")
            return
        }
        XCTAssertNil(atRep)
    }
    
    func testFailedAtRep() {
        let result = parser.parse("Failed at 4")
        
        guard case .modifier(let cmd) = result else {
            XCTFail("Expected ModifierCommand")
            return
        }
        
        guard case .failed(let atRep) = cmd.modifier else {
            XCTFail("Expected failed modifier")
            return
        }
        XCTAssertEqual(atRep, 4)
    }
    
    func testEasyStandalone() {
        let result = parser.parse("Easy")
        
        guard case .modifier(let cmd) = result else {
            XCTFail("Expected ModifierCommand")
            return
        }
        
        XCTAssertEqual(cmd.modifier, .easy)
    }
    
    func testHardStandalone() {
        let result = parser.parse("Hard")
        
        guard case .modifier(let cmd) = result else {
            XCTFail("Expected ModifierCommand")
            return
        }
        
        XCTAssertEqual(cmd.modifier, .hard)
    }
    
    func testWarmupStandalone() {
        let result = parser.parse("Warmup")
        
        guard case .modifier(let cmd) = result else {
            XCTFail("Expected ModifierCommand")
            return
        }
        
        XCTAssertEqual(cmd.modifier, .warmup)
    }
    
    func testWarmUpTwoWords() {
        let result = parser.parse("Warm up")
        
        guard case .modifier(let cmd) = result else {
            XCTFail("Expected ModifierCommand")
            return
        }
        
        XCTAssertEqual(cmd.modifier, .warmup)
    }
    
    func testRPEStandalone() {
        let result = parser.parse("RPE 9")
        
        guard case .modifier(let cmd) = result else {
            XCTFail("Expected ModifierCommand")
            return
        }
        
        guard case .rpe(let rpe) = cmd.modifier else {
            XCTFail("Expected RPE modifier")
            return
        }
        XCTAssertEqual(rpe.value, 9)
    }
    
    func testPainModifier() {
        let result = parser.parse("Shoulder pain")
        
        guard case .modifier(let cmd) = result else {
            XCTFail("Expected ModifierCommand, got \(result)")
            return
        }
        
        guard case .pain(let bodyPart) = cmd.modifier else {
            XCTFail("Expected pain modifier")
            return
        }
        XCTAssertEqual(bodyPart, .shoulder)
    }
    
    // MARK: - Rep Change Tests
    
    func testRepChange() {
        let result = parser.parse("5 reps")
        
        guard case .repChange(let cmd) = result else {
            XCTFail("Expected RepChangeCommand, got \(result)")
            return
        }
        
        XCTAssertEqual(cmd.reps.count, 5)
    }
    
    func testRepChangeSingular() {
        let result = parser.parse("8 rep")
        
        guard case .repChange(let cmd) = result else {
            XCTFail("Expected RepChangeCommand")
            return
        }
        
        XCTAssertEqual(cmd.reps.count, 8)
    }
    
    // MARK: - Exercise Change Tests
    
    func testKnownExerciseChange() {
        let result = parser.parse("Deadlift")
        
        guard case .exerciseChange(let cmd) = result else {
            XCTFail("Expected ExerciseChangeCommand, got \(result)")
            return
        }
        
        XCTAssertEqual(cmd.exercise, "deadlift")
        XCTAssertGreaterThan(cmd.confidence, 0.8)
    }
    
    func testMultiWordExerciseChange() {
        let result = parser.parse("Incline bench")
        
        guard case .exerciseChange(let cmd) = result else {
            XCTFail("Expected ExerciseChangeCommand")
            return
        }
        
        XCTAssertEqual(cmd.exercise, "incline bench")
    }
    
    // MARK: - Edge Cases & Error Handling
    
    func testEmptyInput() {
        let result = parser.parse("")
        
        guard case .unknown(_) = result else {
            XCTFail("Expected UnknownCommand for empty input")
            return
        }
    }
    
    func testWhitespaceOnly() {
        let result = parser.parse("   ")
        
        guard case .unknown(_) = result else {
            XCTFail("Expected UnknownCommand for whitespace input")
            return
        }
    }
    
    func testGibberish() {
        let result = parser.parse("asdfghjkl qwerty")
        
        guard case .unknown(let cmd) = result else {
            XCTFail("Expected UnknownCommand")
            return
        }
        
        XCTAssertEqual(cmd.confidence, 0.0)
    }
    
    func testPartialSetLog() {
        // Missing "for" keyword
        let result = parser.parse("Bench 225")
        
        // Should not parse as set log, might be unknown or exercise change
        if case .logSet(_) = result {
            XCTFail("Should not parse incomplete set as LogSetCommand")
        }
    }
    
    func testUnknownExercise() {
        // Unknown exercise should still parse with lower confidence
        let result = parser.parse("Flobberwobblers 135 for 10")
        
        guard case .logSet(let cmd) = result else {
            XCTFail("Expected LogSetCommand for unknown exercise")
            return
        }
        
        XCTAssertEqual(cmd.exercise, "flobberwobblers")
        // Confidence should be lower for unknown exercise
        XCTAssertLessThan(cmd.confidence, 1.0)
    }
    
    func testNumbersAsText() {
        // "Bench one thirty five for five"
        let result = parser.parse("Bench five for three")
        
        guard case .logSet(let cmd) = result else {
            XCTFail("Expected LogSetCommand")
            return
        }
        
        XCTAssertEqual(cmd.weight.value, 5)
        XCTAssertEqual(cmd.reps.count, 3)
    }
    
    func testMixedNumberFormats() {
        let result = parser.parse("Squat 100 for five")
        
        guard case .logSet(let cmd) = result else {
            XCTFail("Expected LogSetCommand")
            return
        }
        
        XCTAssertEqual(cmd.weight.value, 100)
        XCTAssertEqual(cmd.reps.count, 5)
    }
    
    func testPunctuationHandling() {
        let result = parser.parse("Bench 225 for 5!")
        
        guard case .logSet(let cmd) = result else {
            XCTFail("Expected LogSetCommand")
            return
        }
        
        XCTAssertEqual(cmd.reps.count, 5)
    }
    
    func testCommaInNumber() {
        // Some voice transcriptions might include "225, for 5"
        let result = parser.parse("Bench 225, for 5")
        
        guard case .logSet(let cmd) = result else {
            XCTFail("Expected LogSetCommand")
            return
        }
        
        XCTAssertEqual(cmd.weight.value, 225)
    }
    
    // MARK: - Compound Scenarios
    
    func testFullWorkingSet() {
        // Typical working set with multiple modifiers
        let result = parser.parse("Squat 315 for 5 reps hard rpe 9")
        
        guard case .logSet(let cmd) = result else {
            XCTFail("Expected LogSetCommand")
            return
        }
        
        XCTAssertEqual(cmd.exercise, "squat")
        XCTAssertEqual(cmd.weight.value, 315)
        XCTAssertEqual(cmd.reps.count, 5)
        XCTAssertTrue(cmd.modifiers.contains(.hard))
        XCTAssertTrue(cmd.modifiers.contains(where: { 
            if case .rpe(_) = $0 { return true }
            return false
        }))
    }
    
    func testWarmupSet() {
        let result = parser.parse("135 for 10 warmup easy")
        
        guard case .logSet(let cmd) = result else {
            XCTFail("Expected LogSetCommand")
            return
        }
        
        XCTAssertNil(cmd.exercise)
        XCTAssertTrue(cmd.modifiers.contains(.warmup))
        XCTAssertTrue(cmd.modifiers.contains(.easy))
    }
    
    func testFailedSet() {
        let result = parser.parse("Bench 245 for 5 failed at 3")
        
        guard case .logSet(let cmd) = result else {
            XCTFail("Expected LogSetCommand")
            return
        }
        
        guard case .failed(let atRep) = cmd.modifiers.first else {
            XCTFail("Expected failed modifier")
            return
        }
        XCTAssertEqual(atRep, 3)
    }
    
    // MARK: - Convenience Method Tests
    
    func testParseAsSet() {
        let cmd = parser.parseAsSet("Bench 225 for 5")
        
        XCTAssertNotNil(cmd)
        XCTAssertEqual(cmd?.exercise, "bench")
    }
    
    func testParseAsSetReturnsNil() {
        let cmd = parser.parseAsSet("Same again")
        
        XCTAssertNil(cmd)
    }
    
    func testParseAsDelta() {
        let cmd = parser.parseAsDelta("Plus 5")
        
        XCTAssertNotNil(cmd)
        XCTAssertEqual(cmd?.delta.value, 5)
    }
    
    func testIsSameAgain() {
        XCTAssertTrue(parser.isSameAgain("Same again"))
        XCTAssertTrue(parser.isSameAgain("Same"))
        XCTAssertFalse(parser.isSameAgain("Plus 5"))
    }
    
    // MARK: - Description Tests
    
    func testLogSetDescription() {
        let cmd = LogSetCommand(
            exercise: "bench",
            weight: Weight(value: 225, unit: .pounds),
            reps: Reps(5),
            modifiers: [.hard]
        )
        
        XCTAssertEqual(cmd.description, "bench 225 lbs for 5 reps hard")
    }
    
    func testWeightDeltaDescription() {
        let cmd = WeightDeltaCommand(
            direction: .add,
            delta: Weight(value: 5, unit: nil)
        )
        
        XCTAssertEqual(cmd.description, "plus 5")
    }
    
    func testSameAgainDescription() {
        let cmd = SameAgainCommand()
        XCTAssertEqual(cmd.description, "same again")
    }
    
    // MARK: - RPE Value Clamping Tests
    
    func testRPEClampsToMax() {
        let rpe = RPE(12)
        XCTAssertEqual(rpe.value, 10)
    }
    
    func testRPEClampsToMin() {
        let rpe = RPE(0)
        XCTAssertEqual(rpe.value, 1)
    }
    
    func testRPEAllowsHalfValues() {
        let rpe = RPE(8.5)
        XCTAssertEqual(rpe.value, 8.5)
    }
    
    // MARK: - Weight Unit Parsing Tests
    
    func testWeightUnitVariations() {
        XCTAssertEqual(WeightUnit.from("kg"), .kilograms)
        XCTAssertEqual(WeightUnit.from("kgs"), .kilograms)
        XCTAssertEqual(WeightUnit.from("kilo"), .kilograms)
        XCTAssertEqual(WeightUnit.from("kilos"), .kilograms)
        
        XCTAssertEqual(WeightUnit.from("lb"), .pounds)
        XCTAssertEqual(WeightUnit.from("lbs"), .pounds)
        XCTAssertEqual(WeightUnit.from("pound"), .pounds)
        XCTAssertEqual(WeightUnit.from("pounds"), .pounds)
        
        XCTAssertEqual(WeightUnit.from("plate"), .plates)
        XCTAssertEqual(WeightUnit.from("plates"), .plates)
        
        XCTAssertNil(WeightUnit.from("grams"))
    }
    
    // MARK: - Body Part Tests
    
    func testBodyPartVariations() {
        XCTAssertEqual(BodyPart.from("shoulder"), .shoulder)
        XCTAssertEqual(BodyPart.from("shoulders"), .shoulder)
        XCTAssertEqual(BodyPart.from("knee"), .knee)
        XCTAssertEqual(BodyPart.from("knees"), .knee)
        XCTAssertEqual(BodyPart.from("lower back"), .lower_back)
        
        XCTAssertNil(BodyPart.from("finger"))
    }
    
    // MARK: - Performance Tests
    
    func testParsePerformance() {
        measure {
            for _ in 0..<1000 {
                _ = parser.parse("Bench press 225 for 5 hard rpe 8")
            }
        }
    }
}

// MARK: - SetModifier Equatable Conformance (for test assertions)

extension SetModifier {
    static func == (lhs: SetModifier, rhs: SetModifier) -> Bool {
        switch (lhs, rhs) {
        case (.failed(let l), .failed(let r)):
            return l == r
        case (.easy, .easy), (.hard, .hard), (.warmup, .warmup):
            return true
        case (.rpe(let l), .rpe(let r)):
            return l.value == r.value
        case (.pain(let l), .pain(let r)):
            return l == r
        default:
            return false
        }
    }
}
