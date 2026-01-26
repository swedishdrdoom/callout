# Callout — Product Specification

## One-Sentence Identity

A voice-assisted training memory that stays silent until something statistically meaningful goes wrong.

---

## Core User Pain Statements

- Manual typing/tapping of workout sets is the most annoying part of tracking
- Setting up workouts or programs in advance is a deal-breaker
- Imperfect logs with zero friction > perfect logs with effort
- Corrections should happen after the workout, not during
- The product should be mostly silent — but aggressively loud when something is wrong

---

## Product Thesis

**This is not a coaching app. It is a training memory prosthetic.**

The product's primary job is:
1. To remember what happened during training with near-zero cognitive load
2. To infer structure passively
3. To interrupt the user only when statistically meaningful anomalies occur

**Logging is the product. Insights are a delayed byproduct.**

---

## Design Principles

### 1. Zero Setup
- No workout builders
- No programs required
- No templates up front
- No "start workout" ceremony
- The app must allow logging immediately on open

### 2. Frictionless Capture > Correctness
- Voice input can be ambiguous — the system fills in the blanks
- Structure is inferred later
- The cost of correction must be lower than the cost of logging
- A logged imperfect set is always better than an unlogged perfect one

### 3. Context Over Precision
- Logs are treated as events, not finalized records
- Normalization happens post-hoc
- The user should never be forced to clarify mid-set

### 4. Silence Is a Feature
- No constant coaching
- No frequent insights
- No "nice job" feedback
- The system stays quiet unless it has high confidence that intervention is warranted

---

## Input Modalities

### Primary: Voice Shorthand

Not natural language conversation — compressed gym grammar.

**Examples:**
- "Bench" → sets exercise context
- "100 for 5" → logs set
- "Same again" → repeat last set
- "Plus 2.5" → increment weight
- "Failed at 4" → log failure
- "Left knee tweak" → pain flag

**Assumptions:**
- Exercise context persists until changed
- Units and bar weight inferred from user profile
- Rest timer starts automatically (counts up)
- No voice confirmations — haptic feedback instead

**Trigger:** Tap left AirPod (default), configurable to hold or right AirPod

### Secondary: Single-Tap Logging

For environments where voice feels awkward.

- One large "Log Set" button
- Auto-increments weight/reps based on history
- Swipe or long-press for modifiers (fail, pain, edit)
- No keyboards

### Tertiary: Post-Workout Voice Dump

Escape hatch for bad days.

Example: "Bench: three sets of five at 100. Squats felt heavy. Knee again."

System reconstructs a plausible session.

---

## Core Interaction: The Rest Loop

The app lives between sets, not in dashboards.

During rest, the UI shows only:
- Last logged set
- Current exercise context
- Rest timer (counting UP — elapsed since last set)
- (Optional) Last time's comparable set as ghost data

One dominant action: "Log next set"

---

## Data Model

### Set Cards (Atomic Unit)

```
- Exercise
- Weight
- Reps
- Timestamp
- Optional modifiers:
  - RPE
  - Fail flag
  - Pain flag + location
  - Warm-up flag
  - Notes
```

### Session Inference

The system clusters sets into sessions based on:
- Time gaps
- Exercise transitions
- Rest patterns

It learns:
- Typical session length
- Common exercise groupings
- Progression tendencies
- Normal volume ranges

**The system never asks the user to confirm or label sessions.**

---

## Insights Philosophy

### Two Intelligence Modes

**1. Passive Normalization (Always on, never visible)**
- Resolves ambiguity
- Infers structure
- Learns shorthand
- Builds long-term memory

**2. Active Disruption (Rare, Loud)**
- Only when data crosses meaningful thresholds

### What Should Trigger Alerts

**Plateau Alerts:**
- Lift fails to progress for longer than typical progression cycle
- Plateau is statistically unlikely given prior history

**Risk Alerts:**
- Pain flags correlate with specific movements or volume spikes
- Performance drops align with reported pain

### What Should NOT Trigger Alerts
- Single bad days
- Normal variance
- Minor fluctuations
- Generic encouragement

**Silence is preferred over noise.**

---

## Visibility Strategy

### During Workout
- Last set
- Current movement
- Rest countdown (counting up)
- No charts. No totals. No gamification.

### After Workout
A single "receipt" view:
- Top sets
- Notable flags (pain, failures)
- Any triggered alerts

### Weekly
One question answered: "What actually changed?"

---

## Onboarding (Minimal)

```
Screen 1: "What unit do you lift in?"
          [ kg ]    [ lbs ]

Screen 2: "Tap your left AirPod to log sets by voice."
          [Customize trigger] → settings

Screen 3: "You're ready. Just open and speak."
          [Start Training]
```

Three screens. No account creation for MVP.

---

## iOS Widget

**Small Widget (2×2)**
- Shows: Current exercise context (or "Tap to start")
- Tap: Opens app directly into Rest Loop

---

## North Star Metric

**Average seconds per logged set**

Target: **< 3 seconds**

If this is achieved, everything else compounds.

---

## Explicit Non-Goals

- ❌ Workout builders
- ❌ Predefined programs
- ❌ Constant coaching
- ❌ Complex dashboards
- ❌ Gamified streaks
- ❌ Social feeds
- ❌ Siri shortcuts (use widget instead)

---

## MVP Feature Set

### Must Have (v0.1)
- [ ] Single-screen Rest Loop UI
- [ ] Voice input via AirPods (tap trigger)
- [ ] Whisper API transcription
- [ ] Gym grammar parser (limited vocabulary)
- [ ] Set card logging
- [ ] Exercise context persistence
- [ ] Tap fallback (big "Log Set" button)
- [ ] Session auto-grouping by time
- [ ] Local persistence
- [ ] Workout "receipt" view
- [ ] iOS Home Screen Widget
- [ ] Onboarding (unit selection, trigger config)

### Deferred (v0.2+)
- [ ] Pain/fail flags with correlation
- [ ] Historical ghost sets
- [ ] Plateau alerts
- [ ] Post-workout voice dump reconstruction
- [ ] Export (CSV)
- [ ] Cloud sync
- [ ] Watch app

---

## Competitive Positioning

**Direct competitors:** Strong, Hevy, Fitbod, RepCount, Setgraph

**Our differentiation:** None of them own voice. We do.

**Pricing strategy (future):** Freemium with premium for alerts/insights.

---

## Future Evolution

```
v1.0 — Voice + tap logging, pure autoregulation
v1.x — Insights (plateaus, pain patterns), workout receipts
v2.0 — AI-generated workout suggestions based on history
v3.0 — Watch app for true hands-free
```
