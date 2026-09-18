import Testing
@testable import CmuxCloudMachines

struct CloudWorkspaceMachineContextTests {
    @Test func selectedCloudRowWinsWhenMachinesPanelHasFocus() {
        let context = CloudWorkspaceMachineContext(
            selection: .cloud(" machine-a "),
            selectedWorkspaceCloudMachineID: "machine-b",
            machinesPanelOwnsFocus: true
        )
        #expect(context.target == .cloud("machine-a"))
    }

    @Test func emptyFocusedSelectionDoesNotResurrectWorkspaceBinding() {
        let context = CloudWorkspaceMachineContext(
            selection: .none,
            selectedWorkspaceCloudMachineID: "machine-b",
            machinesPanelOwnsFocus: true
        )
        #expect(context.target == .local)
    }

    @Test func pendingSelectionFailsClosed() {
        let context = CloudWorkspaceMachineContext(
            selection: .pending,
            selectedWorkspaceCloudMachineID: nil,
            machinesPanelOwnsFocus: true
        )
        #expect(context.target == .unavailable)
    }

    @Test func selectedWorkspaceSuppliesCloudMachineWhenSidebarIsNotFocused() {
        let context = CloudWorkspaceMachineContext(
            selection: .none,
            selectedWorkspaceCloudMachineID: "machine-b",
            machinesPanelOwnsFocus: false
        )
        #expect(context.target == .cloud("machine-b"))
    }

    @Test func blankCloudSelectionFailsClosedWhileMachinesPanelHasFocus() {
        let context = CloudWorkspaceMachineContext(
            selection: .cloud("  "),
            selectedWorkspaceCloudMachineID: "machine-b",
            machinesPanelOwnsFocus: true
        )
        #expect(context.target == .unavailable)
    }

    @Test func blankCloudSelectionIsIgnoredWhenSidebarIsNotFocused() {
        let context = CloudWorkspaceMachineContext(
            selection: .cloud(""),
            selectedWorkspaceCloudMachineID: nil,
            machinesPanelOwnsFocus: false
        )
        #expect(context.target == .local)
    }
}
