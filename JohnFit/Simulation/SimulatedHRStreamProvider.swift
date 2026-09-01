import Foundation

/// A fake `HRSource` that emits a slowly-wandering heart rate, so the rest of
/// the app — coaching, workout recording, UI — can be built and exercised in
/// the Simulator (or on a device without a strap on hand) well before Core
/// Bluetooth/HealthKit hardware is involved. Debug/dev-tooling only; never
/// wired up as a real HR source for a recorded workout.
@MainActor
final class SimulatedHRStreamProvider: ObservableObject, HRSource {
    @Published private(set) var isRunning = false
    @Published private(set) var latestMeasurement: HRMeasurement?

    let measurements: AsyncStream<HRMeasurement>
    private let continuation: AsyncStream<HRMeasurement>.Continuation
    private var task: Task<Void, Never>?

    /// BPM the wander is centered on, and how far it's allowed to drift.
    var centerBPM: Double = 135
    var wanderRange: Double = 12
    var tickInterval: TimeInterval = 1.0

    init() {
        var continuation: AsyncStream<HRMeasurement>.Continuation!
        self.measurements = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    func start() {
        guard task == nil else { return }
        isRunning = true
        let center = centerBPM
        let range = wanderRange
        let interval = tickInterval
        task = Task { [weak self] in
            var currentBPM = center
            while !Task.isCancelled {
                let drift = Double.random(in: -3...3)
                currentBPM = min(max(currentBPM + drift, center - range), center + range)
                let measurement = HRMeasurement(beatsPerMinute: Int(currentBPM.rounded()), sensorContactDetected: true)
                await MainActor.run { [weak self] in
                    self?.latestMeasurement = measurement
                    self?.continuation.yield(measurement)
                }
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
    }
}
