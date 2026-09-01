import Foundation
import SwiftData

/// One recorded heart-rate sample, timestamped relative to workout start.
struct HRSamplePoint: Codable {
    let secondsSinceStart: TimeInterval
    let beatsPerMinute: Int
}

/// A completed workout. This is fully local for now (no HealthKit): a free
/// Apple ID can't provision the HealthKit capability, so until this project
/// is on a paid Apple Developer account, SwiftData is the source of truth
/// rather than `HKWorkout`/`HKQuantitySample` as originally planned. See
/// docs/PLAN.md for the migration note.
@Model
final class WorkoutRecord {
    var id: UUID
    var sport: SportType
    var startedAt: Date
    var duration: TimeInterval
    var averageBPM: Int?
    var minBPM: Int?
    var maxBPM: Int?
    /// SwiftData has no native array-of-structs column, so the raw HR time
    /// series is stored as encoded JSON and decoded on demand via `samples`.
    private var encodedHRSamples: Data

    init(
        id: UUID = UUID(),
        sport: SportType,
        startedAt: Date,
        duration: TimeInterval,
        samples: [HRSamplePoint]
    ) {
        self.id = id
        self.sport = sport
        self.startedAt = startedAt
        self.duration = duration
        let bpms = samples.map(\.beatsPerMinute)
        self.averageBPM = bpms.isEmpty ? nil : bpms.reduce(0, +) / bpms.count
        self.minBPM = bpms.min()
        self.maxBPM = bpms.max()
        self.encodedHRSamples = (try? JSONEncoder().encode(samples)) ?? Data()
    }

    var samples: [HRSamplePoint] {
        (try? JSONDecoder().decode([HRSamplePoint].self, from: encodedHRSamples)) ?? []
    }
}
