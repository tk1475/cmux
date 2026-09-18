import Foundation

/// Codable state for one account/team scope: the remembered machine order and the pinned identities.
struct CloudMachinePinStoreState: Codable, Equatable {
    /// Machine identities in the order they were first seen, pinned machines moved to the front when pinned.
    var order: [String] = []
    /// Machine identities the person pinned in this scope.
    var pinned: Set<String> = []
}
