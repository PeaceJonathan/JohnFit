import Combine
import Foundation

/// Records a workout: timestamped HR samples plus elapsed time, sourced from
/// whatever `HRSourceCoordinator.latestMeasurement` reports. Produces a
/// `WorkoutRecord` on `stop()` for the caller to persist.
///
/// Zone-aware coaching isn't built yet (see docs/PLAN.md milestone M3+), so
/// this only records — it doesn't yet know what zone the reader is in.
@MainActor
final class WorkoutRecordingEngine: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var latestBPM: Int?

    private var sport: SportType = .running
    private var startDate: Date?
    private var samples: [HRSamplePoint] = []
    private var measurementCancellable: AnyCancellable?
    private var timerTask: Task<Void, Never>?

    func start(sport: SportType, coordinator: HRSourceCoordinator) {
        guard !isRecording else { return }
        self.sport = sport
        isRecording = true
        elapsed = 0
        samples = []
        latestBPM = nil
        let start = Date()
        startDate = start

        measurementCancellable = coordinator.$latestMeasurement
            .compactMap { $0 }
            .sink { [weak self] measurement in
                guard let self, self.isRecording else { return }
                let offset = measurement.timestamp.timeIntervalSince(start)
                self.samples.append(HRSamplePoint(secondsSinceStart: offset, beatsPerMinute: measurement.beatsPerMinute))
                self.latestBPM = measurement.beatsPerMinute
            }

        timerTask = Task { [weak self] in
            while let self, self.isRecording {
                self.elapsed = Date().timeIntervalSince(start)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    @discardableResult
    func stop() -> WorkoutRecord? {
        guard isRecording, let startDate else { return nil }
        isRecording = false
        measurementCancellable?.cancel()
        measurementCancellable = nil
        timerTask?.cancel()
        timerTask = nil

        let record = WorkoutRecord(sport: sport, startedAt: startDate, duration: elapsed, samples: samples)
        self.startDate = nil
        samples = []
        return record
    }
}
