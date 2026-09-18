import CmuxFoundation
import CoreGraphics
import SwiftUI

/// Design-time constants of the Cloud tree's shared row grid, in unscaled points.
///
/// Every row, whatever its kind or depth, is laid out on the same columns:
/// the AppKit disclosure caret, a gap, then the hosted content, which begins
/// with one fixed status slot (pin glyph, unread dot, or nothing), the icon
/// slot, and the title. ``CloudTreeRowLayout`` scales these by the global font
/// magnification so text, glyphs, and gaps grow together.
enum CloudTreeRowGrid {
    /// Where the depth-0 caret starts, measured from the outline's leading edge.
    static let outlineLeadingMargin: CGFloat = 8
    /// Width reserved for the disclosure caret at every depth, expandable or not.
    static let disclosureSlot: CGFloat = 16
    /// Space between the caret slot and the hosted content.
    static let disclosureGap: CGFloat = 4
    /// One status column on every row: the pin glyph, the unread dot, both, or
    /// nothing. Reserving it everywhere keeps the icon and title columns fixed
    /// when a row is pinned or unread, and keeps children indented by exactly
    /// the tree indent relative to their parent.
    static let statusSlot: CGFloat = 12
    static let statusGap: CGFloat = 4
    static let pinGlyphSize: CGFloat = 9
    static let attentionDotDiameter: CGFloat = 6
    /// Offset of the unread dot toward the top-trailing corner when it shares
    /// the status slot with a pin glyph.
    static let attentionBadgeOffset: CGFloat = 3.5
    /// Space between a title and its dim detail text.
    static let detailGap: CGFloat = 6
    /// Trailing accessories: gap after the text, a fixed slot, then padding.
    static let trailingGap: CGFloat = 10
    static let trailingSlot: CGFloat = 16
    static let trailingPadding: CGFloat = CloudTreeLayoutMetrics().referenceInset
    static let machineLineSpacing: CGFloat = 1
}

enum CloudTreeIconPalette {
    static let workspace = Color.blue
    static let terminal = Color.indigo
    static let display = Color.teal
    static let browser = Color.orange
    static let machine = Color.accentColor
}

/// The Cloud tree's row grid resolved for one style and magnification.
///
/// AppKit (`CloudTreeNSOutlineView`) positions the caret and the hosted content
/// from this value, and every SwiftUI row lays its status slot, icon slot, and
/// title out from the same value, so the two sides can never disagree. Tests
/// read the same numbers to check rendered pixels.
struct CloudTreeRowLayout: Equatable {
    let style: CloudTreeStyle
    let magnification: Int

    /// Resolves the grid for a style at an explicit magnification percent.
    init(style: CloudTreeStyle, magnification: Int) {
        self.style = style
        self.magnification = GlobalFontMagnification.clamp(magnification)
    }

    /// Resolves the grid at the magnification the app currently stores, which
    /// is what AppKit row heights and the SwiftUI environment default both use.
    init(style: CloudTreeStyle) {
        self.init(style: style, magnification: GlobalFontMagnification.storedPercent)
    }

    /// Scales one design-time size by this layout's magnification.
    func scaled(_ size: CGFloat) -> CGFloat {
        GlobalFontMagnification.scaledSize(size, percent: magnification)
    }

    var rowHeight: CGFloat { scaled(style.rowHeight) }
    var leadingMargin: CGFloat { scaled(CloudTreeRowGrid.outlineLeadingMargin) }
    var indentPerLevel: CGFloat { scaled(style.indentPerLevel) }
    var disclosureSlot: CGFloat { scaled(CloudTreeRowGrid.disclosureSlot) }
    var disclosureGap: CGFloat { scaled(CloudTreeRowGrid.disclosureGap) }
    var statusSlot: CGFloat { scaled(CloudTreeRowGrid.statusSlot) }
    var statusGap: CGFloat { scaled(CloudTreeRowGrid.statusGap) }
    var attentionDot: CGFloat { scaled(CloudTreeRowGrid.attentionDotDiameter) }
    var attentionBadgeOffset: CGFloat { scaled(CloudTreeRowGrid.attentionBadgeOffset) }
    var iconSlot: CGFloat { scaled(style.iconSlot) }
    var iconGap: CGFloat { scaled(style.iconGap) }
    var detailGap: CGFloat { scaled(CloudTreeRowGrid.detailGap) }
    var trailingGap: CGFloat { scaled(CloudTreeRowGrid.trailingGap) }

    /// Leading edge of the icon slot, measured from the hosted content's leading edge.
    var iconLeading: CGFloat { statusSlot + statusGap }
    /// Horizontal center of the icon slot, measured from the hosted content's leading edge.
    var iconCenter: CGFloat { iconLeading + iconSlot / 2 }
    /// Leading edge of the title column, measured from the hosted content's leading edge.
    var labelLeading: CGFloat { iconLeading + iconSlot + iconGap }

    /// Leading edge of the caret slot for a row at `depth`, in outline coordinates.
    func disclosureLeading(depth: Int) -> CGFloat {
        leadingMargin + CGFloat(max(0, depth)) * indentPerLevel
    }

    /// Leading edge of the hosted content for a row at `depth`, in outline coordinates.
    func contentLeading(depth: Int) -> CGFloat {
        disclosureLeading(depth: depth) + disclosureSlot + disclosureGap
    }

    /// Horizontal center of the icon for a row at `depth`, in outline coordinates.
    func iconCenterX(depth: Int) -> CGFloat {
        contentLeading(depth: depth) + iconCenter
    }

    /// Leading edge of the title for a row at `depth`, in outline coordinates.
    func labelX(depth: Int) -> CGFloat {
        contentLeading(depth: depth) + labelLeading
    }
}
