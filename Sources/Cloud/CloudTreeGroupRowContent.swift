import CmuxFoundation
import SwiftUI

/// Renders one Cloud tree section header: a category glyph in the shared icon
/// slot, the title, and an optional count, so a group sits on the same columns
/// as every other row at its depth.
struct CloudTreeGroupRowContent: View {
    let title: String
    let icon: String
    let count: Int?
    let style: CloudTreeStyle
    @Environment(\.cmuxGlobalFontMagnificationPercent) private var magnification

    var body: some View {
        let layout = CloudTreeRowLayout(style: style, magnification: magnification)
        HStack(alignment: .center, spacing: layout.iconGap) {
            CloudTreeRowIcon(style: style, systemName: icon, tint: .secondary)
            HStack(alignment: .firstTextBaseline, spacing: layout.detailGap) {
                Text(style.groupLabelStyle == .uppercased ? title.uppercased() : title)
                    .tracking(style.groupLabelStyle == .uppercased ? 0.8 : 0)
                    .cmuxFont(size: style.groupLabelSize, weight: .medium, design: style.fontDesign)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if style.showsGroupCounts, let count {
                    Text(String(count))
                        .cmuxFont(size: style.detailSize, design: style.fontDesign, monospacedDigit: true)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.trailing, CloudTreeRowGrid.trailingPadding)
    }
}
