import SwiftUI

/// Pick a heart-rate source (a real BLE strap, or the debug simulator),
/// connect, and watch live BPM update. Reads from the app-wide
/// `HRSourceCoordinator` rather than owning its own managers, since only one
/// consumer may drain a given `HRSource`'s stream at a time.
struct DevicePairingView: View {
    @EnvironmentObject private var coordinator: HRSourceCoordinator

    var body: some View {
        NavigationStack {
            List {
                Section("Heart Rate Source") {
                    Picker("Source", selection: sourceBinding) {
                        ForEach(HRSourceCoordinator.Source.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if coordinator.activeSource == .bluetooth {
                    bluetoothSection
                }

                Section("Live Heart Rate") {
                    if let bpm = coordinator.latestMeasurement?.beatsPerMinute {
                        Text("\(bpm) BPM")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                    } else {
                        Text("Waiting for a reading…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Connect")
        }
    }

    private var sourceBinding: Binding<HRSourceCoordinator.Source> {
        Binding(
            get: { coordinator.activeSource },
            set: { coordinator.switchTo($0) }
        )
    }

    @ViewBuilder
    private var bluetoothSection: some View {
        Section("Devices") {
            switch coordinator.bluetooth.connectionState {
            case .bluetoothUnavailable:
                Text("Turn on Bluetooth to find a heart rate monitor.")
                    .foregroundStyle(.secondary)
            default:
                Button(coordinator.bluetooth.connectionState == .scanning ? "Scanning…" : "Scan for Devices") {
                    coordinator.bluetooth.startScan()
                }
                .disabled(coordinator.bluetooth.connectionState == .scanning)

                ForEach(coordinator.bluetooth.discoveredDevices) { device in
                    Button {
                        coordinator.bluetooth.connect(to: device)
                    } label: {
                        HStack {
                            Text(device.name)
                            Spacer()
                            if case .connected(let connected) = coordinator.bluetooth.connectionState, connected.id == device.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    DevicePairingView()
        .environmentObject(HRSourceCoordinator())
}
