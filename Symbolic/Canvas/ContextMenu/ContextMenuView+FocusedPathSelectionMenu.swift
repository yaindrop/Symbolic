import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    var bounds: CGRect? { focusedPath.activeNodesBounds }

    func onZoom() {
        guard let bounds else { return }
        viewportUpdater.zoomTo(rect: bounds)
    }

    func setNodeType(_ nodeType: PathNodeType) {
        guard let pathId = activeItem.focusedPathId else { return }
        let nodeIds = Array(focusedPath.activeNodeIds)
        documentUpdater.update(path: .update(.init(pathId: pathId, kind: .setNodeType(.init(nodeIds: nodeIds, nodeType: nodeType)))))
    }

    func setSegmentType(_ segmentType: PathSegmentType) {
        guard let pathId = activeItem.focusedPathId else { return }
        let fromNodeIds = Array(focusedPath.activeSegmentIds)
        documentUpdater.update(path: .update(.init(pathId: pathId, kind: .setSegmentType(.init(fromNodeIds: fromNodeIds, segmentType: segmentType)))))
    }

    func onDelete() {
        documentUpdater.update(focusedPath: .deleteNodes(.init(nodeIds: .init(focusedPath.activeNodeIds))))
    }
}

// MARK: - FocusedPathSelectionMenu

extension ContextMenuView {
    struct FocusedPathSelectionMenu: View, SelectorHolder {
        @Environment(\.sizedViewport) var viewport

        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .syncNotify }
            @Selected({ global.bounds }) var bounds
            @Selected({ global.focusedPath.focusedNodeId }) var focusedNodeId
            @Selected({ global.focusedPath.focusedSegmentId }) var focusedSegmentId
            @Selected({ global.focusedPath.selectingNodes }) var selectingNodes
            @Selected({ global.focusedPath.activeNodeIds.map { global.activeItem.focusedPathProperty?.nodeType(id: $0) }.allSame() }) var activeNodeType
            @Selected({ global.focusedPath.activeSegmentIds.map { global.activeItem.focusedPathProperty?.segmentType(id: $0) }.allSame() }) var activeSegmentType
            @Selected({ global.activeSymbol.symbolToWorld }) var symbolToWorld
            @Selected({ global.activeItem.focusedPathId }) var focusedPathId
        }

        @SelectorWrapper var selector

        @State private var showPopover: Bool = false

        var body: some View {
            setupSelector {
                content
            }
        }
    }
}

// MARK: private

extension ContextMenuView.FocusedPathSelectionMenu {
    @ViewBuilder var content: some View {
        if let bounds = selector.bounds {
            let transform = selector.symbolToWorld.concatenating(viewport.worldToView),
                bounds = bounds.applying(transform)
            menu.contextMenu(bounds: bounds)
        }
    }

    @ViewBuilder var menu: some View {
        HStack {
            Button { global.onZoom() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right.square") }
                .frame(minWidth: 32)
                .tint(.label)

            Button {
                global.focusedPath.setSelecting(!selector.selectingNodes)
            } label: { Image(systemName: "checklist") }
                .frame(minWidth: 32)
                .tint(selector.selectingNodes ? .blue : .label)

            Divider()

            Button { showPopover.toggle() } label: { Image(systemName: "ellipsis.circle") }
                .frame(minWidth: 32)
                .tint(.label)
                .portal(isPresented: $showPopover, configs: .init(isModal: true, align: .centerTrailing, gap: .init(12, 0))) {
                    let pathId = selector.focusedPathId
                    if let pathId, let nodeId = selector.focusedNodeId {
                        PathNodePopover(pathId: pathId, nodeId: nodeId)
                    } else if let pathId, let segmentId = selector.focusedSegmentId {
                        PathSegmentPopover(pathId: pathId, nodeId: segmentId)
                    } else {
                        PathSelectionPopover()
                    }
                }

            Divider()

            Menu { copyMenu } label: { Image(systemName: "doc.on.doc") }
                .menuOrder(.fixed)
                .frame(minWidth: 32)
                .tint(.label)
            Button(role: .destructive) { global.onDelete() } label: { Image(systemName: "trash") }
                .frame(minWidth: 32)
        }
    }

    @ViewBuilder var nodeTypeMenu: some View {
        nodeTypeButton(.corner)
        nodeTypeButton(.locked)
        nodeTypeButton(.mirrored)
    }

    @ViewBuilder func nodeTypeButton(_ nodeType: PathNodeType) -> some View {
        var name: String {
            switch nodeType {
            case .corner: "Corner"
            case .locked: "Locked"
            case .mirrored: "Mirrored"
            }
        }
        let selected = selector.activeNodeType == nodeType
        Button(name, systemImage: selected ? "checkmark" : "") { global.setNodeType(nodeType) }
            .disabled(selected)
    }

    @ViewBuilder var copyMenu: some View {
        Button("Copy", systemImage: "doc.on.doc") {}
        Button("Cut", systemImage: "scissors") {}
        Button("Duplicate", systemImage: "plus.square.on.square") {}
    }
}
