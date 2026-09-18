import AppKit
import CmuxCloudMachines
import CmuxFoundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

/// The Cloud tree is one grid. These tests render the production outline
/// (AppKit carets, SwiftUI-hosted rows) over a fleet with every row kind and
/// measure pixels: each row keeps its caret, status slot, icon, and title on
/// the shared columns for its depth, pinned and unread rows never move their
/// neighbours, and every single-line row shares one height and vertical center.
@MainActor
@Suite("Cloud tree row geometry", .serialized)
struct CloudTreeRowGeometryTests {
    @Test("Every row kind shares the caret, status, icon, and title columns", arguments: [100, 150], [200.0, 360.0])
    func columnsAlignAcrossKindsAndDepths(percent: Int, width: Double) throws {
        try withStoredMagnification(percent) {
            let scene = try GeometryScene(width: width)
            defer { scene.close() }
            let layout = scene.layout
            var report: [String] = []
            var measuredIcons = 0
            for row in 0..<scene.outline.numberOfRows {
                let m = try scene.measure(row: row)
                report.append(m.description)
                #expect(abs(m.rowRect.height - layout.rowHeight) <= 0.5, "\(m.tag): row height \(m.rowRect.height) vs \(layout.rowHeight)")
                #expect(abs(m.content.minX - layout.contentLeading(depth: m.depth)) <= 0.5, "\(m.tag): content x \(m.content.minX)")
                if m.isExpandable {
                    #expect(abs(m.caret.minX - layout.disclosureLeading(depth: m.depth)) <= 0.5, "\(m.tag): caret x \(m.caret.minX)")
                    #expect(abs(m.caret.width - layout.disclosureSlot) <= 0.5, "\(m.tag): caret slot \(m.caret.width)")
                    #expect(abs(m.caret.midY - m.rowRect.midY) <= 1, "\(m.tag): caret centered \(m.caret.midY) vs \(m.rowRect.midY)")
                    #expect(abs(m.content.minX - m.caret.maxX - layout.disclosureGap) <= 0.5, "\(m.tag): caret-to-content gap")
                }
                if let status = m.statusInk {
                    #expect(status.minX >= m.content.minX - 0.5 && status.maxX <= m.content.minX + layout.statusSlot + 1,
                            "\(m.tag): status indicator must stay inside the status slot: \(status)")
                } else {
                    #expect(!m.hasStatusIndicator, "\(m.tag): a pinned or unread row must draw its indicator")
                }
                guard let icon = m.iconInk else {
                    #expect(m.usesSpinner, "\(m.tag): every row except spinner rows draws an icon")
                    continue
                }
                measuredIcons += 1
                // Symbol ink is not perfectly symmetric in its frame (moon.zzz, cloud),
                // so allow glyph-shape slack while still catching a slot's worth of drift.
                #expect(abs(icon.midX - layout.iconCenterX(depth: m.depth)) <= 2,
                        "\(m.tag): icon center \(icon.midX) vs \(layout.iconCenterX(depth: m.depth))")
                #expect(abs(icon.midY - m.rowRect.midY) <= 2, "\(m.tag): icon vertical center \(icon.midY) vs \(m.rowRect.midY)")
                if let label = m.labelInk {
                    let expected = layout.labelX(depth: m.depth)
                    #expect(label.minX >= expected - 0.5 && label.minX <= expected + 3,
                            "\(m.tag): title x \(label.minX) vs column \(expected)")
                }
            }
            #expect(measuredIcons >= 20, "the fixture must exercise every row kind")
            #expect(scene.kinds.isSuperset(of: [
                "machine", "workspacesGroup", "workspace", "terminal", "browser", "display", "portsGroup", "port",
                "displaysPool", "terminalsPool", "resourcesPool", "resource", "placeholder", "pendingMachine",
            ]), "kinds rendered: \(scene.kinds.sorted())")
            try scene.attach("cloud-tree-\(Int(width))-\(percent)")
            try scene.attachText(report.joined(separator: "\n"), named: "cloud-tree-\(Int(width))-\(percent)-measurements")
        }
    }

    @Test("Pinned and unpinned peers share icon and title columns; children step by one indent")
    func pinnedPeersAndDepthSteps() throws {
        let scene = try GeometryScene(width: 300)
        defer { scene.close() }
        let layout = scene.layout
        let pinnedMachine = try scene.measure(row: try scene.row(withTitle: GeometryScene.pinnedMachineID))
        let machine = try scene.measure(row: try scene.row(withTitle: GeometryScene.machineID))
        #expect(pinnedMachine.hasStatusIndicator && !machine.hasStatusIndicator)
        let pinnedIcon = try #require(pinnedMachine.iconInk)
        let icon = try #require(machine.iconInk)
        #expect(abs(pinnedIcon.midX - icon.midX) <= 0.5, "pinning a machine must not move its icon")
        let pinnedLabel = try #require(pinnedMachine.labelInk)
        let label = try #require(machine.labelInk)
        #expect(abs(pinnedLabel.minX - label.minX) <= 1, "pinning a machine must not move its name")

        let pinnedFolder = try scene.measure(row: try scene.row(withTitle: GeometryScene.longWorkspaceName))
        let folder = try scene.measure(row: try scene.row(withTitle: "beta"))
        #expect(pinnedFolder.hasStatusIndicator && !folder.hasStatusIndicator)
        let unreadFolder = try scene.measure(row: try scene.row(withTitle: "alpha"))
        #expect(unreadFolder.hasStatusIndicator && unreadFolder.statusInk != nil, "an unread folder shows its dot in the status column")
        let pinnedFolderIcon = try #require(pinnedFolder.iconInk)
        let folderIcon = try #require(folder.iconInk)
        #expect(abs(pinnedFolderIcon.midX - folderIcon.midX) <= 0.5, "pinning a workspace must not move its icon")

        // Every child sits exactly one indent right of its parent, at every column.
        for row in 0..<scene.outline.numberOfRows {
            guard let parent = scene.outline.parent(forItem: scene.outline.item(atRow: row)) as? CloudTreeNode else { continue }
            let child = try scene.measure(row: row)
            let parentMeasure = try scene.measure(row: scene.outline.row(forItem: parent))
            #expect(abs(child.content.minX - parentMeasure.content.minX - layout.indentPerLevel) <= 0.5, "\(child.tag) under \(parentMeasure.tag)")
            if let childIcon = child.iconInk, let parentIcon = parentMeasure.iconInk {
                #expect(abs(childIcon.midX - parentIcon.midX - layout.indentPerLevel) <= 2, "\(child.tag) icon under \(parentMeasure.tag)")
            }
        }
    }

    @Test("Selection, hover, and collapse keep every remaining row on the grid")
    func statesKeepTheGrid() throws {
        let scene = try GeometryScene(width: 280)
        defer { scene.close() }
        let outline = scene.outline
        let selected = try scene.row(withTitle: "alpha")
        outline.selectRowIndexes(IndexSet(integer: selected), byExtendingSelection: false)
        let hovered = try #require(outline.view(atColumn: 0, row: try scene.row(withTitle: GeometryScene.machineID), makeIfNecessary: true) as? CloudTreeCellView)
        hovered.setHovered(true)
        try scene.attach("cloud-tree-selected-hovered")
        hovered.setHovered(false)
        outline.deselectAll(nil)

        let workspaces = try #require(outline.item(atRow: try scene.row(withTitle: "Workspaces")) as? CloudTreeNode)
        outline.collapseItem(workspaces)
        scene.relayout()
        for row in 0..<outline.numberOfRows {
            let m = try scene.measure(row: row)
            #expect(abs(m.content.minX - scene.layout.contentLeading(depth: m.depth)) <= 0.5, "\(m.tag) after collapse")
            if let icon = m.iconInk {
                #expect(abs(icon.midY - m.rowRect.midY) <= 2, "\(m.tag) vertical after collapse")
            }
        }
        try scene.attach("cloud-tree-collapsed")
    }

    private func withStoredMagnification(_ percent: Int, _ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: GlobalFontMagnification.percentKey)
        defaults.set(percent, forKey: GlobalFontMagnification.percentKey)
        defer {
            if let original { defaults.set(original, forKey: GlobalFontMagnification.percentKey) }
            else { defaults.removeObject(forKey: GlobalFontMagnification.percentKey) }
        }
        try body()
    }
}
