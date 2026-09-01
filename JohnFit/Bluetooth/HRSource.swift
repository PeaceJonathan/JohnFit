import Foundation

/// A single heart-rate reading, decoded from either a BLE strap (GATT Heart Rate
/// Service) or a simulated/HealthKit source, so downstream consumers never need
/// to know where it came from.
struct HRMeasurement: Equatable {
    let beatsPerMinute: Int
    /// `nil` when the source doesn't support contact detection at all.
    let sensorContactDetected: Bool?
    let energyExpendedKJ: Int?
    /// RR-intervals in seconds, captured for future HRV use. Empty when absent.
    let rrIntervals: [TimeInterval]
    let timestamp: Date

    init(
        beatsPerMinute: Int,
        sensorContactDetected: Bool? = nil,
        energyExpendedKJ: Int? = nil,
        rrIntervals: [TimeInterval] = [],
        timestamp: Date = Date()
    ) {
        self.beatsPerMinute = beatsPerMinute
        self.sensorContactDetected = sensorContactDetected
        self.energyExpendedKJ = energyExpendedKJ
        self.rrIntervals = rrIntervals
        self.timestamp = timestamp
    }
}

/// Anything that can supply a live stream of heart-rate readings: a BLE strap,
/// HealthKit/Watch, or the debug simulator. `LiveCoachingEngine` and workout
/// recording depend only on this protocol, never on a concrete source.
@MainActor
protocol HRSource: AnyObject {
    var measurements: AsyncStream<HRMeasurement> { get }
}
