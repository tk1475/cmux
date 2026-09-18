import CmuxFoundation
import SwiftUI

/// This Mac's header row, on the same grid as the cloud machine row: the laptop
/// glyph in the shared icon slot, then the name. Single- or two-line per the style.
struct CloudTreeLocalMachineRowContent: View {
    let row: CloudTreeLocalMachineRow
    var style: CloudTreeStyle = CloudTreeStyleStore.current
    @Environment(\.cmuxGlobalFontMagnificationPercent) private var magnification

    private var layout: CloudTreeRowLayout { CloudTreeRowLayout(style: style, magnification: magnification) }

    var body: some View {
        switch style.machineRowLayout {
        case .singleLine:
            CloudTreeMachineBand(style: style) {
                HStack(alignment: .center, spacing: layout.iconGap) {
                    icon
                    name
                    Spacer(minLength: layout.trailingGap)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(row.name)
        case .twoLine:
            CloudTreeMachineBand(style: style) {
                HStack(alignment: .top, spacing: layout.iconGap) {
                    icon.frame(height: layout.scaled(style.machineNameLineHeight))
                    VStack(alignment: .leading, spacing: layout.scaled(CloudTreeRowGrid.machineLineSpacing)) {
                        name.frame(height: layout.scaled(style.machineNameLineHeight))
                        Text(Self.summary(row))
                            .cmuxFont(size: style.detailSize + 0.5, design: style.fontDesign)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(height: layout.scaled(style.machineSubtitleLineHeight))
                    }
                    Spacer(minLength: layout.trailingGap)
                }
                .padding(.vertical, layout.scaled(style.machineVerticalPadding))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(row.name)
        }
    }

    private var icon: some View {
        CloudTreeRowIcon(style: style, systemName: "laptopcomputer", tint: CloudTreeIconPalette.machine, weight: .medium)
    }

    private var name: some View {
        Text(row.name)
            .cmuxFont(size: style.machineNameSize, weight: style.machineBand ? .semibold : .medium, design: style.fontDesign)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    /// "3 terminals · 1 browser"
    static func summary(_ row: CloudTreeLocalMachineRow) -> String {
        var parts = [CloudTreeRowContentView.count(row.terminalCount)]
        if row.browserCount > 0 {
            parts.append(
                row.browserCount == 1
                    ? String(localized: "cloudTree.local.browserCount.one", defaultValue: "1 browser")
                    : String(format: String(localized: "cloudTree.local.browserCount.other", defaultValue: "%d browsers"), row.browserCount)
            )
        }
        return parts.joined(separator: " · ")
    }
}
