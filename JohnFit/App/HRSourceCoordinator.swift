import Combine
import Foundation

/// Owns the app's single `BluetoothHRManager`/`SimulatedHRStreamProvider`
/// instances and republishes readings as `latestMeasurement`.
///
/// This exists because `AsyncStream` delivers each value to exactly one
/// iterator — if the pairing screen and a workout recorder each ran their own
/// `for await` loop over the same `HRSource`, readings would be split between
/// them unpredictably instead of both seeing every reading. Everything that
/// needs live HR (display, `WorkoutRecordingEngine`) reads `latestMeasurement`
/// instead of consuming an `HRSource` stream directly; this coordinator is the
/// only thing that ever does.
@MainActor
final class HRSourceCoordinator: ObservableObject {
    enum Source: String, CaseIterable, Identifiable {
        case bluetooth = "Heart Rate Monitor"
        case simulated = "Simulated (Debug)"
        var id: String { rawValue }
    }

    let bluetooth = BluetoothHRManager()
    let simulator = SimulatedHRStreamProvider()

    @Published private(set) var activeSource: Source = .bluetooth
    @Published private(set) var latestMeasurement: HRMeasurement?

    private var consumerTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        // Nested ObservableObjects don't auto-propagate change notifications to
        // views observing only this coordinator, so forward theirs into ours.
        bluetooth.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        simulator.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        switchTo(.bluetooth)
    }

    func switchTo(_ source: Source) {
        consumerTask?.cancel()
        simulator.stop()
        latestMeasurement = nil
        activeSource = source

        let stream: AsyncStream<HRMeasurement>
        switch source {
        case .bluetooth:
            stream = bluetooth.measurements
        case .simulated:
            simulator.start()
            stream = simulator.measurements
        }

        consumerTask = Task { [weak self] in
            for await measurement in stream {
                self?.latestMeasurement = measurement
            }
        }
    }
}
