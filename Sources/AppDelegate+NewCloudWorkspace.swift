import AppKit
import CmuxCloudMachines
import Foundation

// MARK: - Explicit Cloud workspace creation

extension AppDelegate {
    /// Cmd+N and the plus menu: creates on the explicitly selected Cloud machine
    /// when the Machines tree owns the selection, refuses a selection that
    /// cannot accept creation, and otherwise creates a local workspace.
    @discardableResult
    func performNewWorkspaceSelectionAwareAction(
        tabManager: TabManager? = nil,
        event: NSEvent? = nil,
        debugSource: String = "newWorkspace"
    ) -> Bool {
        let context = tabManager.flatMap { mainWindowContext(for: $0) }
            ?? event.flatMap { mainWindowContext(forShortcutEvent: $0, debugSource: debugSource) }
            ?? preferredMainWindowContextForWorkspaceCreation(event: event, debugSource: debugSource)
        if let context {
            switch newWorkspaceMachineContext(for: context).target {
            case .unavailable:
                NSSound.beep()
                return false
            case .cloud(let machineID):
                return performNewCloudWorkspaceOnMachineAction(
                    machineID: machineID, focus: context.tabManager.selectedTabId != nil,
                    windowID: context.windowId, debugSource: debugSource
                )
            case .local:
                break
            }
        }
        return performNewWorkspaceCreationAction(
            initialSurface: .terminal, preferredTabManager: tabManager,
            event: event, debugSource: debugSource
        )
    }

    /// Records the Machines tree selection for its owning window.
    func setCloudTreeSelection(_ selection: CloudTreeSelection, in tabManager: TabManager?) {
        guard let tabManager, let context = mainWindowContext(for: tabManager) else { return }
        context.cloudTreeSelection = selection
    }

    /// Returns the last selection captured by the Machines tree in a window.
    func cloudTreeSelection(for tabManager: TabManager?) -> CloudTreeSelection {
        guard let tabManager else { return .empty }
        return mainWindowContext(for: tabManager)?.cloudTreeSelection ?? .empty
    }

    /// Resolves the explicit selection before any asynchronous operation begins.
    func newWorkspaceMachineContext(for context: MainWindowContext) -> CloudWorkspaceMachineContext {
        CloudWorkspaceMachineContext(
            selection: context.cloudTreeSelection.machine,
            selectedWorkspaceCloudMachineID: context.tabManager.selectedWorkspace?.cloudVMBinding?.vmID,
            machinesPanelOwnsFocus: context.keyboardFocusCoordinator.activeRightSidebarMode == .machines
        )
    }

    /// Creates on the explicitly selected Cloud machine, refuses a selection
    /// that cannot accept creation, or presents machine provisioning when no
    /// Cloud machine is selected. Never routes through an implicit default.
    @discardableResult
    func performNewCloudWorkspaceFromSelectionAction(
        preferredWindow: NSWindow? = nil,
        debugSource: String = "newCloudWorkspace",
        destination: CloudWorkspaceGroupDestination? = nil
    ) -> Bool {
        let context = preferredWindow.flatMap { contextForMainWindow($0) }
            ?? preferredMainWindowContextForWorkspaceCreation(event: nil, debugSource: debugSource)
        if let context {
            switch newWorkspaceMachineContext(for: context).target {
            case .cloud(let machineID):
                return performNewCloudWorkspaceOnMachineAction(
                    machineID: machineID,
                    focus: context.tabManager.selectedTabId != nil,
                    windowID: context.windowId,
                    destination: destination,
                    debugSource: debugSource
                )
            case .unavailable:
                // A pending row or a blank Cloud identity is selected: fail closed
                // instead of provisioning a machine the person did not ask for.
                NSSound.beep()
                return false
            case .local:
                break
            }
        }
        return performNewCloudWorkspaceAction(
            preferredWindow: preferredWindow,
            debugSource: debugSource,
            destination: destination
        )
    }

