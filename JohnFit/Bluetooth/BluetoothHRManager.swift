import CoreBluetooth
import Foundation

/// Scans for, connects to, and streams readings from any BLE peripheral that
/// advertises the standard Heart Rate Service (0x180D). Publishes state for
/// SwiftUI and exposes readings via `HRSource` for the coaching/recording layers.
///
/// CoreBluetooth calls delegate methods on the queue passed at init (here, the
/// main queue, since we pass `nil`), but the delegate protocols themselves
/// aren't actor-isolated, so conformances are `nonisolated` and hop back to
/// the main actor to touch published state.
@MainActor
final class BluetoothHRManager: NSObject, ObservableObject, HRSource {
    static let heartRateServiceUUID = CBUUID(string: "180D")
    static let heartRateMeasurementCharacteristicUUID = CBUUID(string: "2A37")

    enum ConnectionState: Equatable {
        case idle
        case scanning
        case connecting(BLEDevice)
        case connected(BLEDevice)
        case disconnected
        case bluetoothUnavailable
    }

    @Published private(set) var connectionState: ConnectionState = .idle
    @Published private(set) var discoveredDevices: [BLEDevice] = []
    @Published private(set) var latestMeasurement: HRMeasurement?

    let measurements: AsyncStream<HRMeasurement>
    private let measurementContinuation: AsyncStream<HRMeasurement>.Continuation

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]

    private static let lastConnectedPeripheralIDKey = "JohnFit.lastConnectedPeripheralID"
    private static let restoreIdentifier = "JohnFit.BluetoothHRManager"

    override init() {
        var continuation: AsyncStream<HRMeasurement>.Continuation!
        self.measurements = AsyncStream { continuation = $0 }
        self.measurementContinuation = continuation
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [
                CBCentralManagerOptionRestoreIdentifierKey: Self.restoreIdentifier,
                CBCentralManagerOptionShowPowerAlertKey: true,
            ]
        )
    }

    func startScan() {
        guard centralManager.state == .poweredOn else { return }
        discoveredDevices = []
        discoveredPeripherals = [:]
        connectionState = .scanning
        centralManager.scanForPeripherals(
            withServices: [Self.heartRateServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScan() {
        centralManager.stopScan()
        if connectionState == .scanning {
            connectionState = .idle
        }
    }

    func connect(to device: BLEDevice) {
        guard let peripheral = discoveredPeripherals[device.id] else { return }
        stopScan()
        connectionState = .connecting(device)
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }

    private func persistLastConnected(_ identifier: UUID) {
        UserDefaults.standard.set(identifier.uuidString, forKey: Self.lastConnectedPeripheralIDKey)
    }

    /// Reconnects to the last-paired strap on launch/relaunch, per Apple's
    /// recommended `retrievePeripherals(withIdentifiers:)` pattern, so the user
    /// doesn't have to re-scan every workout.
    private func attemptAutoReconnect() {
        guard
            let idString = UserDefaults.standard.string(forKey: Self.lastConnectedPeripheralIDKey),
            let uuid = UUID(uuidString: idString)
        else { return }
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
        guard let peripheral = peripherals.first else { return }
        discoveredPeripherals[peripheral.identifier] = peripheral
        peripheral.delegate = self
        connectionState = .connecting(BLEDevice(peripheral: peripheral))
        centralManager.connect(peripheral, options: nil)
    }
}

extension BluetoothHRManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                if connectionState == .idle {
                    attemptAutoReconnect()
                }
            case .poweredOff, .unauthorized, .unsupported:
                connectionState = .bluetoothUnavailable
            default:
                break
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] else { return }
        Task { @MainActor in
            for peripheral in peripherals {
                discoveredPeripherals[peripheral.identifier] = peripheral
                peripheral.delegate = self
                if peripheral.state == .connected {
                    connectedPeripheral = peripheral
                    connectionState = .connected(BLEDevice(peripheral: peripheral))
                }
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            discoveredPeripherals[peripheral.identifier] = peripheral
            let device = BLEDevice(peripheral: peripheral, rssi: RSSI.intValue)
            if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
                discoveredDevices[index] = device
            } else {
                discoveredDevices.append(device)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectedPeripheral = peripheral
            peripheral.delegate = self
            peripheral.discoverServices([Self.heartRateServiceUUID])
            connectionState = .connected(BLEDevice(peripheral: peripheral))
            persistLastConnected(peripheral.identifier)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionState = .disconnected
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            if connectedPeripheral?.identifier == peripheral.identifier {
                connectedPeripheral = nil
            }
            connectionState = .disconnected
        }
    }
}

extension BluetoothHRManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == Self.heartRateServiceUUID {
            peripheral.discoverCharacteristics([Self.heartRateMeasurementCharacteristicUUID], for: service)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == Self.heartRateMeasurementCharacteristicUUID {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard
            characteristic.uuid == Self.heartRateMeasurementCharacteristicUUID,
            let data = characteristic.value,
            let measurement = HeartRateMeasurementParser.parse(data)
        else { return }
        Task { @MainActor in
            latestMeasurement = measurement
            measurementContinuation.yield(measurement)
        }
    }
}
