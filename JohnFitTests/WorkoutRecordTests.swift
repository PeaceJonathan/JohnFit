import XCTest
@testable import JohnFit

final class WorkoutRecordTests: XCTestCase {
    func testComputesAverageMinMaxFromSamples() {
        let samples = [
            HRSamplePoint(secondsSinceStart: 0, beatsPerMinute: 120),
            HRSamplePoint(secondsSinceStart: 10, beatsPerMinute: 140),
            HRSamplePoint(secondsSinceStart: 20, beatsPerMinute: 130),
        ]
        let record = WorkoutRecord(sport: .running, startedAt: Date(), duration: 20, samples: samples)

        XCTAssertEqual(record.averageBPM, 130)
        XCTAssertEqual(record.minBPM, 120)
        XCTAssertEqual(record.maxBPM, 140)
    }

    func testHandlesNoSamples() {
        let record = WorkoutRecord(sport: .cycling, startedAt: Date(), duration: 0, samples: [])

        XCTAssertNil(record.averageBPM)
        XCTAssertNil(record.minBPM)
        XCTAssertNil(record.maxBPM)
        XCTAssertEqual(record.samples, [])
    }

    func testSamplesRoundTripThroughEncoding() {
        let samples = [
            HRSamplePoint(secondsSinceStart: 0, beatsPerMinute: 100),
            HRSamplePoint(secondsSinceStart: 5.5, beatsPerMinute: 105),
        ]
        let record = WorkoutRecord(sport: .swimming, startedAt: Date(), duration: 5.5, samples: samples)

        let decoded = record.samples
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].beatsPerMinute, 100)
        XCTAssertEqual(decoded[1].secondsSinceStart, 5.5, accuracy: 0.001)
    }
}
