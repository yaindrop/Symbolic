import Foundation
import SwiftUI

// MARK: - ActivePathViewModel

class ActivePathViewModel: PathViewModel {
    override func nodeGesture(nodeId: UUID, context: NodeGestureContext) -> MultipleGesture {
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
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            if let newNodeId = context.longPressAddedNodeId {
                moveAddedNode(newNodeId: newNodeId, offset: v.offset, pending: pending)
            } else {
                global.documentUpdater.updateInView(activePath: .moveNode(.init(nodeId: nodeId, offset: v.offset)), pending: pending)
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

            onTap: { _ in self.toggleFocus(nodeId: nodeId) },

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
            onTap: { _ in self.toggleFocus(edgeFromId: fromId) },
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
            global.documentUpdater.updateInView(activePath: .moveEdge(.init(fromNodeId: fromId, offset: v.offset)), pending: pending)
        }
        return .init(
            onPress: { global.canvasAction.start(continuous: .movePathEdge) },
            onPressEnd: { cancelled in
                global.canvasAction.end(continuous: .movePathEdge)
                if cancelled { global.documentUpdater.cancel() }
            },

            onDrag: { updateDrag($0, pending: true) },
            onDragEnd: { updateDrag($0) }
        )
    }

    override func bezierGesture(fromId: UUID, isControl0: Bool) -> MultipleGesture {
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            global.documentUpdater.updateInView(activePath: .moveEdgeControl(.init(fromNodeId: fromId, offset0: isControl0 ? v.offset : .zero, offset1: isControl0 ? .zero : v.offset)), pending: pending)
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

struct ActivePathView: View, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.activeItem.activePath }) var activePath
        @Selected({ global.activeItem.activePathProperty }) var activePathProperty
        @Selected({ global.activeItem.pathFocusedPart }) var focusedPart
    }

    @StateObject var selector = Selector()

    var body: some View { tracer.range("ActivePathView body") {
        setupSelector {
            if let path = selector.activePath, let property = selector.activePathProperty {
                PathView(path: path, property: property, focusedPart: selector.focusedPart)
                    .environmentObject(viewModel)
            }
        }
    } }

    private var viewModel: PathViewModel = ActivePathViewModel()
}
