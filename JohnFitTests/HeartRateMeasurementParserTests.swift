import XCTest
@testable import JohnFit

final class HeartRateMeasurementParserTests: XCTestCase {
    func testParsesUInt8HeartRateWithNoOptionalFields() {
        let data = Data([0x00, 0x4B]) // flags: UInt8 format, no optional fields; 0x4B = 75
        let measurement = HeartRateMeasurementParser.parse(data)
        XCTAssertEqual(measurement?.beatsPerMinute, 75)
        XCTAssertNil(measurement?.sensorContactDetected)
        XCTAssertNil(measurement?.energyExpendedKJ)
        XCTAssertEqual(measurement?.rrIntervals, [])
    }

    func testParsesUInt16HeartRate() {
        let data = Data([0x01, 0x8C, 0x00]) // bit0 set -> UInt16 LE; 0x008C = 140
        let measurement = HeartRateMeasurementParser.parse(data)
        XCTAssertEqual(measurement?.beatsPerMinute, 140)
    }

    func testParsesSensorContactSupportedAndDetected() {
        let data = Data([0x06, 0x46]) // bits 1+2 set (feature supported + detected); 0x46 = 70
        let measurement = HeartRateMeasurementParser.parse(data)
        XCTAssertEqual(measurement?.beatsPerMinute, 70)
        XCTAssertEqual(measurement?.sensorContactDetected, true)
    }

    func testParsesSensorContactSupportedButNotDetected() {
        let data = Data([0x04, 0x46]) // bit 2 set only (feature supported, not detected)
        let measurement = HeartRateMeasurementParser.parse(data)
        XCTAssertEqual(measurement?.sensorContactDetected, false)
    }

    func testSensorContactUnsupportedYieldsNil() {
        let data = Data([0x00, 0x46]) // neither bit set -> feature not supported
        let measurement = HeartRateMeasurementParser.parse(data)
        XCTAssertNil(measurement?.sensorContactDetected)
    }

    func testParsesEnergyExpended() {
        let data = Data([0x08, 0x50, 0x0A, 0x00]) // bit3 set; 0x50 = 80 bpm; energy LE = 10 kJ
        let measurement = HeartRateMeasurementParser.parse(data)
        XCTAssertEqual(measurement?.beatsPerMinute, 80)
        XCTAssertEqual(measurement?.energyExpendedKJ, 10)
    }

    func testParsesRRIntervals() {
        // bit4 set; RR units are 1/1024s: 1024 -> 1.0s, 512 -> 0.5s
        let data = Data([0x10, 0x4B, 0x00, 0x04, 0x00, 0x02])
        let measurement = HeartRateMeasurementParser.parse(data)
        XCTAssertEqual(measurement?.beatsPerMinute, 75)
        XCTAssertEqual(measurement?.rrIntervals.count, 2)
        XCTAssertEqual(measurement?.rrIntervals[0] ?? 0, 1.0, accuracy: 0.001)
        XCTAssertEqual(measurement?.rrIntervals[1] ?? 0, 0.5, accuracy: 0.001)
    }

    func testParsesCombinedOptionalFields() {
        // UInt16 HR + energy + one RR interval, all flags set together.
        // flags = 0b00011111 (uint16 format, contact supported+detected, energy, RR)
        let data = Data([0x1F, 0x8C, 0x00, 0x05, 0x00, 0x00, 0x02])
        let measurement = HeartRateMeasurementParser.parse(data)
        XCTAssertEqual(measurement?.beatsPerMinute, 140)
        XCTAssertEqual(measurement?.sensorContactDetected, true)
        XCTAssertEqual(measurement?.energyExpendedKJ, 5)
        XCTAssertEqual(measurement?.rrIntervals.count, 1)
        XCTAssertEqual(measurement?.rrIntervals[0] ?? 0, 0.5, accuracy: 0.001)
    }

    func testReturnsNilForEmptyData() {
        XCTAssertNil(HeartRateMeasurementParser.parse(Data()))
    }

    func testReturnsNilWhenTruncatedUInt16Value() {
        let data = Data([0x01, 0x4B]) // claims UInt16 format but only one byte follows
        XCTAssertNil(HeartRateMeasurementParser.parse(data))
    }

    func testReturnsNilWhenTruncatedEnergyField() {
        let data = Data([0x08, 0x4B, 0x0A]) // energy flag set but only one byte follows
        XCTAssertNil(HeartRateMeasurementParser.parse(data))
    }
}
