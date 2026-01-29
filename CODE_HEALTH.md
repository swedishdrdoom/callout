# Callout Code Health Report

**Generated:** 2025-01-29  
**Scope:** Services, Views, Models, App, Utilities  
**Total Files Reviewed:** 19 Swift files

---

## Executive Summary

The codebase is generally well-structured with good separation of concerns. However, there are several areas that need attention:

- **High Priority:** Duplicate model definitions, unused code paths, hardcoded API endpoints
- **Medium Priority:** Inconsistent patterns, repeated code, missing abstractions
- **Low Priority:** Minor style inconsistencies, potential optimizations

---

## 🔴 High Priority Issues

### 1. Duplicate Model Definitions

**Files:** `MainView.swift`, `RestLoopView.swift`, `WorkoutModels.swift`

The same models are defined in multiple places with slight variations:

| Model | Locations |
|-------|-----------|
| `InterpretedData` | MainView.swift:217, RestLoopView.swift:455 |
| `BackendResponse/BackendResult` | MainView.swift:212, RestLoopView.swift:449 |
| `WeightUnit` | OnboardingView.swift:180, WorkoutModels.swift (implicit via GrammarParser) |
| `ExerciseData`, `SetData` | MainView.swift:237-247, WorkoutCardView.swift (used) |
| `CompletedWorkout` | MainView.swift:201 (defined), WorkoutCardView.swift (used) |

**Problem:** Changes need to be made in multiple places, leading to drift and bugs.

**Recommendation:**
```swift
// Create Models/BackendModels.swift
struct BackendResponse: Decodable {
    let transcript: String
    let interpreted: InterpretedData
    let latency: LatencyInfo?
}

struct InterpretedData: Decodable {
    let type: String
    let weight: Double?
    let unit: String?
    let reps: Int?
    let name: String?
    let text: String?
    let pr: String?
}
```

---

### 2. Hardcoded Backend URL

**Files:** `MainView.swift:170`, `RestLoopView.swift:383`, `DeepgramService.swift:16`

```swift
// MainView.swift:170
let url = URL(string: "http://139.59.185.244:3100/api/understand")!

// RestLoopView.swift:383
let url = URL(string: "http://139.59.185.244:3100/api/understand")!

// DeepgramService.swift:16
private let transcribeURL = URL(string: "http://139.59.185.244:3100/api/transcribe")!
```

**Problems:**
1. Force unwrap on URL creation
2. Duplicated across files
3. No staging/production differentiation
4. Plain HTTP (not HTTPS)

**Recommendation:**
```swift
// Create Services/APIConfiguration.swift
enum APIConfiguration {
    static let baseURL: URL = {
        #if DEBUG
        return URL(string: "http://139.59.185.244:3100")!
        #else
        return URL(string: "https://api.callout.app")!
        #endif
    }()
    
    static var transcribeURL: URL { baseURL.appendingPathComponent("api/transcribe") }
    static var understandURL: URL { baseURL.appendingPathComponent("api/understand") }
}
```

---

### 3. Unused Code in WorkoutSession

**File:** `WorkoutSession.swift`

The `GrammarParser` integration exists but is bypassed by the backend:

```swift
// Line 45-47 - Dependencies declared but GrammarParser barely used
private let parser = GrammarParser.shared

// Line 97 - processVoiceInput() method exists but isn't called by MainView/RestLoopView
// Both views send audio directly to backend and handle response there
```

The entire `processVoiceInput()` method (lines 97-141) and its `ProcessResult` enum are dead code since the backend now does parsing.

**Recommendation:** Either:
1. Remove `processVoiceInput()` and make GrammarParser a fallback/offline mode
2. Or route all parsing through WorkoutSession for consistency

---

### 4. Two Competing Main Views

**Files:** `MainView.swift`, `RestLoopView.swift`

Both files implement the main workout interface with different approaches:
- `MainView` - Simpler, used by `CalloutApp.swift`
- `RestLoopView` - More feature-rich with ghost data, manual entry, etc.

**Problem:** `RestLoopView` is never instantiated (orphaned code).

**Evidence:**
```swift
// CalloutApp.swift:22 - Only MainView is used
if hasCompletedOnboarding {
    MainView()  // RestLoopView never used
}
```

**Recommendation:** 
- If RestLoopView is the intended V2, migrate to it
- If MainView is the final design, delete RestLoopView
- Current state: ~600 lines of dead code

---