    /// Creates a workspace on a captured Cloud machine and never falls back to another target.
    @discardableResult
    func performNewCloudWorkspaceOnMachineAction(
        machineID: String,
        focus: Bool,
        windowID: UUID? = nil,
        destination: CloudWorkspaceGroupDestination? = nil,
        debugSource: String = "newWorkspace.cloud"
    ) -> Bool {
        guard let coordinator = cloudWorkspaceCoordinator,
              let operationController = cloudWorkspaceOperationController,
              coordinator.isAvailable else { return false }
        let capturedMachineID = machineID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !capturedMachineID.isEmpty else { return false }
        return operationController.start(
            key: "new-cloud-workspace.machine:\(capturedMachineID)"
        ) {
            guard let workspaceID = try await coordinator.createOnMachine(
                machineID: capturedMachineID,
                focus: focus,
                windowID: windowID
            ), !Task.isCancelled, coordinator.isAvailable else { return }
#if DEBUG
            cmuxDebugLog(
                "newWorkspace.cloud.completed source=\(debugSource) machine=\(capturedMachineID) " +
                    "workspace=\(workspaceID.uuidString.prefix(8))"
            )
#endif
            destination?.apply(workspaceID: workspaceID)
        } onFailure: { [weak self] error in
            self?.presentCloudWorkspaceCreationFailure(
                machineID: capturedMachineID,
                error: error,
                windowID: windowID,
                retry: { [weak self] in
                    _ = self?.performNewCloudWorkspaceOnMachineAction(
                        machineID: capturedMachineID, focus: focus, windowID: windowID,
                        destination: destination, debugSource: "\(debugSource).retry"
                    )
                }
            )
        }
    }

    /// Explains a failed create with Retry/Cancel. Only product errors map to
    /// specific copy; anything else gets generic text, because provider and
    /// transport errors can carry URLs, payloads, and environment details that
    /// belong in the private log, not in an alert.
    private func presentCloudWorkspaceCreationFailure(
        machineID: String,
        error: Error,
        windowID: UUID?,
        retry: @escaping @MainActor () -> Void
    ) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "cloudWorkspace.creation.failed.title", defaultValue: "Couldn’t create Cloud workspace")
        let detail: String
        if case CloudWorkspaceCoordinatorError.machineUnavailable = error {
            detail = String(localized: "cloudWorkspace.creation.failed.unavailable", defaultValue: "The selected Cloud machine is unavailable.")
        } else if case CloudWorkspaceCoordinatorError.targetWindowUnavailable = error {
            detail = String(localized: "cloudWorkspace.creation.failed.windowClosed", defaultValue: "The window that started the request has closed.")
        } else {
            detail = String(localized: "cloudWorkspace.creation.failed.generic", defaultValue: "cmux couldn’t reach the machine. Check that it is running and try again.")
        }
        alert.informativeText = String(
            format: String(localized: "cloudWorkspace.creation.failed.detail", defaultValue: "The workspace could not be created on %@. %@"),
            machineID, detail
        )
        alert.addButton(withTitle: String(localized: "common.retry", defaultValue: "Retry"))
        alert.addButton(withTitle: String(localized: "common.cancel", defaultValue: "Cancel"))
        let window = windowID.flatMap { id in
            mainWindowContexts.values.first(where: { $0.windowId == id }).flatMap { resolvedWindow(for: $0) }
        }
        let retryIfChosen: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .alertFirstButtonReturn else { return }
            Task { @MainActor in retry() }
        }
        if let window { alert.beginSheetModal(for: window, completionHandler: retryIfChosen) }
        else { retryIfChosen(alert.runModal()) }
    }

    /// Presents machine provisioning for the explicit New Cloud Workspace command.
    @discardableResult
    func performNewCloudWorkspaceAction(
        tabManager preferredTabManager: TabManager? = nil,
        event: NSEvent? = nil,
        preferredWindow: NSWindow? = nil,
        debugSource: String = "newCloudWorkspace",
        destination: CloudWorkspaceGroupDestination? = nil
    ) -> Bool {
        guard let operationController = cloudWorkspaceOperationController,
              operationController.isCurrentlyAvailable else { return false }
        let context = preferredTabManager.flatMap { mainWindowContext(for: $0) }
            ?? preferredWindow.flatMap { contextForMainWindow($0) }
            ?? event.flatMap { mainWindowContext(forShortcutEvent: $0, debugSource: debugSource) }
            ?? preferredMainWindowContextForWorkspaceCreation(event: event, debugSource: debugSource)
        let hostWindow = context.flatMap { resolvedWindow(for: $0) }
            ?? preferredWindow ?? event?.window ?? NSApp.keyWindow ?? NSApp.mainWindow
        guard let presenter = newMachineSheetPresenter else { return false }
        return operationController.start {
            guard let workspaceID = await presenter.presentNewMachineFetchingPlan(preferredWindow: hostWindow),
                  !Task.isCancelled,
                  operationController.isCurrentlyAvailable else { return }
            destination?.apply(workspaceID: workspaceID)
        }
    }
}
