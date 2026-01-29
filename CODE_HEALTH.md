# Callout Code Health Audit

**Audited:** 2026-01-29  
**Auditor:** Fresh-eye sub-agent  
**Files reviewed:** 18 Swift files across Services, Views, Models, App

---

## 🔴 High Priority

### 1. Dead Code: `handleProcessResult` in RestLoopViewModel
**File:** `Views/RestLoopView.swift` (lines ~415-435)  
**Issue:** The method `handleProcessResult(_:transcription:)` is never called. Voice processing now uses `handleBackendResult(_:)` instead.  
**Action:** Delete the unused method.

### 2. Hardcoded Backend URL
**File:** `Views/RestLoopView.swift` (line ~395), `Services/DeepgramService.swift` (line ~15)  
**Issue:** Backend URL `http://139.59.185.244:3100` is hardcoded in multiple places.  
**Action:** Extract to a single `Configuration` struct or use environment/settings.

```swift
// Suggested: Create Callout/Configuration.swift
enum Configuration {
    static var backendBaseURL: String {
        #if DEBUG
        return "http://139.59.185.244:3100"
        #else
        return "https://api.callout.app"  // Production URL
        #endif
    }
}
```

### 3. Force Unwrap Risk
**File:** `Services/PersistenceManager.swift` (line ~168)  
**Issue:** `workout.startedAt > index.lastWorkoutDate!` — force unwrap after nil check on different line.  
**Action:** Use optional binding or guard let.

```swift
// Before
if index.lastWorkoutDate == nil || workout.startedAt > index.lastWorkoutDate! {

// After  
if let lastDate = index.lastWorkoutDate {
    if workout.startedAt > lastDate {
        index.lastWorkoutDate = workout.startedAt
    }
} else {
    index.lastWorkoutDate = workout.startedAt
}
```

---

## 🟡 Medium Priority

### 4. Legacy Code in DeepgramService
**File:** `Services/DeepgramService.swift`  
**Issue:** Contains legacy code from pre-backend-proxy era:
- `setAPIKey(_:)` method (lines 35-40) — does nothing, marked "no-op"
- `DeepgramError.missingAPIKey` — marked "Legacy, kept for compatibility"
- `hasAPIKey` computed property always returns `true`

**Action:** Remove legacy code or add `@available(*, deprecated)` annotations.

### 5. Large ViewModel (~500 lines)
**File:** `Views/RestLoopView.swift`  
**Issue:** `RestLoopViewModel` handles too many responsibilities:
- Voice recording orchestration
- Backend communication  
- UI state management
- Widget updates
- AirPod callbacks

**Action:** Extract concerns:
- `AudioProcessingService` — handle recording → transcription → interpretation flow
- Move `BackendResult` models to `Models/BackendModels.swift`
- Move `ManualEntryView` to separate file

### 6. Inconsistent Observable Pattern
**Files:** Various Services  
**Issue:** Inconsistent use of `@Observable`:
- ✅ Uses `@Observable`: WorkoutSession, DeepgramService, GrammarParser, VoiceRecorder
- ❌ Doesn't use: PersistenceManager, HapticManager, WidgetDataManager

**Action:** Decide on a pattern. For services that never need UI observation, document why they don't use `@Observable`. Consider making HapticManager `@Observable` if `isEnabled` should trigger UI updates.

### 7. Magic Strings for UserDefaults Keys
**Files:** Multiple  
**Issue:** UserDefaults keys scattered as magic strings:
- `"weightUnit"` in RestLoopView
- `"hapticsEnabled"` in HapticManager  
- `"hasCompletedOnboarding"` in CalloutApp

**Action:** Centralize in an enum:
```swift
enum UserDefaultsKey {
    static let weightUnit = "weightUnit"
    static let hapticsEnabled = "hapticsEnabled"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
}
```

---

## 🟢 Low Priority

### 8. Exercise Aliases Hardcoded
**File:** `Services/GrammarParser.swift` (lines 20-95)  
**Issue:** 80+ exercise aliases hardcoded in a dictionary. Hard to maintain and extend.  
**Action:** Consider moving to `exercises.json` bundled resource for easier updates without code changes.

### 9. Mixed Async Patterns
**Files:** PersistenceManager, others  
**Issue:** Mix of `DispatchQueue.async` and `async/await`. PersistenceManager uses `DispatchQueue` while most other code uses `async/await`.  
**Action:** Consider migrating PersistenceManager to Swift Concurrency with actors for thread safety:

```swift
actor PersistenceManager {
    // ... actor provides built-in thread safety
}
```

### 10. Unused Protocol Default Implementations
**File:** `Services/VoiceRecorder.swift` (lines 190-200)  
**Issue:** `VoiceRecorderDelegate` has empty default implementations for all methods. If the delegate is always expected to be set, consider removing defaults.  
**Action:** Review if delegate pattern is still needed or if closures/callbacks would be cleaner.

### 11. Debug Print Statements
**Files:** Most services  
**Issue:** Many `#if DEBUG print(...)` statements. Good practice but verbose.  
**Action:** Consider a lightweight Logger utility (you have `Utilities/Logger.swift` — verify it's being used consistently).

### 12. Commented Code Style
**File:** `Services/GrammarParser.swift`  
**Issue:** Well-documented but some MARK sections are inconsistent.  
**Action:** Minor — standardize MARK comment style across all files.

---

## ✅ What's Good

- **Singleton pattern** consistently applied across services
- **Pre-warming** on app launch eliminates first-use lag
- **Background queue** for disk I/O in PersistenceManager
- **Haptic feedback** is well-organized and comprehensive
- **Sendable conformance** on models for Swift 6 concurrency
- **@ObservationIgnored** properly used for lazy vars
- **Error handling** with proper LocalizedError conformance
- **Code organization** with clear MARK sections

---

## Summary

| Priority | Count | Est. Effort |
|----------|-------|-------------|
| 🔴 High | 3 | 1-2 hours |
| 🟡 Medium | 4 | 2-4 hours |
| 🟢 Low | 5 | 2-3 hours |

**Recommended order:**
1. Delete dead `handleProcessResult` code (5 min)
2. Extract hardcoded backend URL (15 min)
3. Fix force unwrap in PersistenceManager (5 min)
4. Clean up legacy DeepgramService code (15 min)
5. Extract ManualEntryView to separate file (10 min)
6. Centralize UserDefaults keys (15 min)

Total estimated cleanup: **~4-6 hours** for all items.