## 🟡 Medium Priority Issues

### 5. Repeated Weight Formatting Logic

**Files:** `WidgetDataManager.swift:66`, `RestLoopView.swift:244`, `ReceiptView.swift:177`, `WorkoutCardView.swift:137`

The same weight formatting logic is copied 4+ times:

```swift
// Pattern repeated everywhere
if weight.truncatingRemainder(dividingBy: 1) == 0 {
    return String(format: "%.0f", weight)
} else {
    return String(format: "%.1f", weight)
}
```

**Recommendation:**
```swift
// Add to Models/WorkoutModels.swift or create Utilities/Formatters.swift
extension Double {
    var formattedWeight: String {
        truncatingRemainder(dividingBy: 1) == 0 
            ? String(format: "%.0f", self)
            : String(format: "%.1f", self)
    }
}
```

---

### 6. Inconsistent Error Handling

**File:** `DeepgramService.swift`

The `DeepgramError.missingAPIKey` case is marked as "Legacy, kept for compatibility" but `hasAPIKey` always returns `true`:

```swift
// Line 27
var hasAPIKey: Bool { true }

// Line 66 - This error case can never be thrown
case .missingAPIKey:
    return "Backend unavailable"
```

**Recommendation:** Remove dead error cases or implement proper API key checking if needed.

---

### 7. Magic Numbers

**File:** `WorkoutSession.swift:264`
```swift
// What is 0.6? Should be a named constant
return weight < ghost.weight * 0.6
```

**File:** `DeepgramService.swift:23-24`
```swift
config.timeoutIntervalForRequest = 8  // Why 8?
config.timeoutIntervalForResource = 16  // Why 16?
```

**File:** `RestLoopView.swift:387`
```swift
request.timeoutInterval = 15 // Reasonable timeout for background
```

**Recommendation:**
```swift
enum Constants {
    enum Workout {
        static let warmupThreshold = 0.6  // 60% of working weight = warmup
    }
    enum Network {
        static let quickTimeout: TimeInterval = 8
        static let standardTimeout: TimeInterval = 15
    }
}
```

---

### 8. VoiceRecorder Delegate Not Used

**File:** `VoiceRecorder.swift`

The delegate pattern is fully implemented (lines 210-228) but neither `MainViewModel` nor `RestLoopViewModel` conform to `VoiceRecorderDelegate`. They use the recorder in a fire-and-forget manner.

**Recommendation:** Either:
1. Remove the delegate pattern if not needed
2. Or use it for proper error handling in ViewModels

---

### 9. Inconsistent Async Patterns

**Files:** Multiple

Mix of completion handlers and async/await:

```swift
// PersistenceManager.swift - Uses DispatchQueue for background
diskQueue.async { [weak self] in ... }

// MainView.swift - Uses Task.detached
Task.detached(priority: .userInitiated) { ... }

// VoiceRecorder.swift - Uses async/await
func start() async throws { ... }
```

**Recommendation:** Standardize on async/await with structured concurrency where possible.

---

### 10. Logging Inconsistency

**File:** `Utilities/Logger.swift` exists but is unused

The codebase uses direct `print()` with `#if DEBUG`:

```swift
// Used everywhere
#if DEBUG
print("[WidgetDataManager] Warning: App Group not configured")
#endif

// But Logger.swift provides:
Log.debug("message")  // Never used
```

**Recommendation:** Either use the Log utility consistently or remove it.

---

## 🟢 Low Priority Issues

### 11. Force Unwraps

**File:** `PersistenceManager.swift:24`
```swift
fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
```

While practically safe, could use `first!` with a comment or handle gracefully.

---

### 12. Unused Protocol Conformance

**File:** `WorkoutModels.swift:10`
```swift
struct Workout: Identifiable, Codable, Sendable { ... }
```

`Sendable` conformance is declared but the types aren't used across concurrency boundaries in the current code.

---

### 13. Commented Code Smell

**File:** `GrammarParser.swift:288-291`
```swift
// MARK: - Learning (Future)

/// Add a custom exercise alias
func learnAlias(_ alias: String, for exercise: String) {
    exerciseAliases[alias.lowercased()] = exercise
}
```

Method exists but is never called. Either implement the learning feature or remove.

---

### 14. View Model State Duplication

**File:** `MainView.swift`

`MainViewModel` duplicates some state tracking that `WorkoutSession` already handles:

