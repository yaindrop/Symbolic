import SwiftUI

private class GestureContext {
    var longPressParamT: Scalar?
    var longPressSplitNodeId: UUID?
}

// MARK: - global actions

private extension GlobalStores {
    func onTap(segment fromId: UUID) {
        if focusedPath.selectingNodes {
            guard let path = activeItem.focusedPath, let toId = path.node(after: fromId)?.id else { return }
            let nodeIds = [fromId, toId]
            if focusedPath.activeNodeIds.isSuperset(of: nodeIds) {
                focusedPath.selectRemove(node: nodeIds)
            } else {
                focusedPath.selectAdd(node: nodeIds)
            }
        } else {
            let focused = focusedPath.focusedSegmentId == fromId
            focused ? focusedPath.clear() : focusedPath.setFocus(segment: fromId)
        }
    }

    func edgeGesture(fromId: UUID, segment: PathSegment, context: GestureContext) -> MultipleGesture {
        func split(at paramT: Scalar) {
            context.longPressParamT = paramT
            let id = UUID()
            context.longPressSplitNodeId = id
            focusedPath.setFocus(node: id)
        }
        func moveSplitNode(paramT: Scalar, newNodeId: UUID, offset: Vector2, pending: Bool = false) {
            documentUpdater.updateInView(focusedPath: .splitSegment(.init(fromNodeId: fromId, paramT: paramT, newNodeId: newNodeId, offset: offset)), pending: pending)

            if !pending {
                context.longPressParamT = nil
            }
        }
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            if let paramT = context.longPressParamT, let newNodeId = context.longPressSplitNodeId {
                moveSplitNode(paramT: paramT, newNodeId: newNodeId, offset: v.offset, pending: pending)
            } else if let pathId = activeItem.focusedPath?.id {
                documentUpdater.updateInView(path: .move(.init(pathIds: [pathId], offset: v.offset)), pending: pending)
            }
        }
        func updateLongPress(segment _: PathSegment, pending: Bool = false) {
            guard let paramT = context.longPressParamT, let newNodeId = context.longPressSplitNodeId else { return }
            moveSplitNode(paramT: paramT, newNodeId: newNodeId, offset: .zero, pending: pending)
        }

        return .init(
            configs: .init(durationThreshold: 0.2),
            onPress: {
                canvasAction.start(continuous: .movePath)
                canvasAction.start(triggering: .splitPathEdge)
            },
            onPressEnd: { cancelled in
                canvasAction.end(triggering: .splitPathEdge)
                canvasAction.end(continuous: .splitAndMovePathNode)
                canvasAction.end(continuous: .movePath)
                if cancelled { documentUpdater.cancel() }

            },
            onTap: { _ in onTap(segment: fromId) },
            onLongPress: {
                split(at: segment.paramT(closestTo: $0.location).t)
                updateLongPress(segment: segment, pending: true)
                canvasAction.end(continuous: .movePath)
                canvasAction.end(triggering: .splitPathEdge)
                canvasAction.start(continuous: .splitAndMovePathNode)
            },
            onLongPressEnd: { _ in updateLongPress(segment: segment) },
            onDrag: {
                updateDrag($0, pending: true)
                canvasAction.end(triggering: .splitPathEdge)
            },
            onDragEnd: { updateDrag($0) }
        )
    }

    func focusedEdgeGesture(fromId: UUID) -> MultipleGesture {
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            guard let toId = activeItem.focusedPath?.node(after: fromId)?.id else { return }
            documentUpdater.updateInView(focusedPath: .moveNodes(.init(nodeIds: [fromId, toId], offset: v.offset)), pending: pending)
        }
        return .init(
            onPress: { canvasAction.start(continuous: .movePathEdge) },
            onPressEnd: { cancelled in
                canvasAction.end(continuous: .movePathEdge)
                if cancelled { documentUpdater.cancel() }
            },

            onTap: { _ in onTap(segment: fromId) },
            onDrag: { updateDrag($0, pending: true) },
            onDragEnd: { updateDrag($0) }
        )
    }
}

// MARK: - EdgeHandle

extension FocusedPathView {
    struct EdgeHandle: View, TracedView, EquatableBy, ComputedSelectorHolder {
        let pathId: UUID, fromNodeId: UUID

