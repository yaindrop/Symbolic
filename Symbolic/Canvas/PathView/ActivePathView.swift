import Foundation
import SwiftUI

// MARK: - ActivePathViewModel

class ActivePathViewModel: PathViewModel {
    override func boundsGesture() -> MultipleGestureModel<Void> {
        let model = MultipleGestureModel<Void>()
        func update(pending: Bool = false) -> (DragGesture.Value, Void) -> Void {
            { v, _ in global.documentUpdater.updateInView(activePath: .move(.init(offset: v.offset)), pending: pending) }
        }
        model.onTap { _, _ in global.activeItem.clearFocus() }
        model.onDrag(update(pending: true))
        model.onDragEnd(update())
        model.onTouchDown { global.canvasAction.start(continuous: .movePath) }
        model.onTouchUp { global.canvasAction.end(continuous: .movePath) }
        return model
    }

    override func nodeGesture(nodeId: UUID) -> (MultipleGestureModel<Point2>, NodeGestureContext) {
        let context = NodeGestureContext()
        let model = MultipleGestureModel<Point2>(configs: .init(durationThreshold: 0.2))
        var canAddEndingNode: Bool {
            guard let activePath = global.activeItem.activePath else { return false }
            return activePath.isEndingNode(id: nodeId)
        }
        func addEndingNode() {
            guard canAddEndingNode else { return }
            let id = UUID()
            context.longPressAddedNodeId = id
            global.activeItem.setFocus(node: id)
        }
        func moveAddedNode(newNodeId: UUID, offset: Vector2, pending: Bool = false) {
            global.documentUpdater.updateInView(activePath: .addEndingNode(.init(endingNodeId: nodeId, newNodeId: newNodeId, offset: offset)), pending: pending)
            if !pending {
                context.longPressAddedNodeId = nil
            }
        }
        func updateDrag(pending: Bool = false) -> (DragGesture.Value, Point2) -> Void {
            {
                if let newNodeId = context.longPressAddedNodeId {
                    moveAddedNode(newNodeId: newNodeId, offset: $0.offset, pending: pending)
                } else {
                    global.documentUpdater.updateInView(activePath: .moveNode(.init(nodeId: nodeId, offset: $1.offset(to: $0.location))), pending: pending)
                }
            }
        }
        func updateLongPress(position _: Point2, pending: Bool = false) {
            guard let newNodeId = context.longPressAddedNodeId else { return }
            moveAddedNode(newNodeId: newNodeId, offset: .zero, pending: pending)
        }
        model.onTap { _, _ in self.toggleFocus(nodeId: nodeId) }
        model.onLongPress { _, p in
            addEndingNode()
            updateLongPress(position: p, pending: true)
        }
        model.onLongPressEnd { _, p in updateLongPress(position: p) }
        model.onDrag(updateDrag(pending: true))
        model.onDragEnd(updateDrag())
        model.onTouchDown { global.canvasAction.start(continuous: .movePathNode) }
        model.onTouchUp { global.canvasAction.end(continuous: .movePathNode) }

        model.onTouchDown {
            global.canvasAction.start(continuous: .movePathNode)
            if canAddEndingNode {
                global.canvasAction.start(triggering: .addEndingNode)
            }
        }
        model.onDrag { _, _ in
            global.canvasAction.end(triggering: .addEndingNode)
        }
        model.onLongPress { _, _ in
            if canAddEndingNode {
                global.canvasAction.end(continuous: .movePathNode)
                global.canvasAction.end(triggering: .addEndingNode)
                global.canvasAction.start(continuous: .addAndMoveEndingNode)
            }
        }
        model.onTouchUp {
            global.canvasAction.end(triggering: .addEndingNode)
            global.canvasAction.end(continuous: .addAndMoveEndingNode)
            global.canvasAction.end(continuous: .movePathNode)
        }
        return (model, context)
    }

