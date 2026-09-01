import SwiftUI

@main
struct JohnFitApp: App {
    @StateObject private var container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(container.hrCoordinator)
        }
        .modelContainer(PersistenceController.shared)
    }
}
