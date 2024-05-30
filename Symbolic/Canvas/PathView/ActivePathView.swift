import Foundation
import SwiftUI

// MARK: - ActivePathViewModel

class ActivePathViewModel: PathViewModel {
    override func nodeGesture(nodeId: UUID, context: NodeGestureContext) -> MultipleGesture<Point2> {
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
        func updateDrag(_ v: DragGesture.Value, _ p: Point2, pending: Bool = false) {
            if let newNodeId = context.longPressAddedNodeId {
                moveAddedNode(newNodeId: newNodeId, offset: v.offset, pending: pending)
            } else {
                global.documentUpdater.updateInView(activePath: .moveNode(.init(nodeId: nodeId, offset: p.offset(to: v.location))), pending: pending)
            }
        }
        func updateLongPress(position _: Point2, pending: Bool = false) {
            guard let newNodeId = context.longPressAddedNodeId else { return }
            moveAddedNode(newNodeId: newNodeId, offset: .zero, pending: pending)
        }

        return .init(
            configs: .init(durationThreshold: 0.2),
            onTouchDown: {
                global.canvasAction.start(continuous: .movePathNode)
                if canAddEndingNode {
                    global.canvasAction.start(triggering: .addEndingNode)
                }
            },
            onTouchUp: {
                global.canvasAction.end(triggering: .addEndingNode)
                global.canvasAction.end(continuous: .addAndMoveEndingNode)
                global.canvasAction.end(continuous: .movePathNode)
            },

            onTap: { _, _ in self.toggleFocus(nodeId: nodeId) },

            onLongPress: { _, p in
                addEndingNode()
                updateLongPress(position: p, pending: true)
                if canAddEndingNode {
                    global.canvasAction.end(continuous: .movePathNode)
                    global.canvasAction.end(triggering: .addEndingNode)
                    global.canvasAction.start(continuous: .addAndMoveEndingNode)
                }
            },
            onLongPressEnd: { _, p in updateLongPress(position: p) },

            onDrag: {
                updateDrag($0, $1, pending: true)
                global.canvasAction.end(triggering: .addEndingNode)
            },
            onDragEnd: { updateDrag($0, $1) }
        )
    }

    override func edgeGesture(fromId: UUID, context: EdgeGestureContext) -> MultipleGesture<PathSegment> {
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
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            if let paramT = context.longPressParamT, let newNodeId = context.longPressSplitNodeId {
                moveSplitNode(paramT: paramT, newNodeId: newNodeId, offset: v.offset, pending: pending)
            } else {
                global.documentUpdater.updateInView(activePath: .move(.init(offset: v.offset)), pending: pending)
            }
        }
        func updateLongPress(segment _: PathSegment, pending: Bool = false) {
            guard let paramT = context.longPressParamT, let newNodeId = context.longPressSplitNodeId else { return }
            moveSplitNode(paramT: paramT, newNodeId: newNodeId, offset: .zero, pending: pending)
        }

        return .init(
            configs: .init(durationThreshold: 0.2),
            onTouchDown: {
                global.canvasAction.start(continuous: .movePath)
                global.canvasAction.start(triggering: .splitPathEdge)
            },
            onTouchUp: {
                global.canvasAction.end(triggering: .splitPathEdge)
                global.canvasAction.end(continuous: .splitAndMovePathNode)
                global.canvasAction.end(continuous: .movePath)
            },
            onTap: { _, _ in self.toggleFocus(edgeFromId: fromId) },
            onLongPress: { v, s in
                split(at: s.paramT(closestTo: v.location).t)
                updateLongPress(segment: s, pending: true)
                global.canvasAction.end(continuous: .movePath)
                global.canvasAction.end(triggering: .splitPathEdge)
                global.canvasAction.start(continuous: .splitAndMovePathNode)
            },
            onLongPressEnd: { _, s in updateLongPress(segment: s) },
            onDrag: { v, _ in
                updateDrag(v, pending: true)
                global.canvasAction.end(triggering: .splitPathEdge)
            },
            onDragEnd: { v, _ in updateDrag(v) }
        )
    }

    override func focusedEdgeGesture(fromId: UUID) -> MultipleGesture<Point2> {
        func updateDrag(_ v: DragGesture.Value, _: Point2, pending: Bool = false) {
            global.documentUpdater.updateInView(activePath: .moveEdge(.init(fromNodeId: fromId, offset: v.offset)), pending: pending)
        }
        return .init(
            onTouchDown: { global.canvasAction.start(continuous: .movePathEdge) },
            onTouchUp: { global.canvasAction.end(continuous: .movePathEdge) },
            onDrag: { updateDrag($0, $1, pending: true) },
            onDragEnd: { updateDrag($0, $1) }
        )
    }

    override func bezierGesture(fromId: UUID, isControl0: Bool) -> MultipleGesture<Void> {
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            global.documentUpdater.updateInView(activePath: .moveEdgeControl(.init(fromNodeId: fromId, offset0: isControl0 ? v.offset : .zero, offset1: isControl0 ? .zero : v.offset)), pending: pending)
        }
        return .init(
            onTouchDown: { global.canvasAction.start(continuous: .movePathBezierControl) },
            onTouchUp: { global.canvasAction.end(continuous: .movePathBezierControl) },
            onDrag: { v, _ in updateDrag(v, pending: true) },
            onDragEnd: { v, _ in updateDrag(v) }
        )
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
