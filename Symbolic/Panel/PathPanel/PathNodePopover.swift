import SwiftUI

// MARK: - PathNodePopover

struct PathNodePopover: View, TracedView, ComputedSelectorHolder {
    @Environment(\.portalId) var portalId
    let pathId: UUID, nodeId: UUID

    struct SelectorProps: Equatable { let pathId: UUID, nodeId: UUID }
    class Selector: SelectorBase {
        @Selected({ global.path.get(id: $0.pathId) }) var path
        @Selected({ global.pathProperty.get(id: $0.pathId) }) var pathProperty
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
            Button("Done") { done() }
                .font(.callout)
        } popoverContent: {
            ContextualRow(label: "Position") {
                VectorPicker(value: .init(node?.position ?? .zero)) { update(value: $0, pending: true) } onDone: { update(value: $0) }
                    .background(.ultraThickMaterial)
                    .clipRounded(radius: 6)
            }
            ContextualDivider()
            ContextualRow(label: "Type") {
                CasePicker<PathNodeType>(cases: [.corner, .locked, .mirrored], value: nodeType ?? .corner) { $0.name } onValue: { update(nodeType: $0) }
                    .background(.ultraThickMaterial)
                    .clipRounded(radius: 6)
            }
            ContextualDivider()
            ContextualRow {
                Button("Focus", systemImage: "scope") { focusNode() }
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
            Button("Reset Controls", systemImage: "dot.square") { resetControls() }
            Divider()
            Button("Break", systemImage: "scissors", role: .destructive) { breakNode() }
            Button("Delete", systemImage: "trash", role: .destructive) { deleteNode() }
        }
        .menuOrder(.fixed)
    }
}

// MARK: actions

private extension PathNodePopover {
    func done() {
        global.portal.deregister(id: portalId)
    }

    func update(value: Vector2? = nil, pending: Bool = false) {
        guard var node, let value else { return }
        node.position = .init(value)
        global.documentUpdater.update(focusedPath: .updateNode(.init(nodeId: nodeId, node: node)), pending: pending)
    }

    func update(nodeType: PathNodeType) {
        global.documentUpdater.update(pathProperty: .update(.init(pathId: pathId, kind: .setNodeType(.init(nodeIds: [nodeId], nodeType: nodeType)))))
    }

    func focusNode() {
        guard let bounds = global.focusedPath.nodeBounds(id: nodeId) else { return }
        global.viewportUpdater.zoomTo(rect: bounds, ratio: 0.5)
        global.focusedPath.setFocus(node: nodeId)
    }

    func resetControls() {
        guard var node else { return }
        node.cubicIn = .zero
        node.cubicOut = .zero
        global.documentUpdater.update(focusedPath: .updateNode(.init(nodeId: nodeId, node: node)))
    }

    func breakNode() {
        global.documentUpdater.update(focusedPath: .breakAtNode(.init(nodeId: nodeId, newPathId: UUID(), newNodeId: UUID())))
    }

    func deleteNode() {
        global.documentUpdater.update(focusedPath: .deleteNodes(.init(nodeIds: [nodeId])))
    }
}
