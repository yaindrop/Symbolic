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
            nodeIcon
            Spacer()
            Button("Done") { done() }
                .font(.callout)
        } popoverContent: {
            PopoverRow(label: "Position") {
                VectorPicker(value: .init(node?.position ?? .zero)) { update(value: $0, pending: true) } onDone: { update(value: $0) }
                    .background(.ultraThickMaterial)
                    .clipRounded(radius: 6)
            }
            PopoverDivider()
            PopoverRow(label: "Type") {
                CasePicker<PathNodeType>(cases: [.corner, .locked, .mirrored], value: nodeType ?? .corner) { $0.name } onValue: { update(nodeType: $0) }
                    .background(.ultraThickMaterial)
                    .clipRounded(radius: 6)
            }
            PopoverDivider()
            PopoverRow {
                Button("Focus", systemImage: "scope") { focusNode() }
                    .font(.footnote)
                Spacer()
                Menu("More", systemImage: "ellipsis") {
                    Label("\(nodeId)", systemImage: "number")
                    Divider()
                    Button("Break", systemImage: "scissors", role: .destructive) { breakNode() }
                    Button("Delete", systemImage: "trash", role: .destructive) { deleteNode() }
                }
                .menuOrder(.fixed)
                .font(.footnote)
            }
        }
    }

    var nodeIcon: some View {
        PathNodeIcon(nodeId: nodeId)
    }

    func done() {
        global.portal.deregister(id: portalId)
    }

    func update(value: Vector2? = nil, pending: Bool = false) {
        guard var node, let value else { return }
        node.position = .init(value)
        global.documentUpdater.update(focusedPath: .updateNode(.init(nodeId: nodeId, node: node)), pending: pending)
    }

    func update(nodeType _: PathNodeType) {
        global.documentUpdater.update(pathProperty: .update(.init(pathId: pathId, kind: .setNodeType(.init(nodeIds: [nodeId], nodeType: nodeType)))))
    }

    func focusNode() {
        guard let node else { return }
        global.viewportUpdater.zoomTo(rect: .init(center: node.position, size: .init(squared: 32)))
        global.focusedPath.setFocus(node: nodeId)
    }

//    func mergeNode() {
//        if let mergableNodeId {
//            let pathId = context.path.id
//            global.documentUpdater.update(path: .merge(.init(pathId: pathId, endingNodeId: nodeId, mergedPathId: pathId, mergedEndingNodeId: mergableNodeId)))
//        }
//    }

    func breakNode() {
        global.documentUpdater.update(path: .breakAtNode(.init(pathId: pathId, nodeId: nodeId, newNodeId: UUID(), newPathId: UUID())))
    }

    func deleteNode() {
        global.documentUpdater.update(focusedPath: .deleteNodes(.init(nodeIds: [nodeId])))
    }
}
