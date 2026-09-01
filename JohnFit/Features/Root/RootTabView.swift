import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            DevicePairingView()
                .tabItem { Label("Connect", systemImage: "antenna.radiowaves.left.and.right") }

            LiveWorkoutView()
                .tabItem { Label("Workout", systemImage: "figure.run") }

            WorkoutHistoryListView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(HRSourceCoordinator())
}
