import SwiftUI

// MARK: - PathCurvePopover

struct PathCurvePopover: View, TracedView, ComputedSelectorHolder {
    @Environment(\.portalId) var portalId
    let pathId: UUID, nodeId: UUID, isOut: Bool

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

private extension PathCurvePopover {
    var node: PathNode? { selector.path?.node(id: nodeId) }

    var fromNodeId: UUID? { isOut ? nodeId : selector.path?.nodeId(before: nodeId) }

    var toNodeId: UUID? { isOut ? selector.path?.nodeId(after: nodeId) : nodeId }

    var segment: PathSegment? { fromNodeId.map { selector.path?.segment(fromId: $0) } }

    var segmentType: PathSegmentType? { fromNodeId.map { selector.pathProperty?.segmentType(id: $0) } }

    var activeSegmentType: PathSegmentType? { segment.map { segmentType?.activeType(segment: $0, isOut: isOut) } }

    @ViewBuilder var content: some View {
        PopoverBody {
            curveIcon
            Spacer()
            Button("Done") { done() }
                .font(.callout)
        } popoverContent: {
            ContextualRow(label: "Control") {
                let value = isOut ? node?.cubicOut : node?.cubicIn
                VectorPicker(value: value ?? .zero) { update(value: $0, pending: true) } onDone: { update(value: $0) }
                    .background(.ultraThickMaterial)
                    .clipRounded(radius: 6)
            }
            ContextualDivider()
            ContextualRow(label: "Type") {
                CasePicker<PathSegmentType>(cases: [.line, .cubic, .quadratic], value: activeSegmentType ?? .auto) { $0.name } onValue: { update(segmentType: $0) }
                    .background(.ultraThickMaterial)
                    .clipRounded(radius: 6)
            }
            ContextualDivider()
            ContextualRow {
                Button("Focus", systemImage: "scope") { focusSegment() }
                    .contextualFont()
                Spacer()
                Menu("More", systemImage: "ellipsis") {
                    Button("Split", systemImage: "square.split.diagonal") { splitSegment() }
                    Button("Merge", systemImage: "arrow.left.to.line") {}
                    Divider()
                    Button("Break", systemImage: "scissors", role: .destructive) { breakSegment() }
                }
                .menuOrder(.fixed)
                .contextualFont()
            }
        }
    }

    @ViewBuilder var curveIcon: some View {
        if let fromNodeId, let toNodeId {
            PathCurveIcon(fromNodeId: fromNodeId, toNodeId: toNodeId, isOut: isOut)
        }
    }

    func done() {
        global.portal.deregister(id: portalId)
    }

    func update(value: Vector2? = nil, pending: Bool = false) {
        if let value, var node {
            if isOut {
                node.cubicOut = value
            } else {
                node.cubicIn = value
            }
            global.documentUpdater.update(focusedPath: .updateNode(.init(nodeId: nodeId, node: node)), pending: pending)
        }
    }

    func update(segmentType: PathSegmentType) {
        guard let fromNodeId else { return }
        let segmentType = segmentType == self.segmentType ? nil : segmentType
        global.documentUpdater.update(pathProperty: .update(.init(pathId: pathId, kind: .setSegmentType(.init(fromNodeIds: [fromNodeId], segmentType: segmentType)))))
    }

    func focusSegment() {
        guard let fromNodeId,
              let segment else { return }
        global.viewportUpdater.zoomTo(rect: segment.boundingRect.outset(by: 32))
        global.focusedPath.setFocus(segment: fromNodeId)
    }

    func splitSegment() {
        guard let fromNodeId,
              let segment else { return }
        let paramT = segment.tessellated().approxPathParamT(lineParamT: 0.5).t
        let id = UUID()
        global.documentUpdater.update(focusedPath: .splitSegment(.init(fromNodeId: fromNodeId, paramT: paramT, newNodeId: id, offset: .zero)))
        global.focusedPath.setFocus(node: id)
    }

    func breakSegment() {
        guard let fromNodeId else { return }
        global.documentUpdater.update(path: .breakAtSegment(.init(pathId: pathId, fromNodeId: fromNodeId, newPathId: UUID())))
    }
}
