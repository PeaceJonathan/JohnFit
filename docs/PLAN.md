# JohnFit — Zone-2 Cardio Coaching App (v1 iOS Plan)

## Context

The repo (`peacejonathan/johnfit`) is currently completely empty — no commits, no files. This is a from-scratch build of an iOS app whose mission is to keep the user in their optimal cardio training zone as efficiently as possible, using any connected heart-rate source, with rigorous per-sport baseline testing so the "optimal zone" is actually personalized rather than guessed from an age formula. Longer-term the product adds a community layer (friends, leaderboards, nudges) to make consistency more motivating, but that depends on a backend/accounts system that doesn't exist yet.

**Why now / what this addresses:** the user wants real-time in-workout coaching toward a personalized zone (defaulting to Zone 2, user-overridable), driven by a proper baseline test per sport rather than a generic age-based formula, with progress tracked over repeated tests — and eventually a free social layer to compete with paid incumbents.

**Market check (per user's request):** this space is not empty — competitors include *Zone 2: Heart Rate Training*, *Zone 2 AI (Vo2 Max & Endurance)*, *Zone2 Pulse*, *RunBeat*, and *Heart Rate Zone Announcer*, plus the gym-oriented *MyZone* (which already does HR-based effort points + friend leaderboards, but is tied to its own paid strap/membership model). Most zone-alert apps are single-purpose (just live zone alerts) and either charge a subscription or a one-time IAP ($2–$30 range seen on Zone 2 AI). None of the researched apps combine: (a) a real per-sport field-test protocol (most just use an age-based %HRmax estimate), (b) progress tracking across retests as a first-class feature, and (c) free friends/leaderboards/nudges. That combination is the differentiation worth building — v1 focuses on (a) and the progress-tracking half of (b), since the app needs to be good at the core job before the social layer matters.

**Decisions locked in with the user before planning further:**
- v1 ships the core zone-training experience only (no accounts/backend); friends/leaderboards/nudges are a distinct Phase 2.
- When Phase 2 arrives, use **CloudKit** (fits iOS-only, free tier, Sign in with Apple) rather than standing up Firebase.
- Apple Watch is a **heart-rate source only** in v1 (via HealthKit) — no separate watchOS app target yet.
- **All three sports (running, cycling, swimming)** are in scope for v1, with swimming explicitly using a different, pace-based, non-real-time coaching model, since BLE heart-rate straps cannot transmit live underwater.
- **Audio is a primary coaching channel, not a fallback** — most users don't look at their phone mid-workout, so out-of-zone alerts should be spoken cues that duck (briefly lower) whatever music/podcast is already playing, then fade it back up, rather than a screen alert people are expected to glance at.

---

## 1. Zone model & why

Use a **5-zone, threshold-heart-rate-percentage model** (Friel/Coggan-style LTHR%) for running and cycling — not raw %HRmax and not Karvonen/HRR — because the field tests below each directly produce a measured threshold HR from a real effort, and a threshold-anchored percentage plugs straight into that without needing a separately-obtained (and error-prone, self-administered) true HRmax or resting HR.

Default breakpoints (tunable constants, not hardcoded logic):
- Z1 Recovery: < 81% threshold
- **Z2 Aerobic/Endurance ("optimal" default): 81–89% threshold**
- Z3 Tempo: 90–93%
- Z4 Threshold: 94–99%
- Z5 VO2/Anaerobic: ≥ 100%

Swimming gets a structurally separate `PaceZoneSet` (not HR-based) — see 1.3.

### 1.1 Cycling baseline test — 30-minute time trial (LTHR)
Well-validated standard protocol:
1. 10-min easy spin warmup → 5-min build effort.
2. **30-minute individual time trial** at the hardest sustainable steady effort (RPE/HR-guided pacing, no power meter assumed).
3. **LTHR = average HR over the last 20 minutes** of the 30-minute TT (first 10 min discarded to exclude drift/ramp noise).
4. Feed LTHR into the shared `HRZoneCalculator` to generate the 5 cycling zones.

### 1.2 Running baseline test — incremental + talk-test cross-check
A max-effort TT is harder to self-administer safely while running, so use a gentler **incremental submaximal protocol**:
1. 10-min easy warmup jog.
2. 3–5 incremental stages (3–5 min each) at progressively harder self-selected paces. At the end of each stage, prompt a **talk-test check-in** (comfortable / difficult / can't speak) — the talk test correlates ~90%+ with ventilatory threshold in the literature, making it a legitimately strong field proxy.
3. The **talk-test crossover stage** (first *comfortable → difficult/can't* flip) gives the aerobic/ventilatory threshold estimate — the primary result.
4. Compute a **MAF 180 estimate** (180 − age, ± standard adjustments) purely as a sanity-check display value (MAF alone carries a documented ±10–12 bpm error band); flag for retest if it diverges from the measured value by >~15 bpm.
5. Back-calculate an equivalent LTHR via `aerobicThreshold ≈ 0.80–0.85 × LTHR` (a named, documented approximation constant) so running reuses the same `HRZoneCalculator` as cycling.

### 1.3 Swimming baseline test — pace-based (no real-time HR)
BLE HR can't stream live underwater, so swim zones are pace-based and never drive live coaching:
1. Primary test: **1000m/yd time trial** at best sustainable pace. HealthKit auto-detects swim workouts (from Watch or a swim-capable strap that logs internally and syncs after); reconcile via `SwimWorkoutImporter` by time-window + distance, or accept manual time entry.
2. `thresholdPaceSecPer100 = totalTime / (distance / 100)`.
3. Optional advanced flow (not on critical path): true two-distance **Critical Swim Speed** test — `CSS = (D2 − D1) / (T2 − T1)`.
4. `PaceZoneCalculator` derives 5 pace bands relative to threshold pace (tunable constants, e.g. Z2 = 4–12% slower than threshold).
5. Zone breakdown is shown **post-swim only**, from HealthKit lap/split data — swimming never touches the live coaching engine.

### 1.4 Retesting & progress tracking
No forced retest; suggested cadence **~5 weeks** (within the 4–6 week range for recreational athletes), shown as a non-blocking banner + optional local notification. Every test is stored as a dated `BaselineTestResult`, so threshold HR/pace trending over time is the primary "am I getting fitter" signal (`ProgressTrendView`, Swift Charts).

---

## 2. Xcode project structure

Single app target (SwiftUI, iOS 17+), feature-first + layer-first hybrid so each layer (Bluetooth/, HealthKit/, Zones/, Coaching/, Persistence/) already exposes a narrow protocol surface for an easy later split into Swift Packages:

```
JohnFit/
  JohnFitApp.swift               // SwiftData ModelContainer + HealthKit auth bootstrap
  Info.plist                     // NSBluetoothAlwaysUsageDescription, NSHealthShareUsageDescription,
                                  // NSHealthUpdateUsageDescription, UIBackgroundModes: [bluetooth-central]
  App/                           // AppState, DependencyContainer (composition root)
  Bluetooth/
    BluetoothHRManager.swift     // CBCentralManagerDelegate/CBPeripheralDelegate
    HeartRateMeasurementParser.swift
    BLEDevice.swift
    HRSource.swift                // protocol: AsyncStream<HRMeasurement>
  HealthKit/
    HealthKitManager.swift        // authorization
    WorkoutSessionEngine.swift    // HKWorkoutSession + HKLiveWorkoutBuilder
    HealthKitLiveHRProvider.swift // Watch-via-HealthKit HR source
    WorkoutWriter.swift           // writes HKWorkout + HKQuantitySample series
    SwimWorkoutImporter.swift     // matches auto-detected swim HKWorkouts post-hoc
  Zones/
    ZoneModel.swift                // Zone enum, per-sport % tables, MAF/CSS constants
    HRZoneCalculator.swift
    PaceZoneCalculator.swift
    ZoneTestEngine/
      FieldTestProtocol.swift
      RunningFieldTestEngine.swift
      CyclingFieldTestEngine.swift
      SwimmingFieldTestEngine.swift
      TalkTestPrompt.swift
  Coaching/
    LiveCoachingEngine.swift      // HRSource + ZoneProfile + targetZone -> CoachingState
    AlertManager.swift            // CoreHaptics + AVSpeechSynthesizer, debounced
  Persistence/
    PersistenceController.swift   // SwiftData ModelContainer
    Models/ BaselineTestResult.swift  ZoneProfile.swift  WorkoutRecord.swift  UserSettings.swift
  Simulation/
    SimulatedHRStreamProvider.swift // implements HRSource, debug-only — build in M1
  Features/
    Onboarding/  Pairing/  BaselineTest/  LiveWorkout/  History/  Settings/
  Shared/  DesignSystem/  Utilities/
JohnFitTests/    // XCTest: parser, zone math, test engines, coaching engine (mocked HRSource)
JohnFitUITests/  // XCUITest, driven via SimulatedHRStreamProvider
```

---

## 3. Data model

**HealthKit (source of truth):** `HKWorkout` (running/cycling/swimming, duration, distance, energy), `HKQuantitySample` `.heartRate` written via `HKLiveWorkoutBuilder.addSamples(_:)`, swim lap/stroke data read from auto-detected swim workouts.

**Local persistence — SwiftData** (chosen over Core Data for a fresh iOS 17+ app), UUID-keyed throughout so it's CloudKit-sync-ready later:

- `BaselineTestResult` — id, sport, date, protocolVersion, computedThresholdHR / computedThresholdPaceSecPer100, talkTestCrossoverStageIndex (running), mafReferenceEstimate (running), healthKitWorkoutUUID.
- `ZoneProfile` — id, sport, sourceTestResultID, createdAt, zoneBoundaries[]. "Active" profile per sport = most-recent `createdAt`, not a unique-constraint flag (avoids write conflicts once CloudKit sync exists).
- `WorkoutRecord` — id, healthKitWorkoutUUID, sport, targetZone, timeInZoneSeconds[Int: TimeInterval], zoneProfileIDUsed, isSwimPostSynced.
- `UserSettings` — units, retestReminderEnabled/cadenceWeeks (default 5), lastTestDatePerSport, defaultTargetZonePerSport (default 2), haptic/audio toggles, simulatedHRModeEnabled.

---

## 4. Core Bluetooth integration (GATT Heart Rate Service)

This is what makes "works with basically any BLE heart rate monitor" achievable without vendor SDKs: the **Bluetooth Heart Rate Service (UUID 0x180D)** and its **Heart Rate Measurement characteristic (0x2A37)** are an open, standard GATT profile that Polar, Wahoo, Garmin straps, and Apple's own HealthKit BLE pairing all implement identically.

- Scan for `CBUUID(string: "180D")` → discover the 0x2A37 characteristic → `setNotifyValue(true, ...)` for push updates.
- `HeartRateMeasurementParser` decodes the spec's flag byte: bit 0 selects UInt8 vs UInt16-LE HR value; bits 1–2 = sensor contact status; bit 3 = energy-expended field present; bit 4 = RR-interval fields present (captured for future HRV use, unused in v1 UI).
- Reconnection: use `CBCentralManagerOptionRestoreIdentifierKey` + `centralManager(_:willRestoreState:)`, persist the last-connected peripheral UUID, add `UIBackgroundModes: [bluetooth-central]`.
- The parsed stream feeds both `LiveCoachingEngine` (immediate zone feedback) and `WorkoutWriter` (batched into `HKLiveWorkoutBuilder`).
- **Caveat to surface in-app:** with no watchOS app in v1, Watch HR arrives via `HealthKitLiveHRProvider` polling (`HKObserverQuery`/`HKAnchoredObjectQuery`, background delivery `.immediate`) only while the user separately runs Apple's own Watch Workout app, with realistic 2–5s latency — label it "near real-time," not true real-time, so it isn't confused with the BLE strap feed.

---

## 5. Real-time coaching engine

- Unify all HR inputs behind one `HRSource` protocol (`AsyncStream<HRMeasurement>`), implemented identically by `BluetoothHRManager`, `HealthKitLiveHRProvider`, and `SimulatedHRStreamProvider` — this is what makes the whole app testable in Simulator without hardware (see §7).
- `LiveCoachingEngine` holds the active `ZoneProfile` + user-selected `targetZone` (default Zone 2, live-overridable in `LiveWorkoutView`). On each measurement: resolve current zone, compute deviation, apply **hysteresis** (require ~5–8 consecutive seconds out-of-zone before alerting, to avoid flapping on single noisy samples), publish `CoachingState`.
- `AlertManager`: distinct `CHHapticEngine` patterns for "too high"/"too low" (falls back to `UINotificationFeedbackGenerator` on devices without Taptic Engine), **plus a ducked spoken cue as the primary channel** — see below.
- Swimming structurally never instantiates `LiveCoachingEngine` (it only ever produces a `PaceZoneSet`, which the engine doesn't accept) — zone feedback for swims is post-hoc only.

### 5.1 Audio coaching with music ducking

Since most users train with music/podcasts playing and won't be looking at the screen, spoken cues are designed to interrupt the user's existing audio as briefly and unobtrusively as possible, then hand it back — the same pattern Maps/Waze use for turn directions over Spotify:

- `AudioCoachSession` (new class inside `Coaching/`) wraps an `AVAudioSession` configured with category `.playback` and option `.duckOthers` (adding `.mixWithOthers` is not used here — `.duckOthers` alone is what tells the system to automatically lower other apps' audio while this session is active, without silencing it).
- On an alert firing (already debounced by `LiveCoachingEngine`'s hysteresis, so cues can't stack rapidly): `AudioCoachSession.activate()` → the system ducks the user's music automatically → `AVSpeechSynthesizer.speak(_:)` with a short (~2–3 word) utterance, e.g. "Ease up" / "Pick it up" rather than a full sentence, kept brief on purpose so the duck is as short as possible → on `speechSynthesizer(_:didFinish:)`, call `AudioCoachSession.deactivate(options: .notifyOthersOnDeactivation)`, which signals other apps to restore their volume (the fade-back-up the user asked for is the system's own restoration curve, not something to hand-roll).
- A minimum cooldown between spoken cues (independent of the haptic cooldown, e.g. ~20–30s) prevents "Ease up… ease up… ease up" chatter if the user hovers right at a zone boundary — this is a separate, audio-specific debounce layered on top of `LiveCoachingEngine`'s existing per-alert hysteresis.
- Respect `UserSettings.audioAlertsEnabled` (Settings toggle from §6) and skip speaking entirely — haptics-only — when the phone is in silent/mute mode is *not* forced: `.duckOthers`/`AVSpeechSynthesizer` intentionally plays through the ringer switch for safety-relevant coaching, matching how navigation apps behave; call this out explicitly in the Settings copy so it isn't surprising.
- This only exercises correctly with real backgrounded audio (e.g., actual Spotify/Music/Podcasts playback) and real hardware output — add it to the M4 on-device checklist in §9 rather than assuming it's covered by unit tests. `AlertManager`'s decision logic (which phrase, cooldown timing) stays unit-testable in isolation; only the actual ducking/fade behavior needs a real device with real music playing.

---

## 6. Screens / flows (v1)

1. **Onboarding** — Welcome → Bluetooth/HealthKit permission rationale → HealthKit auth → `DevicePairingView` (BLE scan/connect, or "use Apple Watch instead", or skip).
2. **Baseline test flow** — `SportPickerView` → `RunningTestView` (staged timer + talk-test prompts) / `CyclingTestView` (warmup + 30-min TT) / `SwimmingTestView` (pre-swim instructions + post-swim HK sync or manual entry) → `TestResultSummaryView` (computed threshold + generated zones, accept/redo).
3. **LiveWorkoutView** (run/bike only) — start (sport, target-zone confirm, HR source check) → in-progress (HR, zone gauge, elapsed/distance, alert overlay, pause/end) → summary (time-in-zone chart, save to HealthKit).
4. **SwimSyncView** — post-swim confirmation + pace-zone breakdown from HK lap data (no live UI).
5. **WorkoutHistoryListView → WorkoutDetailView** — HR/pace graph (Swift Charts), time-in-zone breakdown.
6. **ProgressTrendView** — per-sport threshold trend over time + time-in-zone trend across workouts.
7. **SettingsView** — target-zone override per sport, retest reminder cadence/toggle, manage/forget BLE device + simulated-HR debug toggle, units.

---

## 7. Milestones

1. **M1** — BLE HR connectivity + live HR display, **and** `SimulatedHRStreamProvider` (build now, not later, so every following milestone is Simulator-testable).
2. **M2** — HealthKit foundation (auth, `WorkoutSessionEngine` skeleton, `HealthKitLiveHRProvider` with latency caveat) + SwiftData `PersistenceController` and core models.
3. **M3** — Zone model + running baseline test → stored `ZoneProfile`.
4. **M4** — Live run coaching (`LiveCoachingEngine`, `AlertManager`, `AudioCoachSession` music-ducking cues, `LiveWorkoutView`, `WorkoutWriter`) — first true end-to-end vertical slice.
5. **M5** — Cycling baseline test + coaching reuse (should need near-zero new coaching code if M4 is built sport-generic).
6. **M6** — Swimming baseline test + post-sync logging — architecturally isolated from live coaching, can run in parallel with M5.
7. **M7** — History/progress trends + full Settings (Swift Charts, retest local notifications).
8. **M8 (hardening)** — onboarding polish, empty states, background BLE reconnection edge cases, accessibility (zone gauge must not rely on color alone), mid-workout permission-revocation/disconnection handling.

---

## 8. Future social/CloudKit seam (not built now)

All SwiftData entities are UUID-keyed with "active" state resolved by most-recent timestamp rather than a hard uniqueness constraint, specifically so concurrent multi-device writes won't conflict once sync exists. When Phase 2 (friends/leaderboards/nudges) ships: (a) switch `ModelConfiguration` to `cloudKitDatabase: .private(...)`; (b) add a new `Social/` module with `UserProfile`/`Friendship`/`LeaderboardEntry` entities that *reference* `WorkoutRecord`/`BaselineTestResult` by UUID rather than modifying them; (c) any "share to friends" action produces a derived, privacy-filtered summary record rather than exposing raw models.

---

## 9. Verification

**Simulator + unit tests (no hardware needed):**
- `HeartRateMeasurementParser` — fixture byte sequences per the GATT spec (8-bit/16-bit flags, with/without energy/RR fields).
- `HRZoneCalculator` / `PaceZoneCalculator` — exact boundary math per sport table.
- Each `FieldTestEngine` — synthetic time series through the state machine; assert stage transitions, talk-test crossover detection, final threshold computation.
- `LiveCoachingEngine` — mocked `HRSource`; assert zone transitions, hysteresis timing, alert firing, target-zone override.
- SwiftData layer — `ModelConfiguration(isStoredInMemoryOnly: true)` for CRUD, active-profile resolution, retest-cadence date math.
- Full app UI (onboarding, pairing with a fake device list, live workout, history/progress with seeded records) driven via `SimulatedHRStreamProvider` + in-memory store — covers the large majority of the UI with zero hardware.

**Requires a real device + real hardware (Simulator can't do these — no BLE radio, `HKHealthStore.isHealthDataAvailable()` is false):**
- Real CoreBluetooth scan/connect to a physical strap (Polar H10 / Wahoo TICKR / Garmin HRM).
- Real HealthKit read/write and auth prompts.
- Apple Watch as HR source, including manual latency verification.
- Background BLE reconnection/state restoration.
- Outdoor GPS/CoreLocation distance accuracy.
- End-to-end swim test in a real pool, validating `SwimWorkoutImporter` against a real auto-detected HK swim workout.
- `AudioCoachSession` music ducking — must be checked with real backgrounded audio (Music/Spotify/Podcasts actually playing) on a real device: confirm the duck is audible but brief, the spoken phrase is intelligible over the ducked track, volume restores smoothly after speaking, and cues respect the cooldown instead of chattering near a zone boundary.

Run a short manual on-device checklist for these before marking M1, M2, M4, and M6 "done."