    override func edgeGesture(fromId: UUID) -> (MultipleGestureModel<PathSegment>, EdgeGestureContext) {
        let context = EdgeGestureContext()
        let model = MultipleGestureModel<PathSegment>(configs: .init(durationThreshold: 0.2))
        func split(at paramT: Scalar) {
            context.longPressParamT = paramT
            let id = UUID()
            context.longPressSplitNodeId = id
            global.activeItem.setFocus(node: id)
        }
        func moveSplitNode(paramT: Scalar, newNodeId: UUID, offset: Vector2, pending: Bool = false) {
            global.documentUpdater.updateInView(activePath: .splitSegment(.init(fromNodeId: fromId, paramT: paramT, newNodeId: newNodeId, offset: offset)), pending: pending)

            if !pending {
                context.longPressParamT = nil
            }
        }
        func updateDrag(pending: Bool = false) -> (DragGesture.Value, Any) -> Void {
            { v, _ in
                if let paramT = context.longPressParamT, let newNodeId = context.longPressSplitNodeId {
                    moveSplitNode(paramT: paramT, newNodeId: newNodeId, offset: v.offset, pending: pending)
                } else {
                    global.documentUpdater.updateInView(activePath: .move(.init(offset: v.offset)), pending: pending)
                }
            }
        }
        func updateLongPress(segment _: PathSegment, pending: Bool = false) {
            guard let paramT = context.longPressParamT, let newNodeId = context.longPressSplitNodeId else { return }
            moveSplitNode(paramT: paramT, newNodeId: newNodeId, offset: .zero, pending: pending)
        }
        model.onTap { _, _ in self.toggleFocus(edgeFromId: fromId) }
        model.onLongPress { v, s in
            split(at: s.paramT(closestTo: v.location).t)
            updateLongPress(segment: s, pending: true)
        }
        model.onLongPressEnd { _, s in updateLongPress(segment: s) }
        model.onDrag(updateDrag(pending: true))
        model.onDragEnd(updateDrag())

        model.onTouchDown {
            global.canvasAction.start(continuous: .movePath)
            global.canvasAction.start(triggering: .splitPathEdge)
        }
        model.onDrag { _, _ in
            global.canvasAction.end(triggering: .splitPathEdge)
        }
        model.onLongPress { _, _ in
            global.canvasAction.end(continuous: .movePath)
            global.canvasAction.end(triggering: .splitPathEdge)
            global.canvasAction.start(continuous: .splitAndMovePathNode)
        }
        model.onTouchUp {
            global.canvasAction.end(triggering: .splitPathEdge)
            global.canvasAction.end(continuous: .splitAndMovePathNode)
            global.canvasAction.end(continuous: .movePath)
        }
        return (model, context)
    }

    override func focusedEdgeGesture(fromId: UUID) -> MultipleGestureModel<Point2> {
        let model = MultipleGestureModel<Point2>()
        func update(pending: Bool = false) -> (DragGesture.Value, Point2) -> Void {
            { global.documentUpdater.updateInView(activePath: .moveEdge(.init(fromNodeId: fromId, offset: $1.offset(to: $0.location))), pending: pending) }
        }
        model.onDrag(update(pending: true))
        model.onDragEnd(update())
        model.onTouchDown { global.canvasAction.start(continuous: .movePathEdge) }
        model.onTouchUp { global.canvasAction.end(continuous: .movePathEdge) }
        return model
    }

    override func bezierGesture(fromId: UUID, isControl0: Bool) -> MultipleGestureModel<Void>? {
        let model = MultipleGestureModel<Void>()
        func update(pending: Bool = false) -> (DragGesture.Value, Void) -> Void {
            { v, _ in global.documentUpdater.updateInView(activePath: .moveEdgeControl(.init(fromNodeId: fromId, offset0: isControl0 ? v.offset : .zero, offset1: isControl0 ? .zero : v.offset)), pending: pending) }
        }
        model.onDrag(update(pending: true))
        model.onDragEnd(update())
        model.onTouchDown { global.canvasAction.start(continuous: .movePathBezierControl) }
        model.onTouchUp { global.canvasAction.end(continuous: .movePathBezierControl) }
        return model
    }

    private func toggleFocus(nodeId: UUID) {
        let focused = global.activeItem.pathFocusedPart?.nodeId == nodeId
        focused ? global.activeItem.clearFocus() : global.activeItem.setFocus(node: nodeId)
    }

    private func toggleFocus(edgeFromId: UUID) {
        let focused = global.activeItem.pathFocusedPart?.edgeId == edgeFromId
        focused ? global.activeItem.clearFocus() : global.activeItem.setFocus(edge: edgeFromId)
    }
}

// MARK: - ActivePathView

struct ActivePathView: View {
    var body: some View { tracer.range("ActivePathView body") { build {
        if let activePath {
            PathView(path: activePath, focusedPart: focusedPart)
                .environmentObject(viewModel)
                .onAppear { print("ActivePathView appear") }
                .onDisappear { print("ActivePathView disappear") }
        }
    } } }

    @Selected private var activePath = global.activeItem.activePath
    @Selected private var focusedPart = global.activeItem.pathFocusedPart
    private var viewModel: PathViewModel = ActivePathViewModel()
}
