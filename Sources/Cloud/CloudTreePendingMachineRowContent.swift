import CmuxFoundation
import SwiftUI

/// A machine that does not exist yet (or failed to): the row the Machines
/// panel shows from the moment the sheet's Create is pressed until the fleet
/// list returns the real machine. Mirrors ``CloudTreeMachineRowContent``'s
/// two layouts so the row sits in the same column grid as its neighbours;
/// the icon slot carries a spinner while running and a warning once failed.
struct CloudTreePendingMachineRowContent: View {
    let operation: MachineCreateOperation
    var style: CloudTreeStyle = CloudTreeStyleStore.current
    @Environment(\.cmuxGlobalFontMagnificationPercent) private var magnification

    private var layout: CloudTreeRowLayout { CloudTreeRowLayout(style: style, magnification: magnification) }

    var body: some View {
        switch style.machineRowLayout {
        case .singleLine:
            CloudTreeMachineBand(style: style) {
                HStack(alignment: .center, spacing: layout.iconGap) {
                    leadingGlyph
                    HStack(alignment: .firstTextBaseline, spacing: layout.detailGap) {
                        name
                        status
                    }
                    Spacer(minLength: layout.trailingGap)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(operation.summaryLine)
        case .twoLine:
            HStack(alignment: .top, spacing: layout.iconGap) {
                leadingGlyph
                    .frame(height: layout.scaled(style.machineNameLineHeight))
                VStack(alignment: .leading, spacing: layout.scaled(CloudTreeRowGrid.machineLineSpacing)) {
                    name
                        .frame(height: layout.scaled(style.machineNameLineHeight))
                    status
                        .frame(height: layout.scaled(style.machineSubtitleLineHeight))
                }
                Spacer(minLength: layout.trailingGap)
            }
            .padding(.vertical, layout.scaled(style.machineVerticalPadding))
            .padding(.trailing, CloudTreeRowGrid.trailingPadding)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(operation.summaryLine)
        }
    }

    @ViewBuilder
    private var leadingGlyph: some View {
        if operation.isRunning {
            ProgressView()
                .controlSize(.mini)
                .frame(width: layout.iconSlot, alignment: .center)
        } else {
            Image(systemName: "exclamationmark.triangle.fill")
                .cmuxFont(size: style.iconSize, weight: .medium)
                .foregroundStyle(.orange)
                .frame(width: layout.iconSlot, alignment: .center)
        }
    }

    private var name: some View {
        Text(operation.request.displayName)
            .cmuxFont(size: style.machineNameSize, weight: style.machineBand ? .semibold : .medium, design: style.fontDesign)
            .foregroundStyle(operation.isRunning ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var status: some View {
        Text(operation.statusLabel)
            .cmuxFont(size: style.detailSize, design: style.fontDesign)
            .foregroundStyle(operation.isRunning ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.orange.opacity(0.9)))
            .lineLimit(1)
            .truncationMode(.tail)
    }
}