```swift
// MainViewModel tracks:
var entries: [VoiceEntry] = []

// WorkoutSession tracks:
var currentWorkout: Workout?  // Contains exercises and sets
```

---

### 15. Inconsistent Theme Usage

**Files:** `MainView.swift`, `WorkoutCardView.swift` vs others

`CalloutTheme` is defined in `MainView.swift` and used in `WorkoutCardView.swift`, but `RestLoopView.swift`, `ReceiptView.swift`, and `SettingsView.swift` define colors inline:

```swift
// RestLoopView.swift
Color.black  // Instead of CalloutTheme.background
.white.opacity(0.6)  // Instead of CalloutTheme.dimWhite
```

**Recommendation:** Move `CalloutTheme` to a shared file and use consistently.

---

### 16. Preview Data Could Be Richer

**File:** `ReceiptView.swift:189-192`
```swift
#Preview {
    var workout = Workout()
    workout.endedAt = Date()
    return ReceiptView(workout: workout)  // Empty workout
}
```

Preview shows an empty workout, making it less useful for development.

---

## Architectural Recommendations

### 1. Create a Proper Network Layer

Extract networking into a dedicated service:

```swift
// Services/NetworkService.swift
actor NetworkService {
    static let shared = NetworkService()
    
    func understand(audioData: Data) async throws -> BackendResponse
    func transcribe(audioData: Data) async throws -> String
}
```

### 2. Consolidate Models

Create a clear model hierarchy:

```
Models/
├── WorkoutModels.swift      // Core domain models
├── BackendModels.swift      // API response models  
├── ViewModels.swift         // UI-specific models (VoiceEntry, CompletedWorkout)
└── Constants.swift          // Magic numbers, configuration
```

### 3. Resolve MainView vs RestLoopView

Choose one approach and delete the other. Current recommendation: 
- Keep `MainView` (simpler, matches App entry point)
- Port ghost data feature from RestLoopView if needed
- Delete RestLoopView (600+ lines of dead code)

### 4. Add Dependency Injection

Current singleton pattern makes testing difficult:

```swift
// Current
private let recorder = VoiceRecorder()
private let transcription = DeepgramService.shared

// Better
init(
    recorder: VoiceRecorder = VoiceRecorder(),
    transcription: DeepgramService = .shared
)
```

---

## Quick Wins (Can Fix Today)

1. ✅ Extract `CalloutTheme` to `Utilities/Theme.swift`
2. ✅ Add `formattedWeight` extension to Double
3. ✅ Create `APIConfiguration` for URLs
4. ✅ Remove or use `Log` utility
5. ✅ Add warmup threshold constant
6. ✅ Delete `RestLoopView.swift` if not used

---

## Files Summary

| File | Health | Notes |
|------|--------|-------|
| `WorkoutModels.swift` | 🟢 Good | Clean, well-documented |
| `PersistenceManager.swift` | 🟢 Good | Good caching strategy |
| `HapticManager.swift` | 🟢 Good | Clean singleton |
| `WidgetDataManager.swift` | 🟢 Good | Simple, focused |
| `CalloutWidget.swift` | 🟢 Good | Well-structured |
| `VoiceRecorder.swift` | 🟡 OK | Unused delegate pattern |
| `DeepgramService.swift` | 🟡 OK | Dead error cases |
| `WorkoutSession.swift` | 🟡 OK | Dead code paths |
| `GrammarParser.swift` | 🟡 OK | Unused by main flow |
| `AirPodController.swift` | 🟡 OK | May be dead code |
| `MainView.swift` | 🟡 OK | Duplicate models |
| `RestLoopView.swift` | 🔴 Remove | Orphaned, not used |
| `ReceiptView.swift` | 🟢 Good | Clean receipt design |
| `SettingsView.swift` | 🟢 Good | Straightforward |
| `OnboardingView.swift` | 🟡 OK | Duplicate WeightUnit |
| `SplashView.swift` | 🟢 Good | Simple, effective |
| `WorkoutCardView.swift` | 🟡 OK | Uses external models |
| `CalloutApp.swift` | 🟢 Good | Clean entry point |
| `Logger.swift` | 🔴 Remove | Not used anywhere |

---

## Next Steps

1. **Immediate:** Delete `RestLoopView.swift` and `Logger.swift` if confirmed unused
2. **This Week:** Extract duplicate models into shared files
3. **This Sprint:** Create `APIConfiguration` and `Constants` files
4. **Future:** Add dependency injection for testability
