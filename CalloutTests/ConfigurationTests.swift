import XCTest
@testable import Callout

/// Tests for Configuration - sanity checks for app configuration
final class ConfigurationTests: XCTestCase {
    
    func testBackendBaseURLNotEmpty() {
        XCTAssertFalse(Configuration.backendBaseURL.isEmpty)
    }
    
    func testBackendBaseURLIsValidURL() {
        let url = URL(string: Configuration.backendBaseURL)
        XCTAssertNotNil(url, "Backend URL should be a valid URL")
    }
    
    func testBackendBaseURLHasHTTPScheme() {
        let url = URL(string: Configuration.backendBaseURL)
        XCTAssertTrue(
            url?.scheme == "http" || url?.scheme == "https",
            "Backend URL should use http or https"
        )
    }
    
    func testBackendBaseURLHasPort() {
        // Our backend uses a specific port
        let url = URL(string: Configuration.backendBaseURL)
        XCTAssertNotNil(url?.port, "Backend URL should specify a port")
    }
}

/// Tests for BackendModels - API response decoding
@MainActor
final class BackendModelsTests: XCTestCase {
    
    func testDecodeSetResponse() throws {
        let json = """
        {
            "transcript": "100 kilos 5 reps",
            "interpreted": {
                "type": "set",
                "weight": 100,
                "unit": "kg",
                "reps": 5
            },
            "latency": {
                "transcribe": 150,
                "interpret": 80,
                "total": 230
            }
        }
        """
        
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(BackendResult.self, from: data)
        
        XCTAssertEqual(result.transcript, "100 kilos 5 reps")
        XCTAssertEqual(result.interpreted.type, "set")
        XCTAssertEqual(result.interpreted.weight, 100)
        XCTAssertEqual(result.interpreted.unit, "kg")
        XCTAssertEqual(result.interpreted.reps, 5)
        XCTAssertEqual(result.latency?.total, 230)
    }
    
    func testDecodeExerciseResponse() throws {
        let json = """
        {
            "transcript": "bench press",
            "interpreted": {
                "type": "exercise",
                "name": "Bench Press"
            }
        }
        """
        
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(BackendResult.self, from: data)
        
        XCTAssertEqual(result.interpreted.type, "exercise")
        XCTAssertEqual(result.interpreted.name, "Bench Press")
        XCTAssertNil(result.latency)
    }
    
    func testDecodeRepeatResponse() throws {
        let json = """
        {
            "transcript": "same again",
            "interpreted": {
                "type": "repeat"
            }
        }
        """
        
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(BackendResult.self, from: data)
        
        XCTAssertEqual(result.interpreted.type, "repeat")
    }
    
    func testDecodeUnknownResponse() throws {
        let json = """
        {
            "transcript": "random words here",
            "interpreted": {
                "type": "unknown",
                "text": "random words here"
            }
        }
        """
        
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(BackendResult.self, from: data)
        
        XCTAssertEqual(result.interpreted.type, "unknown")
        XCTAssertEqual(result.interpreted.text, "random words here")
    }
    
    func testDecodeMinimalResponse() throws {
        // Minimal valid response
        let json = """
        {
            "transcript": "test",
            "interpreted": {
                "type": "unknown"
            }
        }
        """
        
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(BackendResult.self, from: data)
        
        XCTAssertEqual(result.transcript, "test")
        XCTAssertNil(result.interpreted.weight)
        XCTAssertNil(result.interpreted.reps)
        XCTAssertNil(result.interpreted.name)
        XCTAssertNil(result.latency)
    }
}

/// Tests for UserDefaultsKey - ensure keys are consistent
final class UserDefaultsKeyTests: XCTestCase {
    
    func testKeysAreNotEmpty() {
        XCTAssertFalse(UserDefaultsKey.weightUnit.isEmpty)
        XCTAssertFalse(UserDefaultsKey.hapticsEnabled.isEmpty)
        XCTAssertFalse(UserDefaultsKey.hasCompletedOnboarding.isEmpty)
    }
    
    func testKeysAreUnique() {
        let keys = [
            UserDefaultsKey.weightUnit,
            UserDefaultsKey.hapticsEnabled,
            UserDefaultsKey.hasCompletedOnboarding
        ]
        
        let uniqueKeys = Set(keys)
        XCTAssertEqual(keys.count, uniqueKeys.count, "UserDefaults keys should be unique")
    }
}
