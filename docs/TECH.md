# Callout — Technical Specification

## Tech Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Platform | iOS (iPhone) | Primary target |
| Language | Swift | Native performance, AirPods integration |
| UI | SwiftUI | Modern, declarative |
| Voice transcription | OpenAI Whisper API | Best-in-class accuracy |
| Local storage | SwiftData | Modern, Swift-native persistence |
| Audio | AVFoundation | AirPods integration, recording |
| Networking | URLSession | Whisper API calls |

## System Requirements

- iOS 17.0+
- iPhone with AirPods (any generation)
- Internet connection (for Whisper API)

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│                   UI Layer                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────┐  │
│  │ RestLoopView│  │ReceiptView  │  │Settings │  │
│  └──────┬──────┘  └──────┬──────┘  └────┬────┘  │
└─────────┼────────────────┼──────────────┼───────┘
          │                │              │
┌─────────▼────────────────▼──────────────▼───────┐
│                 Domain Layer                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────┐  │
│  │WorkoutEngine│  │VoiceParser  │  │Analytics│  │
│  └──────┬──────┘  └──────┬──────┘  └────┬────┘  │
└─────────┼────────────────┼──────────────┼───────┘
          │                │              │
┌─────────▼────────────────▼──────────────▼───────┐
│                 Data Layer                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────┐  │
│  │ SwiftData   │  │ WhisperAPI  │  │AudioRec │  │
│  └─────────────┘  └─────────────┘  └─────────┘  │
└─────────────────────────────────────────────────┘
```

---

## Data Models

### SetCard

```swift
@Model
class SetCard {
    var id: UUID
    var exercise: String
    var weight: Double
    var weightUnit: WeightUnit
    var reps: Int
    var timestamp: Date
    
    // Optional modifiers
    var rpe: Int?
    var failed: Bool
    var failedAtRep: Int?
    var painFlag: String?
    var isWarmup: Bool
    var notes: String?
    
    // Session grouping (inferred)
    var sessionId: UUID?
}

enum WeightUnit: String, Codable {
    case kg, lbs
}
```

### Session (Inferred)

```swift
@Model
class Session {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var sets: [SetCard]
    
    // Computed
    var exercises: [String] { ... }
    var totalVolume: Double { ... }
    var topSets: [SetCard] { ... }
}
```

### UserProfile

```swift
@Model
class UserProfile {
    var preferredUnit: WeightUnit
    var voiceTrigger: VoiceTrigger
    var exerciseAliases: [String: String]  // "bench" -> "Bench Press"
}

enum VoiceTrigger: String, Codable {
    case tapLeft, tapRight, holdLeft, holdRight
}
```

---

## Voice Grammar Specification

### Tokenization

Input is tokenized into:
- **Exercise names**: Recognized lifts
- **Numbers**: Weight or rep values
- **Keywords**: "for", "same", "plus", "minus", "failed", etc.
- **Modifiers**: "easy", "hard", "pain", "warmup"

### Grammar Rules

```
SetLog     := Exercise? Weight "for" Reps Modifier*
           | "same" "again"?
           | Delta
           | Modifier

Exercise   := KnownExercise | UnknownWord+

Weight     := Number Unit?
Unit       := "kg" | "kilos" | "lbs" | "pounds"

Reps       := Number "reps"?

Delta      := ("plus" | "add" | "minus" | "drop") Number

Modifier   := "failed" ("at" Number)?
           | "easy" | "hard"
           | "rpe" Number
           | "warmup"
           | BodyPart "pain"

BodyPart   := "left"? "right"? KnownBodyPart
KnownBodyPart := "knee" | "shoulder" | "back" | "elbow" | "wrist" | ...
```

### Example Parses

| Input | Parsed |
|-------|--------|
| "Bench 100 for 5" | exercise=Bench, weight=100, reps=5 |
| "Same again" | repeat last set |
| "Plus 2.5" | weight += 2.5, same reps |
| "8 reps" | same weight, reps=8 |
| "Failed at 4" | failed=true, failedAtRep=4 |
| "Squat" | context switch to Squat |
| "Easy" | modifier on last/current set |
| "Left knee pain" | painFlag="left knee" |

### Unknown Input Handling

If input doesn't parse cleanly:
1. Log raw transcript with timestamp
2. Flag for post-workout review
3. Associate with current exercise context

---

## AirPods Integration

### Tap Detection

Use `AVAudioSession` interruption notifications or MediaPlayer framework for remote command handling.

```swift
// Configure audio session for recording
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playAndRecord, mode: .default)
try session.setActive(true)

