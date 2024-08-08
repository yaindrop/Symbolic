import SwiftUI

// MARK: - PathSegmentPopover

struct PathSegmentPopover: View, TracedView, ComputedSelectorHolder {
    @Environment(\.portalId) var portalId
    var pathId: UUID, nodeId: UUID, isOut: Bool? = nil

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

private extension PathSegmentPopover {
    var node: PathNode? { selector.path?.node(id: nodeId) }

    var fromNodeId: UUID? { isOut != false ? nodeId : selector.path?.nodeId(before: nodeId) }

    var toNodeId: UUID? { isOut != false ? selector.path?.nodeId(after: nodeId) : nodeId }

    var segment: PathSegment? { fromNodeId.map { selector.path?.segment(fromId: $0) } }

    var segmentType: PathSegmentType? { fromNodeId.map { selector.pathProperty?.segmentType(id: $0) } }

    @ViewBuilder var content: some View {
        PopoverBody {
            if let fromNodeId, let toNodeId {
                PathSegmentIcon(fromNodeId: fromNodeId, toNodeId: toNodeId, isOut: isOut)
            }
            Spacer()
            Button("Done") { done() }
                .font(.callout)
        } popoverContent: {
            let segmentType = segmentType
            if isOut != false, segmentType != .quadratic, let node = node {
                ContextualRow(label: "Cubic Out") { vectorPicker(value: node.cubicOut, controlType: .cubicOut) }
                ContextualDivider()
            }
            if isOut != true, segmentType != .quadratic, let node = node {
                ContextualRow(label: "Cubic In") { vectorPicker(value: node.cubicIn, controlType: .cubicIn) }
                ContextualDivider()
            }
            if segmentType != .cubic, let quadratic = segment?.quadratic {
                ContextualRow(label: "Quadratic") { vectorPicker(value: .init(quadratic), controlType: .quadratic) }
                ContextualDivider()
            }
            ContextualRow(label: "Type") {
                CasePicker<PathSegmentType>(cases: [.cubic, .quadratic], value: segmentType ?? .cubic) { $0.name } onValue: { update(segmentType: $0) }
                    .background(.ultraThickMaterial)
                    .clipRounded(radius: 6)
            }
            ContextualDivider()
            ContextualRow {
                Button("Focus", systemImage: "scope") { focusSegment() }
                    .contextualFont()
                Spacer()
                moreMenu
                    .contextualFont()
            }
        }
    }

    @ViewBuilder func vectorPicker(value: Vector2, controlType: PathBezierControlType) -> some View {
        VectorPicker(value: value) { update(value: $0, controlType: controlType, pending: true) } onDone: { update(value: $0, controlType: controlType) }
            .background(.ultraThickMaterial)
            .clipRounded(radius: 6)
    }

    @ViewBuilder var moreMenu: some View {
        Menu("More", systemImage: "ellipsis") {
            Button("Reset Controls", systemImage: "line.diagonal") { resetControls() }
            Button("Split", systemImage: "square.split.diagonal") { splitSegment() }
            Divider()
            Button("Break", systemImage: "scissors", role: .destructive) { breakSegment() }
        }
        .menuOrder(.fixed)
    }
}

// MARK: actions

private extension PathSegmentPopover {
    func done() {
        global.portal.deregister(id: portalId)
    }

    func update(value: Vector2, controlType: PathBezierControlType, pending: Bool = false) {
        guard let fromNodeId,
              var node,
              var segment else { return }
        switch controlType {
        case .cubicOut:
            node.cubicOut = value
            global.documentUpdater.update(focusedPath: .updateNode(.init(nodeId: nodeId, node: node)), pending: pending)
        case .cubicIn:
            node.cubicIn = value
            global.documentUpdater.update(focusedPath: .updateNode(.init(nodeId: nodeId, node: node)), pending: pending)
        case .quadratic:
            segment = .init(from: segment.from, to: segment.to, quadratic: .init(value))
            global.documentUpdater.update(focusedPath: .updateSegment(.init(fromNodeId: fromNodeId, segment: segment)), pending: pending)
        }
    }

    func update(segmentType: PathSegmentType) {
        guard let fromNodeId else { return }
        let segmentType = segmentType == self.segmentType ? nil : segmentType
        global.documentUpdater.update(pathProperty: .update(.init(pathId: pathId, kind: .setSegmentType(.init(fromNodeIds: [fromNodeId], segmentType: segmentType)))))
    }

    func focusSegment() {
        guard let fromNodeId,
              let bounds = global.focusedPath.segmentBounds(fromId: fromNodeId) else { return }
        global.viewportUpdater.zoomTo(rect: bounds, ratio: 0.5)
        global.focusedPath.setFocus(segment: fromNodeId)
    }

    func resetControls() {
        guard let fromNodeId, var segment else { return }
        segment.fromCubicOut = .zero
        segment.toCubicIn = .zero
        global.documentUpdater.update(focusedPath: .updateSegment(.init(fromNodeId: fromNodeId, segment: segment)))
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
        global.documentUpdater.update(focusedPath: .breakAtSegment(.init(fromNodeId: fromNodeId, newPathId: UUID())))
    }
}
