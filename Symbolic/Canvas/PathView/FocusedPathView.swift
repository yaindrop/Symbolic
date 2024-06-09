import SwiftUI

private extension GlobalStore {
    func onTap(node id: UUID) {
        if focusedPath.selectingNodes {
            if focusedPath.activeNodeIds.contains(id) {
                focusedPath.selectRemove(node: [id])
            } else {
                focusedPath.selectAdd(node: [id])
            }
        } else {
            let focused = focusedPath.focusedNodeId == id
            focused ? focusedPath.clear() : focusedPath.setFocus(node: id)
        }
    }
}

private extension GlobalStore {
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
}

// MARK: - FocusedPathViewModel

class FocusedPathViewModel: PathViewModel {
    override func nodeGesture(nodeId: UUID, context: NodeGestureContext) -> MultipleGesture {
        var canAddEndingNode: Bool {
            guard let focusedPath = global.activeItem.focusedPath else { return false }
            return focusedPath.isEndingNode(id: nodeId)
        }
        func addEndingNode() {
            guard canAddEndingNode else { return }
            let id = UUID()
            context.longPressAddedNodeId = id
            global.focusedPath.setFocus(node: id)
        }
        func moveAddedNode(newNodeId: UUID, offset: Vector2, pending: Bool = false) {
            global.documentUpdater.updateInView(focusedPath: .addEndingNode(.init(endingNodeId: nodeId, newNodeId: newNodeId, offset: offset)), pending: pending)
            if !pending {
                context.longPressAddedNodeId = nil
            }
        }
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            if let newNodeId = context.longPressAddedNodeId {
                moveAddedNode(newNodeId: newNodeId, offset: v.offset, pending: pending)
            } else {
                global.documentUpdater.updateInView(focusedPath: .moveNode(.init(nodeId: nodeId, offset: v.offset)), pending: pending)
            }
        }
        func updateLongPress(pending: Bool = false) {
            guard let newNodeId = context.longPressAddedNodeId else { return }
            moveAddedNode(newNodeId: newNodeId, offset: .zero, pending: pending)
        }

        return .init(
            configs: .init(durationThreshold: 0.2),
            onPress: {
                global.canvasAction.start(continuous: .movePathNode)
                if canAddEndingNode {
                    global.canvasAction.start(triggering: .addEndingNode)
                }
            },
            onPressEnd: { cancelled in
                global.canvasAction.end(triggering: .addEndingNode)
                global.canvasAction.end(continuous: .addAndMoveEndingNode)
                global.canvasAction.end(continuous: .movePathNode)
                if cancelled { global.documentUpdater.cancel() }

            },

            onTap: { _ in global.onTap(node: nodeId) },

            onLongPress: { _ in
                addEndingNode()
                updateLongPress(pending: true)
                if canAddEndingNode {
                    global.canvasAction.end(continuous: .movePathNode)
                    global.canvasAction.end(triggering: .addEndingNode)
                    global.canvasAction.start(continuous: .addAndMoveEndingNode)
                }
            },
            onLongPressEnd: { _ in updateLongPress() },

            onDrag: {
                updateDrag($0, pending: true)
                global.canvasAction.end(triggering: .addEndingNode)
            },
            onDragEnd: { updateDrag($0) }
        )
    }

    override func edgeGesture(fromId: UUID, segment: PathSegment, context: EdgeGestureContext) -> MultipleGesture {
        func split(at paramT: Scalar) {
            context.longPressParamT = paramT
            let id = UUID()
            context.longPressSplitNodeId = id
            global.focusedPath.setFocus(node: id)
        }
        func moveSplitNode(paramT: Scalar, newNodeId: UUID, offset: Vector2, pending: Bool = false) {
            global.documentUpdater.updateInView(focusedPath: .splitSegment(.init(fromNodeId: fromId, paramT: paramT, newNodeId: newNodeId, offset: offset)), pending: pending)

            if !pending {
                context.longPressParamT = nil
            }
        }
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            if let paramT = context.longPressParamT, let newNodeId = context.longPressSplitNodeId {
                moveSplitNode(paramT: paramT, newNodeId: newNodeId, offset: v.offset, pending: pending)
            } else if let pathId = global.activeItem.focusedPath?.id {
                global.documentUpdater.updateInView(path: .move(.init(pathIds: [pathId], offset: v.offset)), pending: pending)
            }
        }
        func updateLongPress(segment _: PathSegment, pending: Bool = false) {
            guard let paramT = context.longPressParamT, let newNodeId = context.longPressSplitNodeId else { return }
            moveSplitNode(paramT: paramT, newNodeId: newNodeId, offset: .zero, pending: pending)
        }

        return .init(
            configs: .init(durationThreshold: 0.2),
            onPress: {
                global.canvasAction.start(continuous: .movePath)
                global.canvasAction.start(triggering: .splitPathEdge)
            },
            onPressEnd: { cancelled in
                global.canvasAction.end(triggering: .splitPathEdge)
                global.canvasAction.end(continuous: .splitAndMovePathNode)
                global.canvasAction.end(continuous: .movePath)
                if cancelled { global.documentUpdater.cancel() }

            },
            onTap: { _ in global.onTap(segment: fromId) },
            onLongPress: {
                split(at: segment.paramT(closestTo: $0.location).t)
                updateLongPress(segment: segment, pending: true)
                global.canvasAction.end(continuous: .movePath)
                global.canvasAction.end(triggering: .splitPathEdge)
                global.canvasAction.start(continuous: .splitAndMovePathNode)
            },
            onLongPressEnd: { _ in updateLongPress(segment: segment) },
            onDrag: {
                updateDrag($0, pending: true)
                global.canvasAction.end(triggering: .splitPathEdge)
            },
            onDragEnd: { updateDrag($0) }
        )
    }

    override func focusedEdgeGesture(fromId: UUID) -> MultipleGesture {
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            global.documentUpdater.updateInView(focusedPath: .moveEdge(.init(fromNodeId: fromId, offset: v.offset)), pending: pending)
        }
        return .init(
            onPress: { global.canvasAction.start(continuous: .movePathEdge) },
            onPressEnd: { cancelled in
                global.canvasAction.end(continuous: .movePathEdge)
                if cancelled { global.documentUpdater.cancel() }
            },

            onTap: { _ in global.onTap(segment: fromId) },
            onDrag: { updateDrag($0, pending: true) },
            onDragEnd: { updateDrag($0) }
        )
    }

    override func bezierGesture(fromId: UUID, isControl0: Bool) -> MultipleGesture {
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            global.documentUpdater.updateInView(focusedPath: .moveEdgeControl(.init(fromNodeId: fromId, offset0: isControl0 ? v.offset : .zero, offset1: isControl0 ? .zero : v.offset)), pending: pending)
        }
        return .init(
            onPress: { global.canvasAction.start(continuous: .movePathBezierControl) },
            onPressEnd: { cancelled in
                global.canvasAction.end(continuous: .movePathBezierControl)
                if cancelled { global.documentUpdater.cancel() }
            },
            onDrag: { updateDrag($0, pending: true) },
            onDragEnd: { updateDrag($0) }
        )
    }
}

// MARK: - FocusedPathView

struct FocusedPathView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.activeItem.focusedPath }) var path
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            if let path = selector.path {
                PathView(path: path)
                    .environmentObject(viewModel)
            }
        }
    } }

    private var viewModel: PathViewModel = FocusedPathViewModel()
}
