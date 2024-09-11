import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    func update(nodeId: UUID, position: Point2, pending: Bool = false) {
        guard var node = activeItem.focusedPath?.node(id: nodeId) else { return }
        node.position = position
        documentUpdater.update(focusedPath: .updateNode(.init(nodeId: nodeId, node: node)), pending: pending)
    }

    func update(nodeId: UUID, nodeType: PathNodeType) {
        documentUpdater.update(focusedPath: .setNodeType(.init(nodeIds: [nodeId], nodeType: nodeType)))
    }

    func focusNode(nodeId: UUID) {
        guard let bounds = focusedPath.nodeBounds(id: nodeId) else { return }
        viewportUpdater.zoomTo(worldRect: bounds.applying(activeSymbol.symbolToWorld), ratio: 0.5)
        focusedPath.setFocus(node: nodeId)
    }

    func resetControls(nodeId: UUID) {
        guard var node = activeItem.focusedPath?.node(id: nodeId) else { return }
        node.cubicIn = .zero
        node.cubicOut = .zero
        documentUpdater.update(focusedPath: .updateNode(.init(nodeId: nodeId, node: node)))
    }

    func breakNode(nodeId: UUID) {
        documentUpdater.update(focusedPath: .split(.init(nodeId: nodeId, newPathId: UUID(), newNodeId: UUID())))
    }

    func deleteNode(nodeId: UUID) {
        documentUpdater.update(focusedPath: .deleteNodes(.init(nodeIds: [nodeId])))
    }
}

// MARK: - PathNodePopover

struct PathNodePopover: View, TracedView, ComputedSelectorHolder {
    @Environment(\.portalId) var portalId
    let pathId: UUID, nodeId: UUID

    struct SelectorProps: Equatable { let pathId: UUID, nodeId: UUID }
    class Selector: SelectorBase {
        @Selected({ global.path.get(id: $0.pathId) }) var path
        @Selected({ global.path.property(id: $0.pathId) }) var pathProperty
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector(.init(pathId: pathId, nodeId: nodeId)) {
            content
        }
    } }
}

// MARK: private

private extension PathNodePopover {
    var node: PathNode? { selector.path?.node(id: nodeId) }

    var nodeType: PathNodeType? { selector.pathProperty?.nodeType(id: nodeId) }

    @ViewBuilder var content: some View {
        PopoverBody {
            PathNodeIcon(nodeId: nodeId)
            Spacer()
            Button("Done") { global.portal.deregister(id: portalId) }
                .font(.callout)
        } popoverContent: {
            ContextualRow(label: "Position") {
                VectorPicker(value: .init(node?.position ?? .zero)) {
                    global.update(nodeId: nodeId, position: .init($0), pending: true)
                } onDone: { global.update(nodeId: nodeId, position: .init($0)) }
                    .background(.ultraThickMaterial)
                    .clipRounded(radius: 6)
            }
            ContextualDivider()
            ContextualRow(label: "Type") {
                CasePicker<PathNodeType>(cases: [.corner, .locked, .mirrored], value: nodeType ?? .corner) { $0.name } onValue: { global.update(nodeId: nodeId, nodeType: $0) }
                    .background(.ultraThickMaterial)
                    .clipRounded(radius: 6)
            }
            ContextualDivider()
            ContextualRow {
                Button("Focus", systemImage: "scope") { global.focusNode(nodeId: nodeId) }
                    .contextualFont()
                Spacer()
                moreMenu
                    .contextualFont()
            }
        }
    }

    @ViewBuilder var moreMenu: some View {
        Menu("More", systemImage: "ellipsis") {
            Label("\(nodeId)", systemImage: "number")
            Divider()
            Button("Reset Controls", systemImage: "dot.square") { global.resetControls(nodeId: nodeId) }
            Divider()
            Button("Break", systemImage: "scissors", role: .destructive) { global.breakNode(nodeId: nodeId) }
            Button("Delete", systemImage: "trash", role: .destructive) { global.deleteNode(nodeId: nodeId) }
        }
        .menuOrder(.fixed)
    }
}
