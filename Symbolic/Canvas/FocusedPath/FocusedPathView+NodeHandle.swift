import SwiftUI

private class GestureContext {
    var nodeId: UUID?
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

    func nodesGesture(path: Path, context: GestureContext) -> MultipleGesture {
        func addEndingNode() {
            guard let nodeId = context.nodeId,
                  canAddEndingNode(nodeId: nodeId) else { return }
            let id = UUID()
            context.longPressAddedNodeId = id
            focusedPath.setFocus(node: id)
        }
        func moveAddedNode(newNodeId: UUID, offset: Vector2, pending: Bool = false) {
            guard let nodeId = context.nodeId else { return }
            documentUpdater.updateInView(focusedPath: .addEndingNode(.init(endingNodeId: nodeId, newNodeId: newNodeId, offset: offset)), pending: pending)
            if !pending {
                context.longPressAddedNodeId = nil
            }
        }
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            guard let nodeId = context.nodeId else { return }
            if let newNodeId = context.longPressAddedNodeId {
                moveAddedNode(newNodeId: newNodeId, offset: v.offset, pending: pending)
            } else {
                let multiDrag = focusedPath.selectingNodes && focusedPath.activeNodeIds.contains(nodeId)
                let nodeIds = multiDrag ? .init(focusedPath.activeNodeIds) : [nodeId]
                documentUpdater.updateInView(focusedPath: .moveNodes(.init(nodeIds: nodeIds, offset: v.offset)), pending: pending)
            }
        }
        func updateLongPress(pending: Bool = false) {
            guard let newNodeId = context.longPressAddedNodeId else { return }
            moveAddedNode(newNodeId: newNodeId, offset: .zero, pending: pending)
        }

        return .init(
            configs: .init(durationThreshold: 0.2),
            onPress: { info in
                let location = info.location.applying(viewport.toWorld)
                guard let nodeId = path.nodeId(closestTo: location) else { return }
                context.nodeId = nodeId
                canvasAction.start(continuous: .movePathNode)
                if canAddEndingNode(nodeId: nodeId) {
                    canvasAction.start(triggering: .addEndingNode)
                }
            },
            onPressEnd: { _, cancelled in
                context.nodeId = nil
                canvasAction.end(triggering: .addEndingNode)
                canvasAction.end(continuous: .addAndMoveEndingNode)
                canvasAction.end(continuous: .movePathNode)
                if cancelled { documentUpdater.cancel() }

            },

            onTap: { _ in
                guard let nodeId = context.nodeId else { return }
                onTap(node: nodeId)
            },

            onLongPress: { _ in
                guard let nodeId = context.nodeId else { return }
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
            onDragEnd: {
                updateDrag($0)
            }
        )
    }
}

// MARK: - NodeHandles

extension FocusedPathView {
    struct NodeHandles: View, TracedView, SelectorHolder {
        struct SelectorProps: Equatable { let pathId: UUID, nodeId: UUID }
        class Selector: SelectorBase {
            @Selected(configs: .init(syncNotify: true), { global.viewport.sizedInfo }) var viewport
            @Selected(configs: .init(syncNotify: true), { global.activeItem.focusedPath }) var path
            @Selected({ global.activeItem.focusedPathProperty }) var pathProperty
            @Selected({ global.focusedPath.activeNodeIds }) var activeNodeIds
            @Selected(configs: .init(animation: .faster), { global.focusedPath.selectingNodes }) var selectingNodes
            @Selected({ global.grid.gridStack }) var gridStack
        }

        @SelectorWrapper var selector

        @State private var gestureContext = GestureContext()

        var body: some View { trace {
            setupSelector {
                content
            }
        } }
    }
}

private extension FocusedPathView.NodeHandles {
    @ViewBuilder var content: some View {
        if let path = selector.path {
            AnimatableReader(selector.viewport) { viewport in
                snappedMarks(path: path, viewport: viewport)
                shapes(path: path, nodeType: .corner, viewport: viewport)
                shapes(path: path, nodeType: .locked, viewport: viewport)
                shapes(path: path, nodeType: .mirrored, viewport: viewport)
                activeMarks(path: path, viewport: viewport)
                touchables(path: path, viewport: viewport)
            }
        }
    }

    var circleSize: Scalar { 12 }
    var rectSize: Scalar { circleSize / 2 * 1.7725 } // sqrt of pi
    var touchablePadding: Scalar { 20 }

    func shapes(path: Path, nodeType: PathNodeType, viewport: SizedViewportInfo) -> some View {
        SUPath { p in
            for nodeId in path.nodeIds {
                guard selector.pathProperty?.nodeType(id: nodeId) == nodeType,
                      let node = selector.path?.node(id: nodeId) else { continue }
                let position = node.position.applying(viewport.worldToView)
                if nodeType == .corner {
                    let size = rectSize * (selector.selectingNodes ? 1.5 : 1)
                    p.addRoundedRect(in: .init(center: position, size: .init(squared: size)), cornerSize: .init(2, 2))
                } else {
                    let size = circleSize * (selector.selectingNodes ? 1.5 : 1)
                    p.addEllipse(in: .init(center: position, size: .init(squared: size)))
                }
            }
        }
        .stroke(.blue, style: StrokeStyle(lineWidth: nodeType == .mirrored ? 2 : 1))
        .fill(.blue.opacity(0.3))
        .allowsHitTesting(false)
    }

    func touchables(path: Path, viewport: SizedViewportInfo) -> some View {
        SUPath { p in
            for nodeId in path.nodeIds {
                guard let node = selector.path?.node(id: nodeId) else { continue }
                let position = node.position.applying(viewport.worldToView),
                    size = CGSize(squared: 40)
                p.addRect(.init(center: position, size: size))
            }
        }
        .fill(.blue.opacity(0.1))
        .multipleGesture(global.nodesGesture(path: path, context: gestureContext))
    }

    func activeMarks(path: Path, viewport: SizedViewportInfo) -> some View {
        SUPath { p in
            for nodeId in path.nodeIds {
                guard !selector.selectingNodes,
                      selector.activeNodeIds.contains(nodeId),
                      let node = selector.path?.node(id: nodeId) else { continue }
                let position = node.position.applying(viewport.worldToView),
                    size = CGSize(squared: circleSize / 2)
                p.addEllipse(in: .init(center: position, size: size))
            }
        }
        .fill(.blue)
        .allowsHitTesting(false)
    }

    func snappedMarks(path: Path, viewport: SizedViewportInfo) -> some View {
        SUPath { p in
            for nodeId in path.nodeIds {
                guard !selector.selectingNodes,
                      selector.activeNodeIds.contains(nodeId),
                      let node = selector.path?.node(id: nodeId),
                      let grid = selector.gridStack.first(where: { $0.snapped(node.position) }) else { continue }
                let position = node.position.applying(viewport.worldToView)
                p.move(to: position - .init(9, 0))
                p.addLine(to: position + .init(9, 0))
                p.move(to: position - .init(0, 9))
                p.addLine(to: position + .init(0, 9))
            }
        }
        .stroke(.blue.opacity(0.5))
        .allowsHitTesting(false)
    }
}
