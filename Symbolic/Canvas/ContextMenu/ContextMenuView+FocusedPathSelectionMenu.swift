import SwiftUI

// MARK: - FocusedPathSelectionMenu

extension ContextMenuView {
    struct FocusedPathSelectionMenu: View, SelectorHolder {
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Selected({ global.viewport.sizedInfo }) var viewport
            @Selected({ global.focusedPath.activeNodesBounds }) var bounds
            @Selected({ global.focusedPath.selectingNodes }) var selectingNodes
            @Selected({ global.focusedPath.activeSegmentIds }) var activeSegmentIds
            @Selected({ global.focusedPath.activeNodeIds.map { global.activeItem.focusedPathProperty?.nodeType(id: $0) }.allSame() }) var activeNodeType
            @Selected({ global.focusedPath.activeSegmentIds.map { global.activeItem.focusedPathProperty?.edgeType(id: $0) }.allSame() }) var activeEdgeType
        }

        @SelectorWrapper var selector

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
            AnimatableReader(selector.viewport) {
                menu.contextMenu(bounds: bounds.applying($0.worldToView))
            }
        }
    }

    @ViewBuilder var menu: some View {
        HStack {
            Button {
                if let bounds = selector.bounds {
                    global.viewportUpdater.zoomTo(rect: bounds)
                }
            } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                .frame(minWidth: 32)
                .tint(.label)

            Button { onToggleSelectingNodes() } label: { Image(systemName: "checklist") }
                .frame(minWidth: 32)
                .tint(selector.selectingNodes ? .blue : .label)

            Divider()

            Menu { nodeTypeMenu } label: { Image(systemName: "smallcircle.filled.circle") }
                .menuOrder(.fixed)
                .frame(minWidth: 32)
                .tint(.label)

            if !selector.activeSegmentIds.isEmpty {
                Menu { edgeTypeMenu } label: { Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath") }
                    .menuOrder(.fixed)
                    .frame(minWidth: 32)
                    .tint(.label)
            }

            Divider()

            Menu { copyMenu } label: { Image(systemName: "doc.on.doc") }
                .menuOrder(.fixed)
                .frame(minWidth: 32)
                .tint(.label)
            Button(role: .destructive) { onDelete() } label: { Image(systemName: "trash") }
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
        Button(name, systemImage: selected ? "checkmark" : "") { setNodeType(nodeType) }
            .disabled(selected)
    }

    @ViewBuilder var edgeTypeMenu: some View {
        edgeTypeButton(.line)
        edgeTypeButton(.cubic)
        edgeTypeButton(.quadratic)
    }

    @ViewBuilder func edgeTypeButton(_ edgeType: PathEdgeType) -> some View {
        var name: String {
            switch edgeType {
            case .line: "Line"
            case .cubic: "Cubic Bezier"
            case .quadratic: "Quadratic Bezier"
            case .auto: ""
            }
        }
        let selected = selector.activeEdgeType == edgeType
        Button(name, systemImage: selected ? "checkmark" : "") { selected ? setEdgeType(.auto) : setEdgeType(edgeType) }
    }

    @ViewBuilder var copyMenu: some View {
        Button("Copy", systemImage: "doc.on.doc") {}
        Button("Cut", systemImage: "scissors") {}
        Button("Duplicate", systemImage: "plus.square.on.square") {}
    }

    func onToggleSelectingNodes() {
        global.focusedPath.toggleSelectingNodes()
    }

    func setNodeType(_ nodeType: PathNodeType) {
        guard let pathId = global.activeItem.focusedPath?.id else { return }
        let nodeIds = Array(global.focusedPath.activeNodeIds)
        global.documentUpdater.update(pathProperty: .update(.init(pathId: pathId, kind: .setNodeType(.init(nodeIds: nodeIds, nodeType: nodeType)))))
    }

    func setEdgeType(_ edgeType: PathEdgeType) {
        guard let pathId = global.activeItem.focusedPath?.id else { return }
        let fromNodeIds = Array(global.focusedPath.activeSegmentIds)
        global.documentUpdater.update(pathProperty: .update(.init(pathId: pathId, kind: .setEdgeType(.init(fromNodeIds: fromNodeIds, edgeType: edgeType)))))
    }

    func onUngroup() {}

    func onDelete() {}
}
