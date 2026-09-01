import SwiftData
import SwiftUI

struct WorkoutHistoryListView: View {
    @Query(sort: \WorkoutRecord.startedAt, order: .reverse) private var workouts: [WorkoutRecord]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "figure.run",
                        description: Text("Start a workout from the Workout tab to see it here.")
                    )
                } else {
                    List {
                        ForEach(workouts) { workout in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(workout.sport.displayName)
                                        .font(.headline)
                                    Spacer()
                                    Text(workout.startedAt, style: .date)
                                        .foregroundStyle(.secondary)
                                }
                                HStack(spacing: 16) {
                                    Label(durationString(workout.duration), systemImage: "clock")
                                    if let avg = workout.averageBPM {
                                        Label("\(avg) avg", systemImage: "heart.fill")
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("History")
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(workouts[index])
        }
    }

    private func durationString(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}

#Preview {
    WorkoutHistoryListView()
}
