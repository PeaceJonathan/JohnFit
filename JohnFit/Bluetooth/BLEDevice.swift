import CoreBluetooth
import Foundation

/// Lightweight, `Equatable`/`Identifiable` wrapper around a discovered
/// `CBPeripheral` so SwiftUI views never have to touch CoreBluetooth types.
struct BLEDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let rssi: Int?

    init(peripheral: CBPeripheral, rssi: Int? = nil) {
        self.id = peripheral.identifier
        self.name = peripheral.name ?? "Unknown Heart Rate Monitor"
        self.rssi = rssi
    }
}
