import SwiftUI

private class GestureContext {
    var longPressParamT: Scalar?
    var longPressSplitNodeId: UUID?
}

// MARK: - global actions

private extension GlobalStores {
    func onTap(segment fromId: UUID) {
        if focusedPath.selectingNodes {
            guard let path = activeItem.focusedPath, let toId = path.nodeId(after: fromId) else { return }
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

    func segmentGesture(fromId: UUID, segment: PathSegment, context: GestureContext) -> MultipleGesture {
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
            onPress: { _ in
                canvasAction.start(continuous: .movePath)
                canvasAction.start(triggering: .splitPathSegment)
            },
            onPressEnd: { _, cancelled in
                canvasAction.end(triggering: .splitPathSegment)
                canvasAction.end(continuous: .splitAndMovePathNode)
                canvasAction.end(continuous: .movePath)
                if cancelled { documentUpdater.cancel() }

            },
            onTap: { _ in onTap(segment: fromId) },
            onLongPress: {
                split(at: segment.paramT(closestTo: $0.location).t)
                updateLongPress(segment: segment, pending: true)
                canvasAction.end(continuous: .movePath)
                canvasAction.end(triggering: .splitPathSegment)
                canvasAction.start(continuous: .splitAndMovePathNode)
            },
            onLongPressEnd: { _ in updateLongPress(segment: segment) },
            onDrag: {
                updateDrag($0, pending: true)
                canvasAction.end(triggering: .splitPathSegment)
            },
            onDragEnd: { updateDrag($0) }
        )
    }

    func focusedSegmentGesture(fromId: UUID) -> MultipleGesture {
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            guard let toId = activeItem.focusedPath?.nodeId(after: fromId) else { return }
            documentUpdater.updateInView(focusedPath: .moveNodes(.init(nodeIds: [fromId, toId], offset: v.offset)), pending: pending)
        }
        return .init(
            onPress: { _ in canvasAction.start(continuous: .movePathSegment) },
            onPressEnd: { _, cancelled in
                canvasAction.end(continuous: .movePathSegment)
                if cancelled { documentUpdater.cancel() }
            },

            onTap: { _ in onTap(segment: fromId) },
            onDrag: { updateDrag($0, pending: true) },
            onDragEnd: { updateDrag($0) }
        )
    }
}

// MARK: - SegmentHandle

extension FocusedPathView {
    struct SegmentHandle: View, TracedView, EquatableBy, ComputedSelectorHolder {
        let pathId: UUID, fromNodeId: UUID

        var equatableBy: some Equatable { pathId; fromNodeId }

        struct SelectorProps: Equatable { let pathId: UUID, fromNodeId: UUID }
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Formula({ global.path.get(id: $0.pathId) }) static var path

            @Selected({ global.viewportUpdater.referenceSizedInfo }) var viewport
            @Selected({ path($0)?.segment(fromId: $0.fromNodeId) }) var segment
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

private extension FocusedPathView.SegmentHandle {
    @ViewBuilder var content: some View {
        if let segment = selector.segment {
            AnimatableReader(selector.viewport) {
                let segment = segment.applying($0.worldToView)
                SUPath { p in segment.append(to: &p) }
                    .strokedPath(StrokeStyle(lineWidth: 24, lineCap: .round))
                    .fill(Color.invisibleSolid)
                    .multipleGesture(global.segmentGesture(fromId: fromNodeId, segment: segment, context: gestureContext))
            }
        }
    }
}

// MARK: - FocusedSegmentHandle

extension FocusedPathView {
    struct FocusedSegmentHandle: View, TracedView, EquatableBy, ComputedSelectorHolder {
        @ObservedObject var env: FocusedPathView.Selector
        let pathId: UUID, fromNodeId: UUID

        var equatableBy: some Equatable { pathId; fromNodeId }

        struct SelectorProps: Equatable { let pathId: UUID, fromNodeId: UUID }
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Formula({ global.path.get(id: $0.pathId) }) static var path

            @Selected({ path($0)?.segment(fromId: $0.fromNodeId) }) var segment
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

private extension FocusedPathView.FocusedSegmentHandle {
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
            AnimatableReader(env.viewport) {
                let segment = segment.applying($0.worldToView)
                let circlePosition = circlePosition(segment: segment)
                Circle()
                    .stroke(color, style: .init(lineWidth: lineWidth))
                    .fill(color.opacity(0.5))
                    .frame(size: .init(squared: circleSize))
                    .padding(touchablePadding)
                    .invisibleSoildOverlay()
                    .position(circlePosition)
                    .multipleGesture(global.focusedSegmentGesture(fromId: fromNodeId))
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
            }
        }
    }
}
