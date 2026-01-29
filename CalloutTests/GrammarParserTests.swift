import XCTest
@testable import Callout

/// Tests for GrammarParser - voice command parsing
final class GrammarParserTests: XCTestCase {
    
    var parser: GrammarParser!
    
    override func setUp() {
        super.setUp()
        parser = GrammarParser.shared
    }
    
    // MARK: - Set Logging Tests
    
    func testParseWeightForReps() {
        // Standard "weight for reps" pattern
        let result = parser.parse("100 for 5")
        
        if case .setLogged(let data) = result {
            XCTAssertEqual(data.weight, 100)
            XCTAssertEqual(data.reps, 5)
            XCTAssertFalse(data.isWarmup)
        } else {
            XCTFail("Expected setLogged, got \(result)")
        }
    }
    
    func testParseWeightTimesReps() {
        let result = parser.parse("80 times 8")
        
        if case .setLogged(let data) = result {
            XCTAssertEqual(data.weight, 80)
            XCTAssertEqual(data.reps, 8)
        } else {
            XCTFail("Expected setLogged, got \(result)")
        }
    }
    
    func testParseWeightXReps() {
        let result = parser.parse("60 x 10")
        
        if case .setLogged(let data) = result {
            XCTAssertEqual(data.weight, 60)
            XCTAssertEqual(data.reps, 10)
        } else {
            XCTFail("Expected setLogged, got \(result)")
        }
    }
    
    func testParseDecimalWeight() {
        let result = parser.parse("102.5 for 5")
        
        if case .setLogged(let data) = result {
            XCTAssertEqual(data.weight, 102.5)
            XCTAssertEqual(data.reps, 5)
        } else {
            XCTFail("Expected setLogged, got \(result)")
        }
    }
    
    // MARK: - Unit Detection Tests
    
    func testParseWithKgUnit() {
        let result = parser.parse("100kg for 5")
        
        if case .setLogged(let data) = result {
            XCTAssertEqual(data.weight, 100)
            XCTAssertEqual(data.reps, 5)
            XCTAssertEqual(data.unit, .kg)
        } else {
            XCTFail("Expected setLogged, got \(result)")
        }
    }
    
    func testParseWithKilosUnit() {
        let result = parser.parse("60 kilos for 8")
        
        if case .setLogged(let data) = result {
            XCTAssertEqual(data.weight, 60)
            XCTAssertEqual(data.reps, 8)
            XCTAssertEqual(data.unit, .kg)
        } else {
            XCTFail("Expected setLogged, got \(result)")
        }
    }
    
    func testParseWithLbsUnit() {
        let result = parser.parse("225 lbs for 5")
        
        if case .setLogged(let data) = result {
            XCTAssertEqual(data.weight, 225)
            XCTAssertEqual(data.reps, 5)
            XCTAssertEqual(data.unit, .lbs)
        } else {
            XCTFail("Expected setLogged, got \(result)")
        }
    }
    
    func testParseWithPoundsUnit() {
        let result = parser.parse("135 pounds for 10")
        
        if case .setLogged(let data) = result {
            XCTAssertEqual(data.weight, 135)
            XCTAssertEqual(data.reps, 10)
            XCTAssertEqual(data.unit, .lbs)
        } else {
            XCTFail("Expected setLogged, got \(result)")
        }
    }
    
    // MARK: - Reps-First Pattern Tests
    
    func testParseRepsFirstPattern() {
        let result = parser.parse("5 reps 100 kilos")
        
        if case .setLogged(let data) = result {
            XCTAssertEqual(data.weight, 100)
            XCTAssertEqual(data.reps, 5)
            XCTAssertEqual(data.unit, .kg)
        } else {
            XCTFail("Expected setLogged, got \(result)")
        }
    }
    
    func testParseWeightFirstWithUnit() {
        let result = parser.parse("100 kgs 5 reps")
        
        if case .setLogged(let data) = result {
            XCTAssertEqual(data.weight, 100)
            XCTAssertEqual(data.reps, 5)
            XCTAssertEqual(data.unit, .kg)
        } else {
            XCTFail("Expected setLogged, got \(result)")
        }
    }
    
    // MARK: - Same/Repeat Tests
    
    func testParseSame() {
        let result = parser.parse("same")
        XCTAssertEqual(result, .sameAgain)
    }
    
    func testParseSameAgain() {
        let result = parser.parse("same again")
        XCTAssertEqual(result, .sameAgain)
    }
    
    func testParseAgain() {
        let result = parser.parse("again")
        XCTAssertEqual(result, .sameAgain)
    }
    
    func testParseRepeat() {
        let result = parser.parse("repeat")
        XCTAssertEqual(result, .sameAgain)
    }
    
