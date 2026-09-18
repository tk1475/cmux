import SwiftUI

/// The hover-only actions at a row's trailing edge (delete, new terminal,
/// new workspace, close, cancel/retry a create). Hosted in a second, hit-testable
/// view by `CloudTreeCellView`; laid out always so hovering never reflows.
struct CloudTreeRowHoverButtons: View {
    let kind: CloudTreeNode.Kind
    let machineActions: MachineRowActions
    let nodeActions: CloudTreeNodeActions

    var body: some View {
        switch kind {
        case .machine(let machine, _):
            MachinesChromeIconButton(
                symbolName: "trash",
                accessibilityLabel: String(localized: "machines.row.delete", defaultValue: "Delete Machine"),
                isBusy: false
            ) {
                machineActions.confirmDelete(machine.id)
            }
        case .pendingMachine(let operation):
            // A running create can be cancelled from the row; a failed create
            // can be retried or dropped.
            HStack(spacing: 4) {
                if operation.isRunning {
                    xmark(String(localized: "machines.pending.cancel", defaultValue: "Cancel Create")) {
                        machineActions.create.cancel(operation.id)
                    }
                } else {
                    MachinesChromeIconButton(
                        symbolName: "arrow.counterclockwise",
                        accessibilityLabel: String(localized: "machines.pending.retry", defaultValue: "Retry Create"),
                        isBusy: false
                    ) {
                        machineActions.create.retry(operation.id)
                    }
                    xmark(String(localized: "machines.pending.dismiss", defaultValue: "Dismiss")) {
                        machineActions.create.dismiss(operation.id)
                    }
                }
            }
        case .localMachine:
            plus(String(localized: "cloudTree.menu.newTerminal", defaultValue: "New Terminal")) {
                nodeActions.newTerminal(.local, nil)
            }
        case .terminalsPool(let machine, _):
            plus(String(localized: "cloudTree.menu.newTerminal", defaultValue: "New Terminal")) {
                nodeActions.newTerminal(machine, nil)
            }
        case .displaysPool:
            EmptyView()
        case .workspacesGroup(let machine):
            plus(String(localized: "cloudTree.menu.newWorkspace", defaultValue: "New Workspace")) {
                nodeActions.newWorkspace(machine)
            }
        case .workspace(let machine, let workspace, _, _, _):
            HStack(spacing: 4) {
                plus(String(localized: "cloudTree.menu.newTerminalHere", defaultValue: "New Terminal Here")) {
                    nodeActions.newTerminal(machine, workspace.id)
                }
                if !machine.isLocal {
                    xmark(String(localized: "cloudTree.row.closeWorkspace", defaultValue: "Close Workspace\u{2026}")) {
                        nodeActions.closeWorkspace(machine, workspace)
                    }
                }
            }
        case .terminal(let row):
            if !row.resource.machine.isLocal {
                xmark(String(localized: "cloudTree.menu.killTerminal", defaultValue: "Kill Terminal\u{2026}")) {
                    nodeActions.closeTerminal(row.resource.id)
                }
            }
        default:
            EmptyView()
        }
    }
    /// Returns whether the row kind has a hover action to lay out.
    static func hasButtons(for kind: CloudTreeNode.Kind) -> Bool {
        switch kind {
        case .machine, .localMachine, .terminalsPool, .workspacesGroup, .workspace:
            return true
        case .pendingMachine:
            return true
        case .terminal(let row):
            return !row.resource.machine.isLocal
        default:
            return false
        }
    }

    private func plus(_ label: String, action: @escaping () -> Void) -> some View {
        MachinesChromeIconButton(symbolName: "plus", accessibilityLabel: label, isBusy: false, action: action)
    }

    private func xmark(_ label: String, action: @escaping () -> Void) -> some View {
        MachinesChromeIconButton(symbolName: "xmark", accessibilityLabel: label, isBusy: false, action: action)
    }
}
