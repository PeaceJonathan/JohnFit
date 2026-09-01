import Foundation

/// Composition root: instances shared across the whole app, injected into
/// the SwiftUI environment from `JohnFitApp`.
@MainActor
final class DependencyContainer: ObservableObject {
    let hrCoordinator = HRSourceCoordinator()
}
