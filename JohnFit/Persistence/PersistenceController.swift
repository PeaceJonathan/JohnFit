import Foundation
import SwiftData

/// SwiftData container setup. All model types the app persists must be
/// listed in `schema` below.
@MainActor
enum PersistenceController {
    static let shared: ModelContainer = {
        let schema = Schema([WorkoutRecord.self])
        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
    }()
}
