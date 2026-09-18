import CmuxFoundation
import SwiftUI

/// The fixed status column every Cloud tree row starts with: the pin glyph when
/// the row is pinned, the unread dot when it has unread attention (badged onto
/// the pin when both apply), and reserved blank space otherwise. Because the
/// column is always present, pinning or a notification never moves the icon or
/// title of any row. Immutable input keeps AppKit cell reuse independent of
/// observable stores.
struct CloudSidebarRowDecoration: ViewModifier {
    let style: CloudTreeStyle
    let isPinned: Bool
    let hasUnreadNotification: Bool
    @Environment(\.cmuxGlobalFontMagnificationPercent) private var magnification

    func body(content: Content) -> some View {
        let layout = CloudTreeRowLayout(style: style, magnification: magnification)
        HStack(alignment: .center, spacing: layout.statusGap) {
            ZStack {
                // Both indicators stay mounted: in-place outline reloads repaint
                // pin and read/unread changes without reflowing the row.
                Image(systemName: "pin.fill")
                    .cmuxFont(size: CloudTreeRowGrid.pinGlyphSize, weight: .semibold)
                    .foregroundStyle(.secondary)
                    .opacity(isPinned ? 1 : 0)
                    .accessibilityHidden(!isPinned)
                    .accessibilityLabel(String(localized: "taskManager.row.pinned", defaultValue: "Pinned"))
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: layout.attentionDot, height: layout.attentionDot)
                    .offset(
                        x: isPinned ? layout.attentionBadgeOffset : 0,
                        y: isPinned ? -layout.attentionBadgeOffset : 0
                    )
                    .opacity(hasUnreadNotification ? 1 : 0)
                    .accessibilityHidden(!hasUnreadNotification)
                    .accessibilityLabel(String(localized: "cloudTree.organization.unread", defaultValue: "Unread notification"))
                    .help(hasUnreadNotification
                        ? String(localized: "cloudTree.organization.unread", defaultValue: "Unread notification") : "")
            }
            .frame(width: layout.statusSlot, alignment: .center)
            content
        }
    }
}
