# JohnFit

A free iOS app that keeps you in your optimal cardio training zone (Zone 2 by
default, user-overridable) using any Bluetooth heart-rate monitor, with a real
per-sport baseline test — not an age-based guess — to find your zones for
running, cycling, and swimming.

See [`docs/PLAN.md`](docs/PLAN.md) for the full product/technical plan,
including the zone model, per-sport baseline-test protocols, architecture, and
milestone breakdown. This repo currently implements **M1**: BLE heart-rate
connectivity and a simulated HR stream for hardware-free development.

## Requirements

- macOS with Xcode 15+ (iOS 17 deployment target)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

The `.xcodeproj` is generated, not committed, so the project stays diffable in
`project.yml`.

## Getting started

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
  App/            App entry point
  Bluetooth/      GATT Heart Rate Service (0x180D/0x2A37) scanning + parsing
  Simulation/     Debug-only fake HR stream, so most of the app is testable
                  without hardware
  Features/       SwiftUI screens, one folder per flow
JohnFitTests/     Unit tests (parser, zone math, etc. as milestones land)
docs/PLAN.md      Full implementation plan and roadmap
```
