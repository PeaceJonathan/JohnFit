import SwiftUI

/// M1's vertical slice: pick a heart-rate source (a real BLE strap, or the
/// debug simulator), connect, and watch live BPM update. Later milestones
/// replace the bare BPM readout with the zone-aware coaching UI, but this
/// screen — and the `HRSource` abstraction underneath it — stays the same.
struct DevicePairingView: View {
    @StateObject private var bluetooth = BluetoothHRManager()
    @StateObject private var simulator = SimulatedHRStreamProvider()

    @State private var source: HRSourceKind = .bluetooth
    @State private var displayedBPM: Int?
    @State private var streamTask: Task<Void, Never>?

    enum HRSourceKind: String, CaseIterable, Identifiable {
        case bluetooth = "Heart Rate Monitor"
        case simulated = "Simulated (Debug)"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Heart Rate Source") {
                    Picker("Source", selection: $source) {
                        ForEach(HRSourceKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if source == .bluetooth {
                    bluetoothSection
                }

                Section("Live Heart Rate") {
                    if let displayedBPM {
                        Text("\(displayedBPM) BPM")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                    } else {
                        Text("Waiting for a reading…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Connect")
            .onChange(of: source) { _, newValue in switchSource(to: newValue) }
            .onAppear { switchSource(to: source) }
            .onDisappear {
                streamTask?.cancel()
                simulator.stop()
            }
        }
    }

    @ViewBuilder
    private var bluetoothSection: some View {
        Section("Devices") {
            switch bluetooth.connectionState {
            case .bluetoothUnavailable:
                Text("Turn on Bluetooth to find a heart rate monitor.")
                    .foregroundStyle(.secondary)
            default:
                Button(bluetooth.connectionState == .scanning ? "Scanning…" : "Scan for Devices") {
                    bluetooth.startScan()
                }
                .disabled(bluetooth.connectionState == .scanning)

                ForEach(bluetooth.discoveredDevices) { device in
                    Button {
                        bluetooth.connect(to: device)
                    } label: {
                        HStack {
                            Text(device.name)
                            Spacer()
                            if case .connected(let connected) = bluetooth.connectionState, connected.id == device.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
        }
    }

    private func switchSource(to kind: HRSourceKind) {
        streamTask?.cancel()
        simulator.stop()
        displayedBPM = nil

        switch kind {
        case .bluetooth:
            streamTask = Task {
                for await measurement in bluetooth.measurements {
                    displayedBPM = measurement.beatsPerMinute
                }
            }
        case .simulated:
            simulator.start()
            streamTask = Task {
                for await measurement in simulator.measurements {
                    displayedBPM = measurement.beatsPerMinute
                }
            }
        }
    }
}

#Preview {
    DevicePairingView()
}
