import SwiftUI

private class GestureContext {
    var longPressAddedNodeId: UUID?
}

private extension GlobalStores {
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

    func canAddEndingNode(nodeId: UUID) -> Bool {
        guard let focusedPath = activeItem.focusedPath else { return false }
        return focusedPath.isEndingNode(id: nodeId)
    }

    func nodeGesture(nodeId: UUID, context: GestureContext) -> MultipleGesture {
        func addEndingNode() {
            guard canAddEndingNode(nodeId: nodeId) else { return }
            let id = UUID()
            context.longPressAddedNodeId = id
            focusedPath.setFocus(node: id)
        }
        func moveAddedNode(newNodeId: UUID, offset: Vector2, pending: Bool = false) {
            documentUpdater.updateInView(focusedPath: .addEndingNode(.init(endingNodeId: nodeId, newNodeId: newNodeId, offset: offset)), pending: pending)
            if !pending {
                context.longPressAddedNodeId = nil
            }
        }
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            if let newNodeId = context.longPressAddedNodeId {
                moveAddedNode(newNodeId: newNodeId, offset: v.offset, pending: pending)
            } else {
                let nodeIds = global.focusedPath.activeNodeIds.contains(nodeId) ? .init(global.focusedPath.activeNodeIds) : [nodeId]
                documentUpdater.updateInView(focusedPath: .moveNodes(.init(nodeIds: nodeIds, offset: v.offset)), pending: pending)
            }
        }
        func updateLongPress(pending: Bool = false) {
            guard let newNodeId = context.longPressAddedNodeId else { return }
            moveAddedNode(newNodeId: newNodeId, offset: .zero, pending: pending)
        }

        return .init(
            configs: .init(durationThreshold: 0.2),
            onPress: {
                canvasAction.start(continuous: .movePathNode)
                if canAddEndingNode(nodeId: nodeId) {
                    canvasAction.start(triggering: .addEndingNode)
                }
            },
            onPressEnd: { cancelled in
                canvasAction.end(triggering: .addEndingNode)
                canvasAction.end(continuous: .addAndMoveEndingNode)
                canvasAction.end(continuous: .movePathNode)
                if cancelled { documentUpdater.cancel() }

            },

            onTap: { _ in onTap(node: nodeId) },

            onLongPress: { _ in
                addEndingNode()
                updateLongPress(pending: true)
                if canAddEndingNode(nodeId: nodeId) {
                    canvasAction.end(continuous: .movePathNode)
                    canvasAction.end(triggering: .addEndingNode)
                    canvasAction.start(continuous: .addAndMoveEndingNode)
                }
            },
            onLongPressEnd: { _ in updateLongPress() },

            onDrag: {
                updateDrag($0, pending: true)
                canvasAction.end(triggering: .addEndingNode)
            },
            onDragEnd: { updateDrag($0) }
        )
    }
}

// MARK: - NodeHandle

extension FocusedPathView {
    struct NodeHandle: View, TracedView, EquatableBy, ComputedSelectorHolder {
        let pathId: UUID, nodeId: UUID

        var equatableBy: some Equatable { pathId; nodeId }

        struct SelectorProps: Equatable { let pathId: UUID, nodeId: UUID }
        class Selector: SelectorBase {
            override var syncNotify: Bool { true }
            @Formula({ global.path.get(id: $0.pathId) }) static var path
            @Formula({ global.pathProperty.get(id: $0.pathId) }) static var property
            @Selected({ path($0)?.node(id: $0.nodeId)?.position.applying(global.viewport.toView) }) var position
            @Selected({ property($0)?.nodeType(id: $0.nodeId) }) var nodeType
            @Selected({ global.focusedPath.activeNodeIds.contains($0.nodeId) }) var active
            @Selected(animation: .fast, { global.focusedPath.selectingNodes }) var selectingNodes
        }

        @SelectorWrapper var selector

        @State private var gestureContext = GestureContext()

        var body: some View { trace {
            setupSelector(.init(pathId: pathId, nodeId: nodeId)) {
                content
            }
        } }
    }
}

// MARK: private

extension FocusedPathView.NodeHandle {
    var circleSize: Scalar { 12 }
    var rectSize: Scalar { circleSize / 2 * 1.7725 } // sqrt of pi
    var touchablePadding: Scalar { 20 }

    @ViewBuilder var content: some View {
        if let position = selector.position {
            nodeShape
                .padding(touchablePadding)
                .invisibleSoildOverlay()
                .position(position)
                .multipleGesture(global.nodeGesture(nodeId: nodeId, context: gestureContext))
        }
    }

    @ViewBuilder var nodeShape: some View {
        if selector.nodeType == .corner {
            RoundedRectangle(cornerRadius: 2)
                .stroke(.blue, style: StrokeStyle(lineWidth: 1))
                .fill(.blue.opacity(0.3))
                .if(!selector.selectingNodes && selector.active) { $0.overlay { focusMark }}
                .frame(size: .init(squared: rectSize * (selector.selectingNodes ? 1.5 : 1)))
        } else {
            Circle()
                .stroke(.blue, style: StrokeStyle(lineWidth: selector.nodeType == .mirrored ? 2 : 1))
                .fill(.blue.opacity(0.3))
                .if(!selector.selectingNodes && selector.active) { $0.overlay { focusMark }}
                .frame(size: .init(squared: circleSize * (selector.selectingNodes ? 1.5 : 1)))
        }
    }

    @ViewBuilder var focusMark: some View {
        Circle()
            .fill(.blue)
            .scaleEffect(0.5)
            .allowsHitTesting(false)
    }
}
