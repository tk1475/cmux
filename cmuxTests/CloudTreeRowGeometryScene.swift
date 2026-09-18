import AppKit
import CmuxCloudMachines
import CmuxFoundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

/// One rendered Cloud tree with every row kind: two fleet machines (one pinned),
/// a connecting machine, pinned and unpinned workspaces, unread and pinned
/// terminals, a browser, a display, a port, every pool, the Resources section,
/// and running and failed creates. Rows are measured from the production
/// outline's geometry and from the pixels it draws.
@MainActor
final class GeometryScene {
    static let machineID = "curious-lilac-lobster"
    static let pinnedMachineID = "trusty-cobalt-dingo"
    static let connectingMachineID = "sleepy-amber-otter"
    static let longWorkspaceName = "workspace-with-a-very-long-name-that-must-truncate"

    let coordinator: CloudTreeOutlineView.Coordinator
    let container: CloudTreeContainerView
    let window: NSWindow
    let outline: CloudTreeNSOutlineView
    let layout: CloudTreeRowLayout
    let kinds: Set<String>
    private let defaults: UserDefaults
    private let defaultsName = "cloud-tree-geometry-\(UUID().uuidString)"
    private var bitmap: NSBitmapImageRep?
    private var ink: InkMap?

    struct RowMeasure: CustomStringConvertible {
        let tag: String
        let depth: Int
        let isExpandable: Bool
        let hasStatusIndicator: Bool
        let usesSpinner: Bool
        let rowRect: NSRect
        let caret: NSRect
        let content: NSRect
        let statusInk: NSRect?
        let iconInk: NSRect?
        let labelInk: NSRect?

        var description: String {
            func f(_ r: NSRect?) -> String { r.map { String(format: "x=%.1f…%.1f y=%.1f…%.1f", $0.minX, $0.maxX, $0.minY, $0.maxY) } ?? "-" }
            return "\(tag) depth=\(depth) row=\(f(rowRect)) caret=\(f(caret)) content=\(f(content)) status=\(f(statusInk)) icon=\(f(iconInk)) label=\(f(labelInk))"
        }
    }

    init(width: Double) throws {
        defaults = UserDefaults(suiteName: defaultsName)!
        let organization = CloudSidebarOrganizationStore(defaults: defaults)
        let catalog = SurfaceCatalog(sidebarOrganization: organization)
        coordinator = CloudTreeOutlineView.Coordinator(
            machineActions: MachineRowActions(
                openShell: { _ in }, openDesktop: { _ in }, runCommand: { _, _ in }, confirmDelete: { _ in },
                promptRename: { _, _ in }, resizeDisk: { _, _ in }, promptUpgrade: {}
            ),
            nodeActions: CloudTreeNodeActions.bound(
                catalog: { catalog }, selectedWorkspaceID: { nil }, selectLocalWorkspace: { _ in },
                onWillMutate: { _ in }, onDidMutate: {}, onFailure: { _ in }, refresh: {}
            ),
            expansionStore: CloudTreeExpansionStore(defaults: defaults),
            organization: organization,
            tabDragTransferRegistry: { nil }
        )
        container = CloudTreeContainerView(coordinator: coordinator)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = container
        outline = try #require(coordinator.outlineView)
        layout = CloudTreeRowLayout(style: coordinator.style)
        let nodes = Self.nodes()
        _ = organization.perform(.pin, id: CloudTreeNodeBuilder.nodeID(workspace: "ws_2", machine: .cloud(Self.machineID)), nodes: nodes)
        let pinnedTerminal = try #require(CloudTreeNodeBuilder.flattened(nodes).first { $0.searchableTitle == "build" && $0.canOrganize })
        _ = organization.perform(.pin, id: pinnedTerminal.id, nodes: nodes)
        coordinator.apply(nodes: nodes)
        outline.expandItem(nil, expandChildren: true)
        kinds = Set(CloudTreeNodeBuilder.flattened(coordinator.nodes).map(\.structureTag))
        relayout()
    }