        var equatableBy: some Equatable { pathId; fromNodeId }

        struct SelectorProps: Equatable { let pathId: UUID, fromNodeId: UUID }
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Formula({ global.path.get(id: $0.pathId) }) static var path
            @Selected({ global.viewport.sizedInfo }) var viewport
            @Selected({ path($0)?.segment(from: $0.fromNodeId) }) var segment
        }

        @SelectorWrapper var selector

        @State private var gestureContext = GestureContext()

        var body: some View { trace {
            setupSelector(.init(pathId: pathId, fromNodeId: fromNodeId)) {
                content
            }
        } }
    }
}

// MARK: private

private extension FocusedPathView.EdgeHandle {
    @ViewBuilder var content: some View {
        if let segment = selector.segment {
            AnimatableReader(selector.viewport) {
                let segment = segment.applying($0.worldToView)
                SUPath { p in segment.append(to: &p) }
                    .strokedPath(StrokeStyle(lineWidth: 24, lineCap: .round))
                    .fill(Color.invisibleSolid)
                    .multipleGesture(global.edgeGesture(fromId: fromNodeId, segment: segment, context: gestureContext))
            }
        }
    }

    var circleSize: Scalar { 16 }
    var lineWidth: Scalar { 2 }

    @ViewBuilder func circle(at point: Point2, color: Color) -> some View {
        Circle()
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth))
            .fill(color)
            .frame(size: .init(squared: circleSize))
            .invisibleSoildOverlay()
            .position(point)
    }
}

// MARK: - FocusedEdgeHandle

extension FocusedPathView {
    struct FocusedEdgeHandle: View, TracedView, EquatableBy, ComputedSelectorHolder {
        let pathId: UUID, fromNodeId: UUID

        var equatableBy: some Equatable { pathId; fromNodeId }

        struct SelectorProps: Equatable { let pathId: UUID, fromNodeId: UUID }
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Formula({ global.path.get(id: $0.pathId) }) static var path
            @Selected({ global.viewport.sizedInfo }) var viewport
            @Selected({ path($0)?.segment(from: $0.fromNodeId) }) var segment
            @Selected({ global.focusedPath.focusedSegmentId == $0.fromNodeId }) var focused
        }

        @SelectorWrapper var selector

        var body: some View { trace {
            setupSelector(.init(pathId: pathId, fromNodeId: fromNodeId)) {
                content
            }
        } }
    }
}

// MARK: private

private extension FocusedPathView.FocusedEdgeHandle {
    var color: Color { .cyan }
    var lineWidth: Scalar { 1 }
    var circleSize: Scalar { 12 }
    var touchablePadding: Scalar { 24 }

    func circlePosition(segment: PathSegment) -> Point2 {
        let tessellated = segment.tessellated()
        let t = tessellated.approxPathParamT(lineParamT: 0.5).t
        return segment.position(paramT: t)
    }

    func subtractingCircle(at point: Point2) -> SUPath {
        SUPath { $0.addEllipse(in: .init(center: point, size: .init(squared: circleSize))) }
    }

    @ViewBuilder var content: some View {
        if let segment = selector.segment, selector.focused {
            AnimatableReader(selector.viewport) {
                let segment = segment.applying($0.worldToView)
                let circlePosition = circlePosition(segment: segment)
                Circle()
                    .stroke(color, style: .init(lineWidth: lineWidth))
                    .fill(color.opacity(0.5))
                    .frame(size: .init(squared: circleSize))
                    .padding(touchablePadding)
                    .invisibleSoildOverlay()
                    .position(circlePosition)
                    .overlay {
                        SUPath { p in
                            let tessellated = segment.tessellated()
                            let fromT = tessellated.approxPathParamT(lineParamT: 0.1).t
                            let toT = tessellated.approxPathParamT(lineParamT: 0.9).t
                            segment.subsegment(fromT: fromT, toT: toT).append(to: &p)
                        }
                        .strokedPath(StrokeStyle(lineWidth: 2, lineCap: .round))
                        .subtracting(subtractingCircle(at: circlePosition))
                        .fill(color)
                        .allowsHitTesting(false)
                    }
                    .multipleGesture(global.focusedEdgeGesture(fromId: fromNodeId))
            }
        }
    }
}
