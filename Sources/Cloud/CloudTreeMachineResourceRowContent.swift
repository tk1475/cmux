import CmuxFoundation
import SwiftUI

/// A single resource or cost row inside a machine's Resources section: the
/// metric's glyph in the shared icon slot, its label in the title column, and
/// the reading after it.
struct CloudTreeMachineResourceRowContent: View {
    let row: CloudTreeMachineResourceRow
    var style: CloudTreeStyle = CloudTreeStyleStore.current
    @Environment(\.cmuxGlobalFontMagnificationPercent) private var magnification

    var body: some View {
        let layout = CloudTreeRowLayout(style: style, magnification: magnification)
        HStack(alignment: .center, spacing: layout.iconGap) {
            CloudTreeRowIcon(style: style, systemName: row.metric.symbolName, tint: .secondary)
            HStack(alignment: .firstTextBaseline, spacing: layout.detailGap) {
                Text(row.title)
                    .cmuxFont(size: style.titleSize, design: style.fontDesign)
                    .foregroundStyle(.primary)
                    .frame(minWidth: layout.scaled(40), alignment: .leading)
                    .layoutPriority(1)
                Text(row.detail)
                    .cmuxFont(size: style.detailSize, design: style.fontDesign, monospacedDigit: true)
                    .foregroundStyle(.secondary)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .padding(.trailing, CloudTreeRowGrid.trailingPadding)
        .help(row.accessibilityLabel)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }
}