    func close() {
        window.contentView = nil
        defaults.removePersistentDomain(forName: defaultsName)
    }

    /// Fits the window to every row so each one has a live cell to draw.
    func relayout() {
        container.layoutSubtreeIfNeeded()
        let last = outline.numberOfRows - 1
        let height = last >= 0 ? outline.rect(ofRow: last).maxY + 24 : 200
        window.setContentSize(NSSize(width: window.contentView?.bounds.width ?? 300, height: height))
        container.layoutSubtreeIfNeeded()
        outline.layoutSubtreeIfNeeded()
        bitmap = nil
        ink = nil
    }

    func row(withTitle title: String) throws -> Int {
        for row in 0..<outline.numberOfRows {
            if let node = outline.item(atRow: row) as? CloudTreeNode, node.searchableTitle == title { return row }
        }
        throw GeometryError.missingRow(title)
    }

    private func renderedInk() throws -> InkMap {
        if let ink { return ink }
        outline.displayIfNeeded()
        let rep = try #require(outline.bitmapImageRepForCachingDisplay(in: outline.bounds))
        outline.cacheDisplay(in: outline.bounds, to: rep)
        let map = InkMap(rep, scale: Double(rep.pixelsWide) / Double(outline.bounds.width))
        bitmap = rep
        ink = map
        return map
    }

    func measure(row: Int) throws -> RowMeasure {
        let node = try #require(outline.item(atRow: row) as? CloudTreeNode)
        let map = try renderedInk()
        let rowRect = outline.rect(ofRow: row)
        let content = outline.frameOfCell(atColumn: 0, row: row)
        let band = NSRect(x: content.minX, y: rowRect.minY + 1, width: content.width, height: rowRect.height - 2)
        let clusters = map.clusters(in: band, minimumGap: 2.5)
        let hasStatus = node.isPinned || node.hasUnreadAttention
        let usesSpinner: Bool
        switch node.kind {
        case .placeholder(_, let placeholder): usesSpinner = placeholder.style == .connecting
        case .pendingMachine(let operation): usesSpinner = operation.isRunning
        default: usesSpinner = false
        }
        var remaining = clusters[...]
        var status: NSRect?
        if hasStatus, let first = remaining.first, first.minX < content.minX + layout.statusSlot + 1 {
            status = first
            remaining = remaining.dropFirst()
        }
        let icon = remaining.first
        let label = remaining.dropFirst().first
        return RowMeasure(
            tag: "\(node.structureTag)(\(node.searchableTitle.prefix(18)))",
            depth: max(0, outline.level(forRow: row)),
            isExpandable: node.isExpandable,
            hasStatusIndicator: hasStatus,
            usesSpinner: usesSpinner,
            rowRect: rowRect,
            caret: outline.frameOfOutlineCell(atRow: row),
            content: content,
            statusInk: status,
            iconInk: usesSpinner ? nil : icon,
            labelInk: usesSpinner ? nil : label
        )
    }

