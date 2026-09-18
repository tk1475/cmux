import CmuxFoundation
import SwiftUI

/// A one-line explanatory row (connecting, asleep, empty, link error) on the
/// same grid as its siblings: the state glyph or spinner in the icon slot,
/// then the text in the title column.
struct CloudTreePlaceholderContent: View {
    let placeholder: CloudTreePlaceholder
    let style: CloudTreeStyle
    @Environment(\.cmuxGlobalFontMagnificationPercent) private var magnification

    var body: some View {
        let layout = CloudTreeRowLayout(style: style, magnification: magnification)
        HStack(alignment: .center, spacing: layout.iconGap) {
            switch placeholder.style {
            case .connecting:
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: layout.iconSlot, alignment: .center)
            case .error:
                CloudTreeRowIcon(style: style, systemName: "exclamationmark.triangle", tint: .secondary)
            case .dimmed:
                CloudTreeRowIcon(style: style, systemName: "moon.zzz", tint: .secondary, dimmed: true)
            }
            Text(placeholder.text)
                .cmuxFont(size: style.detailSize + 1, design: style.fontDesign)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.trailing, CloudTreeRowGrid.trailingPadding)
    }
}
