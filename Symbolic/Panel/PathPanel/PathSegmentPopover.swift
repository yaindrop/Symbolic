import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    func update(fromNodeId: UUID, control: Vector2, controlType: PathNodeControlType, pending: Bool = false) {
        guard var segment = activeItem.focusedPath?.segment(fromId: fromNodeId) else { return }
        switch controlType {
        case .cubicOut:
            segment.fromCubicOut = control
        case .cubicIn:
            segment.toCubicIn = control
        case .quadraticOut:
            segment = .init(from: segment.from, to: segment.to, quadratic: .init(control))
        }
        documentUpdater.update(focusedPath: .updateSegment(.init(fromNodeId: fromNodeId, segment: segment)), pending: pending)
    }

    func update(fromNodeId: UUID, segmentType: PathSegmentType?) {
        documentUpdater.update(focusedPath: .setSegmentType(.init(fromNodeIds: [fromNodeId], segmentType: segmentType)))
    }

    func focusSegment(fromNodeId: UUID) {
        guard let bounds = focusedPath.segmentBounds(fromId: fromNodeId) else { return }
        viewportUpdater.zoomTo(worldRect: bounds.applying(activeSymbol.symbolToWorld), ratio: 0.5)
        focusedPath.setFocus(segment: fromNodeId)
    }

    func resetControls(fromNodeId: UUID) {
        guard var segment = activeItem.focusedPath?.segment(fromId: fromNodeId) else { return }
        segment.fromCubicOut = .zero
        segment.toCubicIn = .zero
        documentUpdater.update(focusedPath: .updateSegment(.init(fromNodeId: fromNodeId, segment: segment)))
    }

    func splitSegment(fromNodeId: UUID) {
        guard let segment = activeItem.focusedPath?.segment(fromId: fromNodeId) else { return }
        let paramT = segment.tessellated().approxPathParamT(lineParamT: 0.5).t
        let id = UUID()
        documentUpdater.update(focusedPath: .splitSegment(.init(fromNodeId: fromNodeId, paramT: paramT, newNodeId: id, offset: .zero)))
        focusedPath.setFocus(node: id)
    }

    func breakSegment(fromNodeId: UUID) {
        documentUpdater.update(focusedPath: .split(.init(nodeId: fromNodeId, newPathId: UUID(), newNodeId: nil)))
    }
}

// MARK: - PathSegmentPopover

struct PathSegmentPopover: View, TracedView, ComputedSelectorHolder {
    @Environment(\.portalId) var portalId
    var pathId: UUID, nodeId: UUID, isOut: Bool? = nil

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

private extension PathSegmentPopover {
    var node: PathNode? { selector.path?.node(id: nodeId) }

    var fromNodeId: UUID? { isOut != false ? nodeId : selector.path?.nodeId(before: nodeId) }

    var toNodeId: UUID? { isOut != false ? selector.path?.nodeId(after: nodeId) : nodeId }

    var segment: PathSegment? { fromNodeId.map { selector.path?.segment(fromId: $0) } }

    var segmentType: PathSegmentType? { fromNodeId.map { selector.pathProperty?.segmentType(id: $0) } }

    @ViewBuilder var content: some View {
        if let fromNodeId, let toNodeId {
            PopoverBody {
                PathSegmentIcon(fromNodeId: fromNodeId, toNodeId: toNodeId, isOut: isOut)
                Spacer()
                Button("Done") { global.portal.deregister(id: portalId) }
                    .font(.callout)
            } popoverContent: {
                let segmentType = segmentType
                if isOut != false, segmentType == .cubic, let node {
                    ContextualRow(label: "Cubic Out") { vectorPicker(fromNodeId: fromNodeId, value: node.cubicOut, controlType: .cubicOut) }
                    ContextualDivider()
                }
                if isOut != true, segmentType == .cubic, let node {
                    ContextualRow(label: "Cubic In") { vectorPicker(fromNodeId: fromNodeId, value: node.cubicIn, controlType: .cubicIn) }
                    ContextualDivider()
                }
                if segmentType == .quadratic, let quadratic = segment?.quadratic {
                    ContextualRow(label: "Quadratic") { vectorPicker(fromNodeId: fromNodeId, value: .init(quadratic), controlType: .quadraticOut) }
                    ContextualDivider()
                }
                ContextualRow(label: "Type") {
                    CasePicker<PathSegmentType>(cases: [.cubic, .quadratic], value: segmentType ?? .cubic) { $0.name } onValue: {
                        global.update(fromNodeId: fromNodeId, segmentType: $0 == segmentType ? nil : $0)
                    }
                    .background(.ultraThickMaterial)
                    .clipRounded(radius: 6)
                }
                ContextualDivider()
                ContextualRow {
                    Button("Focus", systemImage: "scope") { global.focusSegment(fromNodeId: fromNodeId) }
                        .contextualFont()
                    Spacer()
                    moreMenu(fromNodeId: fromNodeId)
                        .contextualFont()
                }
            }
        }
    }

    @ViewBuilder func vectorPicker(fromNodeId: UUID, value: Vector2, controlType: PathNodeControlType) -> some View {
        VectorPicker(value: value) {
            global.update(fromNodeId: fromNodeId, control: $0, controlType: controlType, pending: true)
        } onDone: { global.update(fromNodeId: fromNodeId, control: $0, controlType: controlType) }
            .background(.ultraThickMaterial)
            .clipRounded(radius: 6)
    }

    @ViewBuilder func moreMenu(fromNodeId: UUID) -> some View {
        Menu("More", systemImage: "ellipsis") {
            Button("Reset Controls", systemImage: "line.diagonal") { global.resetControls(fromNodeId: fromNodeId) }
            Button("Split", systemImage: "square.split.diagonal") { global.splitSegment(fromNodeId: fromNodeId) }
            Divider()
            Button("Break", systemImage: "scissors", role: .destructive) { global.breakSegment(fromNodeId: fromNodeId) }
        }
        .menuOrder(.fixed)
    }
}