    func attach(_ name: String) throws {
        _ = try renderedInk()
        let rep = try #require(bitmap)
        #if compiler(>=6.2)
        Attachment.record(try #require(rep.representation(using: .png, properties: [:])), named: "\(name).png")
        #endif
    }

    func attachText(_ text: String, named name: String) throws {
        #if compiler(>=6.2)
        Attachment.record(text, named: "\(name).txt")
        #endif
    }

    enum GeometryError: Error { case missingRow(String) }

    // MARK: Fixture

    private static func nodes() -> [CloudTreeNode] {
        let machine = SurfaceMachineID.cloud(machineID)
        let pinned = SurfaceMachineID.cloud(pinnedMachineID)
        let ws1 = SurfaceRemoteWorkspace(id: "ws_1", name: "alpha", index: 0, focused: true)
        let ws2 = SurfaceRemoteWorkspace(id: "ws_2", name: longWorkspaceName, index: 1, focused: false)
        let ws3 = SurfaceRemoteWorkspace(id: "ws_3", name: "beta", index: 0, focused: true)
        func terminal(_ key: String, title: String, on host: SurfaceMachineID, in workspace: SurfaceRemoteWorkspace) -> SurfaceResource {
            var resource = SurfaceResource(
                id: SurfaceResourceID(machine: host, kind: .terminal, key: key),
                title: title, detail: "/home/cmux/src", lifecycle: .running, agent: nil,
                remoteWorkspace: workspace, port: nil, url: nil
            )
            resource.remoteViews = [SurfaceRemoteView(tabID: "tab_\(key)", workspace: workspace)]
            return resource
        }
        var browser = SurfaceResource(
            id: SurfaceResourceID(machine: machine, kind: .browser, key: "browser_1"),
            title: "cmux", detail: nil, lifecycle: .running, agent: nil,
            remoteWorkspace: ws1, port: nil, url: "https://cmux.com/docs"
        )
        browser.remoteViews = [SurfaceRemoteView(tabID: "tab_browser_1", workspace: ws1)]
        let port = SurfaceResource(
            id: SurfaceResourceID(machine: machine, kind: .browser, key: "port:8080"),
            title: "8080", detail: nil, lifecycle: .running, agent: nil,
            remoteWorkspace: nil, port: 8080, url: nil
        )
        var display = SurfaceResource(
            id: SurfaceResourceID(machine: machine, kind: .display, key: "display:1"),
            title: "Desktop", detail: nil, lifecycle: .running, agent: nil,
            remoteWorkspace: ws2, port: nil, url: nil
        )
        display.remoteViews = [SurfaceRemoteView(tabID: "tab_display_1", workspace: ws2)]
        func info(_ id: SurfaceMachineID, name: String, link: SurfaceLinkState, workspaces: [SurfaceRemoteWorkspace], desktop: Bool) -> SurfaceMachineInfo {
            var info = SurfaceMachineInfo(
                id: id, name: name, status: "running", image: nil, hasDesktop: desktop,
                memoryMb: 8192, diskMb: 65536, linkState: link, linkError: nil,
                cpuPercent: 12, memoryUsedMb: 2048, diskUsedMb: 20000, remoteWorkspaces: workspaces
            )
            info.privateAddress = "10.99.0.7"
            return info
        }
        let snapshot = SurfaceCatalogSnapshot(
            machines: [
                info(machine, name: machineID, link: .connected, workspaces: [ws1, ws2], desktop: true),
                info(pinned, name: pinnedMachineID, link: .connected, workspaces: [ws3], desktop: false),
                info(.cloud(connectingMachineID), name: connectingMachineID, link: .connecting, workspaces: [], desktop: false),
            ],
            resources: [
                terminal("term_1", title: "shell", on: machine, in: ws1),
                terminal("term_2", title: "build", on: machine, in: ws1),
                browser, port, display,
                terminal("term_3", title: "agent", on: machine, in: ws2),
                terminal("term_4", title: "shell", on: pinned, in: ws3),
            ],
            projections: []
        )
        func machineSnapshot(_ id: String, desktop: Bool, pinned: Bool) -> MachineSnapshot {
            var snapshot = MachineSnapshot(
                id: id, provider: "freestyle", image: "cmux-devbox:devbox-20260828b", isDesktop: desktop,
                activity: .ready, createdAt: nil, label: nil
            )
            snapshot.isPinned = pinned
            return snapshot
        }
        var failed = MachineCreateOperation(
            id: UUID(), request: MachineCreateCoordinatorTests.newMachineRequest(name: "quota-test"),
            startedAt: Date(timeIntervalSince1970: 1_787_400_060)
        )
        failed.phase = .failed(output: "Error: quota exceeded")
        return CloudTreeNodeBuilder.nodes(
            machines: [machineSnapshot(machineID, desktop: true, pinned: false), machineSnapshot(pinnedMachineID, desktop: false, pinned: true)],
            pendingCreates: [
                MachineCreateOperation(id: UUID(), request: MachineCreateCoordinatorTests.newMachineRequest(name: "ci"), startedAt: Date(timeIntervalSince1970: 1_787_400_000)),
                failed,
            ],
            snapshot: snapshot,
            localWorkspaces: [],
            unreadTerminalIDs: [machineID: ["term_1"]],
            includeLocalMachine: false
        )
    }
}

/// Which pixels of a rendered view carry ink, in view points.
struct InkMap {
    let scale: Double
    private let width: Int
    private let height: Int
    private let inked: [Bool]