// Listen for AirPods tap via MPRemoteCommandCenter
let commandCenter = MPRemoteCommandCenter.shared()
commandCenter.playCommand.addTarget { event in
    // Start/stop voice recording
    return .success
}
```

### Recording Flow

1. User taps AirPod → start recording
2. User taps again (or silence detected) → stop recording
3. Send audio to Whisper API
4. Parse response
5. Haptic feedback for confirmation

---

## Whisper API Integration

### Request

```swift
func transcribe(audioData: Data) async throws -> String {
    let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    
    let boundary = UUID().uuidString
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    
    var body = Data()
    // Add audio file
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n")
    body.append("Content-Type: audio/m4a\r\n\r\n")
    body.append(audioData)
    body.append("\r\n")
    // Add model parameter
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
    body.append("whisper-1\r\n")
    body.append("--\(boundary)--\r\n")
    
    request.httpBody = body
    
    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(WhisperResponse.self, from: data)
    return response.text
}
```

### Prompt Hint (Optional)

Whisper supports a `prompt` parameter to improve accuracy for domain-specific vocabulary:

```
"Gym workout logging. Exercises: bench press, squat, deadlift, overhead press, rows, pullups. 
Numbers are weights in kg or lbs. Format: 'exercise weight for reps'."
```

---

## Haptic Feedback

```swift
enum HapticFeedback {
    case setLogged      // Double tap - success
    case exerciseChanged // Single tap
    case error          // Long buzz
    case alert          // Pattern vibration
    
    func trigger() {
        let generator = UINotificationFeedbackGenerator()
        switch self {
        case .setLogged:
            generator.notificationOccurred(.success)
        case .exerciseChanged:
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        case .error:
            generator.notificationOccurred(.error)
        case .alert:
            generator.notificationOccurred(.warning)
        }
    }
}
```

---

## Widget

### Small Widget

```swift
struct CalloutWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CalloutWidget", provider: Provider()) { entry in
            CalloutWidgetView(entry: entry)
        }
        .configurationDisplayName("Callout")
        .description("Quick access to workout logging")
        .supportedFamilies([.systemSmall])
    }
}

struct CalloutWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack {
            if let exercise = entry.currentExercise {
                Text(exercise)
                    .font(.headline)
                Text(entry.lastSet ?? "")
                    .font(.caption)
            } else {
                Text("Tap to start")
                    .font(.headline)
            }
        }
        .widgetURL(URL(string: "callout://start"))
    }
}
```

---

## File Structure

```
Callout/
├── App/
│   ├── CalloutApp.swift
│   └── ContentView.swift
├── Features/
│   ├── RestLoop/
│   │   ├── RestLoopView.swift
│   │   └── RestLoopViewModel.swift
│   ├── Receipt/
│   │   ├── ReceiptView.swift
│   │   └── ReceiptViewModel.swift
│   ├── Onboarding/
│   │   └── OnboardingView.swift
│   └── Settings/
│       └── SettingsView.swift
├── Core/
│   ├── Voice/
│   │   ├── VoiceRecorder.swift
│   │   ├── WhisperService.swift
│   │   └── GrammarParser.swift
│   ├── Data/
│   │   ├── Models/
│   │   │   ├── SetCard.swift
│   │   │   ├── Session.swift
│   │   │   └── UserProfile.swift
│   │   └── Persistence.swift
│   └── Haptics/
│       └── HapticManager.swift
├── Widget/
│   └── CalloutWidget.swift
├── Resources/
│   └── Assets.xcassets
└── Tests/
    ├── GrammarParserTests.swift
    └── SessionInferenceTests.swift
```

---

## API Keys & Secrets

For MVP (single user = Doom), API key can be bundled or fetched from a simple config.

For future distribution:
- User provides own OpenAI API key, OR
- Proxy through a backend that manages API calls

---

## Performance Targets

| Metric | Target |
|--------|--------|
| App launch → ready to log | < 1 second |
| Voice recording → transcription | < 2 seconds |
| Set logged (end-to-end) | < 3 seconds |
| Battery impact per hour workout | < 5% |
