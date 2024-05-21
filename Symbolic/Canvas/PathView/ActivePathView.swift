import Foundation
import SwiftUI

// MARK: - ActivePathViewModel

class ActivePathViewModel: PathViewModel {
    override func boundsGesture() -> MultipleGestureModel<Void> {
        let model = MultipleGestureModel<Void>()
        func update(pending: Bool = false) -> (DragGesture.Value, Void) -> Void {
            { v, _ in global.pathUpdaterInView.updateActivePath(moveByOffset: Vector2(v.translation), pending: pending) }
        }
        model.onDrag(update(pending: true))
        model.onDragEnd(update())
        model.onTouchDown { global.canvasAction.start(continuous: .movePath) }
        model.onTouchUp { global.canvasAction.end(continuous: .movePath) }
        return model
    }

    override func nodeGesture(nodeId: UUID) -> MultipleGestureModel<Point2> {
        let model = MultipleGestureModel<Point2>()
        func update(pending: Bool = false) -> (DragGesture.Value, Point2) -> Void {
            { global.pathUpdaterInView.updateActivePath(moveNode: nodeId, offset: $1.offset(to: $0.location), pending: pending) }
        }
        model.onTap { _, _ in self.toggleFocus(nodeId: nodeId) }
        model.onDrag(update(pending: true))
        model.onDragEnd(update())
        model.onTouchDown { global.canvasAction.start(continuous: .movePathNode) }
        model.onTouchUp { global.canvasAction.end(continuous: .movePathNode) }
        return model
    }

    override func edgeGesture(fromId: UUID) -> (MultipleGestureModel<PathSegment>, EdgeGestureContext) {
        let context = EdgeGestureContext()
        let model = MultipleGestureModel<PathSegment>()
        func split(at paramT: Scalar) {
            context.longPressParamT = paramT
            let id = UUID()
            context.longPressSplitNodeId = id
            global.activePath.setFocus(node: id)
        }
        func moveSplitNode(to p: Point2, pending: Bool = false) {
            guard let longPressParamT = context.longPressParamT, let longPressSplitNodeId = context.longPressSplitNodeId else { return }
            global.pathUpdaterInView.updateActivePath(splitSegment: fromId, paramT: longPressParamT, newNodeId: longPressSplitNodeId, position: p, pending: pending)
            if !pending {
                context.longPressParamT = nil
            }
        }
        func updateDrag(pending: Bool = false) -> (DragGesture.Value, Any) -> Void {
            { v, _ in
                if context.longPressSplitNodeId == nil {
                    global.pathUpdaterInView.updateActivePath(moveByOffset: Vector2(v.translation), pending: pending)
                } else {
                    moveSplitNode(to: v.location, pending: pending)
                }
            }
        }
        func updateLongPress(segment: PathSegment, pending: Bool = false) {
            guard let longPressParamT = context.longPressParamT else { return }
            moveSplitNode(to: segment.position(paramT: longPressParamT), pending: pending)
        }
        model.onTap { _, _ in self.toggleFocus(edgeFromId: fromId) }
        model.onLongPress { v, s in
            split(at: s.paramT(closestTo: v.location).t)
            updateLongPress(segment: s, pending: true)
        }
        model.onLongPressEnd { _, s in updateLongPress(segment: s) }
        model.onDrag(updateDrag(pending: true))
        model.onDragEnd(updateDrag())

        model.onTouchDown { global.canvasAction.start(triggering: .splitPathEdge) }
        model.onDrag { _, _ in global.canvasAction.end(triggering: .splitPathEdge) }
        model.onLongPress { _, _ in
            global.canvasAction.end(triggering: .splitPathEdge)
            global.canvasAction.start(continuous: .splitAndMovePathNode)
        }
        model.onTouchUp {
            global.canvasAction.end(triggering: .splitPathEdge)
            global.canvasAction.end(continuous: .splitAndMovePathNode)
        }
        return (model, context)
    }

    override func focusedEdgeGesture(fromId: UUID) -> MultipleGestureModel<Point2> {
        let model = MultipleGestureModel<Point2>()
        func update(pending: Bool = false) -> (DragGesture.Value, Point2) -> Void {
            { value, origin in global.pathUpdaterInView.updateActivePath(moveEdge: fromId, offset: origin.offset(to: value.location), pending: pending) }
        }
        model.onDrag(update(pending: true))
        model.onDragEnd(update())
        model.onTouchDown { global.canvasAction.start(continuous: .movePathEdge) }
        model.onTouchUp { global.canvasAction.end(continuous: .movePathEdge) }
        return model
    }

    override func bezierGesture(fromId: UUID, updater: @escaping (PathEdge.Bezier, Point2) -> PathEdge.Bezier) -> MultipleGestureModel<PathEdge.Bezier>? {
        let model = MultipleGestureModel<PathEdge.Bezier>()
        func update(pending: Bool = false) -> (DragGesture.Value, PathEdge.Bezier) -> Void {
            { global.pathUpdaterInView.updateActivePath(edge: fromId, bezier: updater($1, $0.location), pending: pending) }
        }
        model.onDrag(update(pending: true))
        model.onDragEnd(update())
        model.onTouchDown { global.canvasAction.start(continuous: .movePathBezierControl) }
        model.onTouchUp { global.canvasAction.end(continuous: .movePathBezierControl) }
        return model
    }

    override func arcGesture(fromId: UUID, updater: @escaping (PathEdge.Arc, Scalar) -> PathEdge.Arc) -> MultipleGestureModel<(PathEdge.Arc, Point2)> {
        let model = MultipleGestureModel<(PathEdge.Arc, Point2)>()
        func update(pending: Bool = false) -> (DragGesture.Value, (PathEdge.Arc, Point2)) -> Void {
            { global.pathUpdaterInView.updateActivePath(edge: fromId, arc: updater($1.0, $0.location.distance(to: $1.1) * 2), pending: pending) }
        }
        model.onDrag(update(pending: true))
        model.onDragEnd(update())
        model.onTouchDown { global.canvasAction.start(continuous: .movePathArcControl) }
        model.onTouchUp { global.canvasAction.end(continuous: .movePathArcControl) }
        return model
    }

    private func toggleFocus(nodeId: UUID) {
        let focused = global.activePath.focusedPart?.nodeId == nodeId
        focused ? global.activePath.clearFocus() : global.activePath.setFocus(node: nodeId)
    }

    private func toggleFocus(edgeFromId: UUID) {
        let focused = global.activePath.focusedPart?.edgeId == edgeFromId
        focused ? global.activePath.clearFocus() : global.activePath.setFocus(edge: edgeFromId)
    }
}

// MARK: - ActivePathView

struct ActivePathView: View {
    var body: some View {
        if let activePath {
            PathView(path: activePath, focusedPart: focusedPart)
                .environmentObject(viewModel)
        }
    }

    @Selected private var activePath = global.activePath.pendingActivePath
    @Selected private var focusedPart = global.activePath.focusedPart
    private var viewModel: PathViewModel = ActivePathViewModel()
}