    init(_ rep: NSBitmapImageRep, scale: Double) {
        self.scale = scale
        width = rep.pixelsWide
        height = rep.pixelsHigh
        var inked = [Bool](repeating: false, count: width * height)
        if let data = rep.bitmapData, rep.bitsPerSample == 8, !rep.isPlanar, rep.hasAlpha {
            let samples = rep.samplesPerPixel
            let alphaIndex = rep.bitmapFormat.contains(.alphaFirst) ? 0 : samples - 1
            for y in 0..<height {
                let row = data + y * rep.bytesPerRow
                for x in 0..<width where row[x * samples + alphaIndex] > 30 {
                    inked[y * width + x] = true
                }
            }
        } else {
            // A background-filled bitmap: anything that is not the corner colour is ink.
            let background = rep.colorAt(x: 0, y: 0)?.usingColorSpace(.deviceRGB)
            for y in 0..<height {
                for x in 0..<width {
                    guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), let background else { continue }
                    let delta = abs(color.redComponent - background.redComponent) + abs(color.greenComponent - background.greenComponent)
                        + abs(color.blueComponent - background.blueComponent) + abs(color.alphaComponent - background.alphaComponent)
                    if delta > 0.12 { inked[y * width + x] = true }
                }
            }
        }
        self.inked = inked
    }

    /// Ink clusters inside `band` (flipped view points), split at horizontal gaps of at least `minimumGap` points.
    func clusters(in band: NSRect, minimumGap: Double) -> [NSRect] {
        let x0 = max(0, Int((band.minX * scale).rounded(.down)))
        let x1 = min(width, Int((band.maxX * scale).rounded(.up)))
        let y0 = max(0, Int((band.minY * scale).rounded(.down)))
        let y1 = min(height, Int((band.maxY * scale).rounded(.up)))
        guard x0 < x1, y0 < y1 else { return [] }
        var clusters: [NSRect] = []
        var current: (minX: Int, maxX: Int, minY: Int, maxY: Int)?
        var gap = 0
        let gapPixels = max(1, Int((minimumGap * scale).rounded()))
        for x in x0..<x1 {
            var columnMinY: Int?
            var columnMaxY = 0
            for y in y0..<y1 where inked[y * width + x] {
                if columnMinY == nil { columnMinY = y }
                columnMaxY = y
            }
            if let columnMinY {
                if var c = current {
                    c.maxX = x; c.minY = min(c.minY, columnMinY); c.maxY = max(c.maxY, columnMaxY); current = c
                } else {
                    current = (x, x, columnMinY, columnMaxY)
                }
                gap = 0
            } else if let c = current {
                gap += 1
                if gap >= gapPixels {
                    clusters.append(rect(c))
                    current = nil
                    gap = 0
                }
            }
        }
        if let c = current { clusters.append(rect(c)) }
        return clusters
    }

    private func rect(_ c: (minX: Int, maxX: Int, minY: Int, maxY: Int)) -> NSRect {
        NSRect(
            x: Double(c.minX) / scale, y: Double(c.minY) / scale,
            width: Double(c.maxX - c.minX + 1) / scale, height: Double(c.maxY - c.minY + 1) / scale
        )
    }
}
