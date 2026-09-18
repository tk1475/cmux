import CmuxFoundation
import SwiftUI

/// The full-width tinted band `sections`-family machine rows sit in; a plain
/// pass-through elsewhere. The band is decoration only: it extends behind the
/// content without moving it off the shared row grid.
struct CloudTreeMachineBand<Content: View>: View {
    let style: CloudTreeStyle
    @ViewBuilder var content: () -> Content
    @Environment(\.cmuxGlobalFontMagnificationPercent) private var magnification

    var body: some View {
        if style.machineBand {
            content()
                .padding(.vertical, GlobalFontMagnification.scaledSize(
                    style.machineBandVerticalPadding, percent: magnification
                ))
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .padding(.leading, -6)
                        .padding(.trailing, -2)
                )
                .padding(.trailing, CloudTreeRowGrid.trailingPadding)
        } else {
            content()
                .padding(.trailing, CloudTreeRowGrid.trailingPadding)
        }
    }
}
