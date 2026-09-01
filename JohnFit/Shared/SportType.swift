import Foundation

/// The three sports JohnFit supports. Kept as a closed set (no catch-all
/// "general" case) since every later milestone — baseline testing, zone
/// coaching — is defined per sport.
enum SportType: String, Codable, CaseIterable, Identifiable {
    case running
    case cycling
    case swimming

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .running: "Running"
        case .cycling: "Cycling"
        case .swimming: "Swimming"
        }
    }
}
