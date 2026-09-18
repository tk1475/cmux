import Foundation

/// Resolves a window's current selection into a fail-closed workspace target.
public struct CloudWorkspaceMachineContext: Equatable, Sendable {
    /// The resolved target.
    public let target: CloudWorkspaceMachineTarget

    /// Resolves the Machines selection before an asynchronous operation begins.
    /// - Parameters:
    ///   - selection: The complete Machines tree selection snapshot.
    ///   - selectedWorkspaceCloudMachineID: The selected workspace's Cloud binding.
    ///   - machinesPanelOwnsFocus: Whether the Machines panel owns window focus.
    public init(
        selection: CloudWorkspaceMachineSelection,
        selectedWorkspaceCloudMachineID: String?,
        machinesPanelOwnsFocus: Bool
    ) {
        if machinesPanelOwnsFocus {
            switch selection {
            case .cloud(let id) where !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
                target = .cloud(id.trimmingCharacters(in: .whitespacesAndNewlines))
            case .pending, .cloud:
                // A pending row, or a Cloud row whose identity is blank, can
                // never resolve to a machine; fail closed rather than fall back
                // to this Mac or to any other machine.
                target = .unavailable
            case .local, .none:
                target = .local
            }
        } else {
            let value = selectedWorkspaceCloudMachineID?.trimmingCharacters(in: .whitespacesAndNewlines)
            target = value?.isEmpty == false ? .cloud(value!) : .local
        }
    }
}