    func testParseOneMore() {
        let result = parser.parse("one more")
        XCTAssertEqual(result, .sameAgain)
    }
    
    // MARK: - Exercise Change Tests
    
    func testParseExerciseBench() {
        let result = parser.parse("bench")
        
        if case .exerciseChanged(let name) = result {
            XCTAssertEqual(name, "Bench Press")
        } else {
            XCTFail("Expected exerciseChanged, got \(result)")
        }
    }
    
    func testParseExerciseSquat() {
        let result = parser.parse("squat")
        
        if case .exerciseChanged(let name) = result {
            XCTAssertEqual(name, "Squat")
        } else {
            XCTFail("Expected exerciseChanged, got \(result)")
        }
    }
    
    func testParseExerciseDeadlift() {
        let result = parser.parse("deadlift")
        
        if case .exerciseChanged(let name) = result {
            XCTAssertEqual(name, "Deadlift")
        } else {
            XCTFail("Expected exerciseChanged, got \(result)")
        }
    }
    
    func testParseExerciseOHP() {
        let result = parser.parse("ohp")
        
        if case .exerciseChanged(let name) = result {
            XCTAssertEqual(name, "Overhead Press")
        } else {
            XCTFail("Expected exerciseChanged, got \(result)")
        }
    }
    
    func testParseExerciseRDL() {
        let result = parser.parse("rdl")
        
        if case .exerciseChanged(let name) = result {
            XCTAssertEqual(name, "Romanian Deadlift")
        } else {
            XCTFail("Expected exerciseChanged, got \(result)")
        }
    }
    
    // MARK: - Warmup Tests
    
    func testParseWarmupSet() {
        let result = parser.parse("warmup 60 for 10")
        
        if case .warmup(let data) = result {
            XCTAssertEqual(data.weight, 60)
            XCTAssertEqual(data.reps, 10)
            XCTAssertTrue(data.isWarmup)
        } else {
            XCTFail("Expected warmup, got \(result)")
        }
    }
    
    func testParseWarmUpSet() {
        let result = parser.parse("warm up 40 for 12")
        
        if case .warmup(let data) = result {
            XCTAssertEqual(data.weight, 40)
            XCTAssertEqual(data.reps, 12)
            XCTAssertTrue(data.isWarmup)
        } else {
            XCTFail("Expected warmup, got \(result)")
        }
    }
    
    // MARK: - Flag Tests
    
    func testParsePainFlag() {
        let result = parser.parse("pain")
        
        if case .addFlag(let flag) = result {
            XCTAssertEqual(flag, .pain)
        } else {
            XCTFail("Expected addFlag, got \(result)")
        }
    }
    
    func testParseFailureFlag() {
        let result = parser.parse("failure")
        
        if case .addFlag(let flag) = result {
            XCTAssertEqual(flag, .failure)
        } else {
            XCTFail("Expected addFlag, got \(result)")
        }
    }
    
    func testParseDropSetFlag() {
        let result = parser.parse("drop set")
        
        if case .addFlag(let flag) = result {
            XCTAssertEqual(flag, .dropSet)
        } else {
            XCTFail("Expected addFlag, got \(result)")
        }
    }
    
    // MARK: - Edge Cases
    
    func testParseEmptyString() {
        let result = parser.parse("")
        XCTAssertEqual(result, .empty)
    }
    
    func testParseWhitespaceOnly() {
        let result = parser.parse("   ")
        XCTAssertEqual(result, .empty)
    }
    
    func testParseUnknownText() {
        let result = parser.parse("hello world random text")
        
        if case .unknown(let text) = result {
            XCTAssertEqual(text, "hello world random text")
        } else {
            XCTFail("Expected unknown, got \(result)")
        }
    }
    
    func testCaseInsensitive() {
        let result = parser.parse("BENCH")
        
        if case .exerciseChanged(let name) = result {
            XCTAssertEqual(name, "Bench Press")
        } else {
            XCTFail("Expected exerciseChanged, got \(result)")
        }
    }
}

// MARK: - ParseResult Equatable for testing

extension GrammarParser.ParseResult: Equatable {
    public static func == (lhs: GrammarParser.ParseResult, rhs: GrammarParser.ParseResult) -> Bool {
        switch (lhs, rhs) {
        case (.sameAgain, .sameAgain):
            return true
        case (.empty, .empty):
            return true
        case (.exerciseChanged(let l), .exerciseChanged(let r)):
            return l == r
        case (.addFlag(let l), .addFlag(let r)):
            return l == r
        case (.unknown(let l), .unknown(let r)):
            return l == r
        default:
            return false
        }
    }
}
