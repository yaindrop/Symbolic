import SwiftUI

// MARK: - PathSegmentPopover

struct PathSelectionPopover: View, TracedView, SelectorHolder {
    @Environment(\.portalId) var portalId

    class Selector: SelectorBase {
        @Selected({ global.viewport.sizedInfo }) var viewport
        @Selected({ global.focusedPath.activeNodesBounds }) var bounds
        @Selected({ global.focusedPath.selectingNodes }) var selectingNodes
        @Selected({ global.focusedPath.activeNodeIds }) var activeNodeIds
        @Selected({ global.focusedPath.activeSegmentIds }) var activeSegmentIds
        @Selected({ global.focusedPath.activeNodeIds.map { global.activeItem.focusedPathProperty?.nodeType(id: $0) }.complete()?.allSame() }) var activeNodeType
        @Selected({ global.focusedPath.activeSegmentIds.map { global.activeItem.focusedPathProperty?.segmentType(id: $0) }.complete()?.allSame() }) var activeSegmentType
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

private extension PathSelectionPopover {
//    var node: PathNode? { selector.path?.node(id: nodeId) }
//
//    var fromNodeId: UUID? { isOut ? nodeId : selector.path?.nodeId(before: nodeId) }
//
//    var toNodeId: UUID? { isOut ? selector.path?.nodeId(after: nodeId) : nodeId }
//
//    var segment: PathSegment? { fromNodeId.map { selector.path?.segment(fromId: $0) } }
//
//    var segmentType: PathSegmentType? { fromNodeId.map { selector.pathProperty?.segmentType(id: $0) } }

    @ViewBuilder var content: some View {
        PopoverBody {
            curveIcon
            Spacer()
            Button("Done") { done() }
                .font(.callout)
        } popoverContent: {
            if !selector.activeNodeIds.isEmpty {
                ContextualRow(label: "Nodes") {
                    CasePicker<PathNodeType>(cases: [.corner, .locked, .mirrored], value: selector.activeNodeType ?? .corner) { $0.name } onValue: { update(nodeType: $0) }
                        .background(.ultraThickMaterial)
                        .clipRounded(radius: 6)
                }
                ContextualDivider()
            }
            if !selector.activeSegmentIds.isEmpty {
                ContextualRow(label: "Segments") {
                    CasePicker<PathSegmentType>(cases: [.cubic, .quadratic], value: selector.activeSegmentType ?? .cubic) { $0.name } onValue: { update(segmentType: $0) }
                        .background(.ultraThickMaterial)
                        .clipRounded(radius: 6)
                }
                ContextualDivider()
            }
            ContextualRow {
                Button("Zoom in", systemImage: "scope") {}
                    .contextualFont()
                Spacer()
                Menu("More", systemImage: "ellipsis") {
                    Button("Split", systemImage: "square.split.diagonal") {}
                    Button("Merge", systemImage: "arrow.left.to.line") {}
                    Divider()
                    Button("Break", systemImage: "scissors", role: .destructive) {}
                }
                .menuOrder(.fixed)
                .contextualFont()
            }
        }
    }

    @ViewBuilder var curveIcon: some View {
        Text("\(selector.activeNodeIds.count) nodes")
    }

    func done() {
        global.portal.deregister(id: portalId)
    }

//    func update(value: Vector2? = nil, pending: Bool = false) {
//        if let value, var node {
//            if isOut {
//                node.cubicOut = value
//            } else {
//                node.cubicIn = value
//            }
//            global.documentUpdater.update(focusedPath: .updateNode(.init(nodeId: nodeId, node: node)), pending: pending)
//        }
//    }
//
    func update(segmentType: PathSegmentType) {
        guard let pathId = global.activeItem.focusedPath?.id else { return }
        let fromNodeIds = Array(global.focusedPath.activeSegmentIds)
        global.documentUpdater.update(pathProperty: .update(.init(pathId: pathId, kind: .setSegmentType(.init(fromNodeIds: fromNodeIds, segmentType: segmentType)))))
    }

    func update(nodeType: PathNodeType) {
        guard let pathId = global.activeItem.focusedPath?.id else { return }
        let nodeIds = Array(global.focusedPath.activeNodeIds)
        global.documentUpdater.update(pathProperty: .update(.init(pathId: pathId, kind: .setNodeType(.init(nodeIds: nodeIds, nodeType: nodeType)))))
    }

//    func focusSegment() {
//        guard let fromNodeId,
//              let bounds = global.focusedPath.segmentBounds(fromId: fromNodeId) else { return }
//        global.viewportUpdater.zoomTo(rect: bounds, ratio: 0.5)
//        global.focusedPath.setFocus(segment: fromNodeId)
//    }
//
//    func splitSegment() {
//        guard let fromNodeId,
//              let segment else { return }
//        let paramT = segment.tessellated().approxPathParamT(lineParamT: 0.5).t
//        let id = UUID()
//        global.documentUpdater.update(focusedPath: .splitSegment(.init(fromNodeId: fromNodeId, paramT: paramT, newNodeId: id, offset: .zero)))
//        global.focusedPath.setFocus(node: id)
//    }
//
//    func breakSegment() {
//        guard let fromNodeId else { return }
//        global.documentUpdater.update(focusedPath: .breakAtSegment(.init(fromNodeId: fromNodeId, newPathId: UUID())))
//    }
}
