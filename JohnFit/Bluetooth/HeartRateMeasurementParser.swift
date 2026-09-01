import Foundation

/// Decodes the Bluetooth SIG **Heart Rate Measurement** characteristic
/// (service 0x180D, characteristic 0x2A37). This is a published, vendor-neutral
/// GATT profile — every compliant strap (Polar, Wahoo, Garmin, etc.) and the
/// Apple Watch's own BLE HR broadcast encode readings this exact way, which is
/// what makes "works with basically any BLE heart rate monitor" possible
/// without a vendor SDK.
///
/// Wire format (little-endian):
/// - byte 0: flags
///   - bit 0: HR value format (0 = UInt8, 1 = UInt16)
///   - bit 1: sensor contact detected (only meaningful if bit 2 is set)
///   - bit 2: sensor contact feature supported
///   - bit 3: energy expended field present (UInt16, kJ)
///   - bit 4: one or more RR-interval fields present (UInt16 each, units of 1/1024s)
/// - HR value (1 or 2 bytes, per bit 0)
/// - energy expended (2 bytes, if bit 3)
/// - RR-intervals (2 bytes each, repeated until the payload ends, if bit 4)
enum HeartRateMeasurementParser {
    private struct Flags {
        let isValueFormatUInt16: Bool
        let sensorContactFeatureSupported: Bool
        let sensorContactDetected: Bool
        let energyExpendedPresent: Bool
        let rrIntervalPresent: Bool

        init(byte: UInt8) {
            isValueFormatUInt16 = byte & 0x01 != 0
            sensorContactDetected = byte & 0x02 != 0
            sensorContactFeatureSupported = byte & 0x04 != 0
            energyExpendedPresent = byte & 0x08 != 0
            rrIntervalPresent = byte & 0x10 != 0
        }
    }

    static func parse(_ data: Data) -> HRMeasurement? {
        guard !data.isEmpty else { return nil }
        let bytes = [UInt8](data)
        let flags = Flags(byte: bytes[0])
        var offset = 1

        let bpm: Int
        if flags.isValueFormatUInt16 {
            guard bytes.count >= offset + 2 else { return nil }
            bpm = Int(littleEndianUInt16: bytes, at: offset)
            offset += 2
        } else {
            guard bytes.count >= offset + 1 else { return nil }
            bpm = Int(bytes[offset])
            offset += 1
        }

        var energyExpended: Int?
        if flags.energyExpendedPresent {
            guard bytes.count >= offset + 2 else { return nil }
            energyExpended = Int(littleEndianUInt16: bytes, at: offset)
            offset += 2
        }

        var rrIntervals: [TimeInterval] = []
        if flags.rrIntervalPresent {
            while bytes.count >= offset + 2 {
                let raw = Int(littleEndianUInt16: bytes, at: offset)
                rrIntervals.append(TimeInterval(raw) / 1024.0)
                offset += 2
            }
        }

        return HRMeasurement(
            beatsPerMinute: bpm,
            sensorContactDetected: flags.sensorContactFeatureSupported ? flags.sensorContactDetected : nil,
            energyExpendedKJ: energyExpended,
            rrIntervals: rrIntervals
        )
    }
}

private extension Int {
    init(littleEndianUInt16 bytes: [UInt8], at offset: Int) {
        self = Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
    }
}
