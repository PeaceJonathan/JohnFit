import SwiftData
import SwiftUI

/// Start/stop a workout and record HR against it. No zone coaching yet
/// (that's milestone M3+ in docs/PLAN.md) — this is plain recording, built on
/// the M1 heart-rate layer and M2 local persistence.
struct LiveWorkoutView: View {
    @EnvironmentObject private var coordinator: HRSourceCoordinator
    @Environment(\.modelContext) private var modelContext
    @StateObject private var recorder = WorkoutRecordingEngine()
    @State private var selectedSport: SportType = .running

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if !recorder.isRecording {
                    Picker("Sport", selection: $selectedSport) {
                        ForEach(SportType.allCases) { sport in
                            Text(sport.displayName).tag(sport)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                Spacer()

                VStack(spacing: 8) {
                    Text(recorder.latestBPM.map { "\($0)" } ?? "--")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                    Text("BPM")
                        .foregroundStyle(.secondary)
                }

                Text(elapsedString)
                    .font(.title2.monospacedDigit())

                Spacer()

                Button {
                    toggleRecording()
                } label: {
                    Text(recorder.isRecording ? "End Workout" : "Start Workout")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(recorder.isRecording ? .red : .accentColor)
                .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle(recorder.isRecording ? selectedSport.displayName : "Workout")
        }
    }

    private var elapsedString: String {
        let total = Int(recorder.elapsed)
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    private func toggleRecording() {
        if recorder.isRecording {
            if let record = recorder.stop() {
                modelContext.insert(record)
            }
        } else {
            recorder.start(sport: selectedSport, coordinator: coordinator)
        }
    }
}

#Preview {
    LiveWorkoutView()
        .environmentObject(HRSourceCoordinator())
}
