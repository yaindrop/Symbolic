import SwiftUI

private class GestureContext {
    var longPressAddedNodeId: UUID?
}

// MARK: - global actions

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
                let multiDrag = focusedPath.selectingNodes && focusedPath.activeNodeIds.contains(nodeId)
                let nodeIds = multiDrag ? .init(global.focusedPath.activeNodeIds) : [nodeId]
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
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Formula({ global.path.get(id: $0.pathId) }) static var path
            @Formula({ global.pathProperty.get(id: $0.pathId) }) static var property
            @Formula({ path($0)?.node(id: $0.nodeId) }) static var node

            @Selected({ global.viewport.sizedInfo }) var viewport
            @Selected({ node($0)?.position }) var position
            @Selected({ property($0)?.nodeType(id: $0.nodeId) }) var nodeType
            @Selected({ global.focusedPath.activeNodeIds.contains($0.nodeId) }) var active
            @Selected(configs: .init(animation: .faster), { global.focusedPath.selectingNodes }) var selectingNodes
            @Selected({ node($0).map { global.grid.snapped($0.position) } != nil }) var snapped
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
            AnimatableReader(selector.viewport) { viewport in
                nodeShape
                    .padding(touchablePadding)
                    .invisibleSoildOverlay()
                    .position(position.applying(viewport.worldToView))
                    .multipleGesture(global.nodeGesture(nodeId: nodeId, context: gestureContext))
                    .overlay { snappedMark(viewport) }
            }
        }
    }

    @ViewBuilder var nodeShape: some View {
        if selector.nodeType == .corner {
            RoundedRectangle(cornerRadius: 2)
                .stroke(.blue, style: StrokeStyle(lineWidth: 1))
                .fill(.blue.opacity(0.3))
                .overlay { focusMark }
                .frame(size: .init(squared: rectSize * (selector.selectingNodes ? 1.5 : 1)))
        } else {
            Circle()
                .stroke(.blue, style: StrokeStyle(lineWidth: selector.nodeType == .mirrored ? 2 : 1))
                .fill(.blue.opacity(0.3))
                .overlay { focusMark }
                .frame(size: .init(squared: circleSize * (selector.selectingNodes ? 1.5 : 1)))
        }
    }

    @ViewBuilder var focusMark: some View {
        if !selector.selectingNodes && selector.active {
            Circle()
                .fill(.blue)
                .scaleEffect(0.5)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder func snappedMark(_ viewport: SizedViewportInfo) -> some View {
        let position = selector.position?.applying(viewport.worldToView)
        if let position, selector.snapped {
            SUPath { path in
                path.move(to: position - .init(9, 0))
                path.addLine(to: position + .init(9, 0))
                path.move(to: position - .init(0, 9))
                path.addLine(to: position + .init(0, 9))
            }
            .stroke(.blue.opacity(0.8), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
    }
}
