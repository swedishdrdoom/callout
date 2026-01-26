# Callout 🎤

**Voice-first workout logging for iOS.**

> *A training memory prosthetic that stays silent until something statistically meaningful goes wrong.*

## What is Callout?

Callout is a workout logging app that prioritizes **zero-friction capture** over everything else. No workout builders. No programs. No setup. Just open the app, speak your sets, and lift.

### Core Philosophy

- **Logging is the product.** Insights are a delayed byproduct.
- **Silence is a feature.** No coaching, no "nice job", no noise.
- **Imperfect logs > unlogged sets.** The cost of correction must be lower than the cost of logging.

### Input Modes

1. **Voice shorthand** (primary): "Bench 100 for 5", "Same again", "Plus 2.5"
2. **Single-tap logging** (fallback): For when voice feels awkward

### Target

- iPhone + AirPods
- Whisper API for transcription
- Built for serious lifters who hate friction

## Status

🚧 **v0.1 Development** — Core Swift codebase complete, awaiting Xcode project setup.

### Completed (4,600+ lines of Swift)
- ✅ Data models (SetCard, Session, UserProfile)
- ✅ SwiftData persistence layer
- ✅ Grammar parser (full gym shorthand support)
- ✅ Whisper API integration
- ✅ Voice recorder (AVFoundation)
- ✅ Haptic feedback system
- ✅ WorkoutEngine (state management)
- ✅ SwiftUI views (RestLoop, Receipt, Onboarding, Settings)

### Next Steps
- [ ] Create Xcode project and import files
- [ ] Configure OpenAI API key
- [ ] Build and test on device
- [ ] Integrate AirPods tap detection

## Docs

- [Product Spec](./docs/PRODUCT.md)
- [Tech Spec](./docs/TECH.md) *(coming soon)*

## License

MIT
