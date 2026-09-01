# JohnFit

A free iOS app that keeps you in your optimal cardio training zone (Zone 2 by
default, user-overridable) using any Bluetooth heart-rate monitor, with a real
per-sport baseline test — not an age-based guess — to find your zones for
running, cycling, and swimming.

See [`docs/PLAN.md`](docs/PLAN.md) for the full product/technical plan,
including the zone model, per-sport baseline-test protocols, architecture, and
milestone breakdown. This repo currently implements:

- **M1** — BLE heart-rate connectivity (any strap using the standard GATT
  Heart Rate Service) and a simulated HR stream for hardware-free development.
- **M2** — local workout recording and history, persisted with SwiftData.
  This is HealthKit-free for now: HealthKit requires a paid Apple Developer
  account to provision, and this project is currently built for free
  sideloading (see below). See docs/PLAN.md for the migration note.

No Mac is required to build and install this — see **Building without a Mac**
below.

## Building without a Mac

Without a Mac there's no local Xcode, Simulator, or way to run the test
suite — so this repo builds and **tests itself via GitHub Actions** on every
push, using a macOS runner, then uploads an unsigned `.ipa` you can sideload
onto your iPhone from a Windows PC using [AltStore](https://altstore.io).
Check the **Actions** tab after each push: a red ✗ means a unit test failed
or the build broke — that's the only feedback loop available without a Mac,
so it's worth checking before assuming a change works.

1. **One-time setup**, on your Windows PC and iPhone:
   - Install **AltServer** on Windows from [altstore.io](https://altstore.io).
   - Plug in your iPhone (or set up Wi-Fi sync), then from AltServer's system
     tray icon choose **Install AltStore** and pick your device — this
     installs the AltStore app on your phone using your (free) Apple ID.
   - On the iPhone, go to **Settings → General → VPN & Device Management** and
     trust the developer certificate for your Apple ID.
   - Keep AltServer running on your PC and your phone on the same Wi-Fi
     periodically (AltStore prompts you) — a free Apple ID's apps expire every
     7 days and need this to auto-refresh. Exact menu wording can drift
     between AltServer versions; altstore.io/faq has the current steps.

2. **Every time you want the latest build:**
   - Go to this repo's **Actions** tab on GitHub, open the newest run of
     "Build IPA," and download the `JohnFit-unsigned-ipa` artifact (a zip
     containing `JohnFit.ipa`).
   - Get that `.ipa` onto your iPhone (AirDrop, iCloud Drive, email — whatever
     gets it into the Files app).
   - Open it from the Files app and share it to **AltStore**, or add it from
     AltStore's **My Apps → +**. AltServer must be running on your PC and the
     phone on the same Wi-Fi network, since that's what actually signs and
     installs the app.

Once you're ready to distribute this more easily (TestFlight, no 7-day
resign limit) or need HealthKit, enrolling in the paid Apple Developer
Program ($99/year) removes both constraints — see docs/PLAN.md.

## Building with Xcode (if you get access to a Mac later)

- macOS with Xcode 15+ (iOS 17 deployment target)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

The `.xcodeproj` is generated, not committed, so the project stays diffable in
`project.yml`.

```sh
xcodegen generate
open JohnFit.xcodeproj
```

Run the `JohnFit` scheme on a simulator or device. On first launch the app
defaults to the **Simulated (Debug)** heart-rate source, so you can see live
BPM update without any hardware — switch to **Heart Rate Monitor** to scan for
a real BLE strap (Polar H10, Wahoo TICKR, Garmin HRM, etc.) once you have one
on hand. Real Bluetooth scanning only works on a physical device; the
Simulator has no BLE radio.

Run tests with `xcodebuild test -scheme JohnFit -destination 'platform=iOS Simulator,name=iPhone 15'`
or via Xcode's Test navigator.

## Project layout

```
JohnFit/
  App/            App entry point, DependencyContainer, HRSourceCoordinator
  Bluetooth/      GATT Heart Rate Service (0x180D/0x2A37) scanning + parsing
  Simulation/     Debug-only fake HR stream, so most of the app is testable
                  without hardware
  Workouts/       Workout recording engine
  Persistence/    SwiftData models and container
  Shared/         Cross-feature types (SportType, etc.)
  Features/       SwiftUI screens, one folder per flow
JohnFitTests/     Unit tests (parser, zone math, etc. as milestones land)
docs/PLAN.md      Full implementation plan and roadmap
.github/workflows/build-ipa.yml   CI build producing a sideloadable .ipa
```
