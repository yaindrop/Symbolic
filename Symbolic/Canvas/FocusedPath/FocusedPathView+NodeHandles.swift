import SwiftUI

private class GestureContext: ObservableObject {
    var nodeId: UUID?

    @Published var dragOffset: Vector2 = .zero

    @Published var actionWheelNodeId: UUID?
    var actionWheelOption: ActionWheel.Option?

    enum PendingAction {
        case moveNodes(PathAction.Update.MoveNodes)
        case addEndingNode(PathAction.Update.AddEndingNode)
        case breakAtNode(PathAction.BreakAtNode)
    }

    var pendingAction: PendingAction?

    func setup(_ nodeId: UUID) {
        self.nodeId = nodeId
        dragOffset = .zero
        actionWheelNodeId = nil
        actionWheelOption = nil
        pendingAction = nil
    }
}

// MARK: - global actions

private extension GlobalStores {
    func start(context: GestureContext, _ action: GestureContext.PendingAction) {
        context.actionWheelNodeId = nil
        context.pendingAction = action
        update(action, pending: true)
    }

    func update(_ action: GestureContext.PendingAction, offset: Vector2? = nil, pending: Bool = false) {
        switch action {
        case var .moveNodes(action):
            action.offset = offset ?? action.offset
            documentUpdater.update(focusedPath: .moveNodes(action), pending: pending)
        case var .addEndingNode(action):
            action.offset = offset ?? action.offset
            documentUpdater.update(focusedPath: .addEndingNode(action), pending: pending)
        case var .breakAtNode(action):
            action.offset = offset ?? action.offset
            documentUpdater.update(path: .breakAtNode(action), pending: pending)
        }
    }

    func nodesGesture(context: GestureContext) -> MultipleGesture {
        var canAddEndingNode: Bool {
            guard let nodeId = context.nodeId,
                  let focusedPath = activeItem.focusedPath else { return false }
            return focusedPath.isEndingNode(id: nodeId)
        }
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            context.dragOffset = v.offset
            guard context.actionWheelNodeId == nil else { return }
            let offset = v.offset.applying(viewport.toWorld)
            if let action = context.pendingAction {
                update(action, offset: offset, pending: pending)
            } else {
                guard let nodeId = context.nodeId else { return }
                let multiDrag = focusedPath.selectingNodes && focusedPath.activeNodeIds.contains(nodeId)
                let nodeIds = multiDrag ? .init(focusedPath.activeNodeIds) : [nodeId]
                start(context: context, .moveNodes(.init(nodeIds: nodeIds, offset: offset)))
            }
        }

        return .init(
            configs: .init(durationThreshold: 0.2),
            onPress: { info in
                let location = info.location.applying(viewport.toWorld)
                guard let path = activeItem.focusedPath,
                      let nodeId = path.nodeId(closestTo: location) else { return }
                context.setup(nodeId)
                canvasAction.start(continuous: .movePathNode)
                canvasAction.start(triggering: .pathNodeActions)
            },
            onPressEnd: { _, cancelled in
                context.nodeId = nil
                canvasAction.end(triggering: .pathNodeActions)
                canvasAction.end(continuous: .addAndMoveEndingNode)
                canvasAction.end(continuous: .movePathNode)
                if cancelled { documentUpdater.cancel() }
            },

            onTap: { _ in
                guard let nodeId = context.nodeId else { return }
                focusedPath.onTap(node: nodeId)
            },

            onLongPress: { _ in
                withAnimation { context.actionWheelNodeId = context.nodeId }
                if let nodeId = context.nodeId {
                    focusedPath.setFocus(node: nodeId)
                }
                canvasAction.end(continuous: .movePathNode)
                canvasAction.end(triggering: .pathNodeActions)
            },
            onLongPressEnd: { _ in
                guard context.actionWheelNodeId != nil else { return }
                context.actionWheelOption?.onSelect()
                withAnimation { context.actionWheelNodeId = nil }
            },

            onDrag: { updateDrag($0, pending: true) },
            onDragEnd: { updateDrag($0) }
        )
    }

    func actionWheelOptions(context: GestureContext) -> [ActionWheel.Option] {
        [
            .init(name: "Break", imageName: "scissors") {
                guard let path = activeItem.focusedPath,
                      let nodeId = context.nodeId else { return }
                documentUpdater.update(path: .breakAtNode(.init(pathId: path.id, nodeId: nodeId, newPathId: .init(), newNodeId: .init(), offset: .zero)))
            },
            .init(name: "Add", imageName: "plus.square", tintColor: .blue, holdingDuration: 0.5) {
                guard let nodeId = context.nodeId else { return }
                let offset = context.dragOffset.applying(viewport.toWorld)
                start(context: context, .addEndingNode(.init(endingNodeId: nodeId, newNodeId: .init(), offset: offset)))
            },
            .init(name: "Delete", imageName: "trash", tintColor: .red) {
                guard let nodeId = context.nodeId else { return }
                documentUpdater.update(focusedPath: .deleteNodes(.init(nodeIds: [nodeId])))
            },
            .init(name: "Merge Prev", imageName: "arrow.right.to.line", tintColor: .orange) { print("2") },
            .init(name: "Merge Next", imageName: "arrow.left.to.line", tintColor: .green) { print("2") },
        ]
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

        @StateObject private var gestureContext = GestureContext()

        @State private var hoveringOption: ActionWheel.Option?

        var body: some View { trace {
            setupSelector {
                content
            }
        } }
    }
}

// MARK: private

private extension FocusedPathView.NodeHandles {
    @ViewBuilder var content: some View {
        AnimatableReader(selector.viewport) {
            snappedMarks(viewport: $0)
            shapes(nodeType: .corner, viewport: $0)
            shapes(nodeType: .locked, viewport: $0)
            shapes(nodeType: .mirrored, viewport: $0)
            activeMarks(viewport: $0)
            touchables(viewport: $0)
            actionWheel(viewport: $0)
        }
    }

    var circleSize: Scalar { 12 }
    var rectSize: Scalar { circleSize / 2 * 1.7725 } // sqrt of pi
    var touchableSize: Scalar { 40 }

    @ViewBuilder func shapes(nodeType: PathNodeType, viewport: SizedViewportInfo) -> some View {
        SUPath { p in
            guard let path = selector.path else { return }
            let pathProperty = selector.pathProperty,
                selectingNodes = selector.selectingNodes
            for nodeId in path.nodeIds {
                guard pathProperty?.nodeType(id: nodeId) == nodeType,
                      let node = path.node(id: nodeId) else { continue }
                let position = node.position.applying(viewport.worldToView)
                if nodeType == .corner {
                    let size = rectSize * (selectingNodes ? 1.5 : 1)
                    p.addRoundedRect(in: .init(center: position, size: .init(squared: size)), cornerSize: .init(2, 2))
                } else {
                    let size = circleSize * (selectingNodes ? 1.5 : 1)
                    p.addEllipse(in: .init(center: position, size: .init(squared: size)))
                }
            }
        }
        .stroke(.blue, style: StrokeStyle(lineWidth: nodeType == .mirrored ? 2 : 1))
        .fill(.blue.opacity(0.3))
        .allowsHitTesting(false)
    }

    @ViewBuilder func touchables(viewport: SizedViewportInfo) -> some View {
        SUPath { p in
            guard let path = selector.path else { return }
            for nodeId in path.nodeIds {
                guard let node = path.node(id: nodeId) else { continue }
                let position = node.position.applying(viewport.worldToView),
                    size = CGSize(squared: touchableSize)
                p.addRect(.init(center: position, size: size))
            }
        }
        .fill(.blue.opacity(0.1))
        .multipleGesture(global.nodesGesture(context: gestureContext))
    }

    @ViewBuilder func activeMarks(viewport: SizedViewportInfo) -> some View {
        SUPath { p in
            guard let path = selector.path else { return }
            let activeNodeIds = selector.activeNodeIds,
                selectingNodes = selector.selectingNodes
            for nodeId in path.nodeIds {
                guard !selectingNodes,
                      activeNodeIds.contains(nodeId),
                      let node = path.node(id: nodeId) else { continue }
                let position = node.position.applying(viewport.worldToView),
                    size = CGSize(squared: circleSize / 2)
                p.addEllipse(in: .init(center: position, size: size))
            }
        }
        .fill(.blue)
        .allowsHitTesting(false)
    }

    @ViewBuilder func snappedMarks(viewport: SizedViewportInfo) -> some View {
        SUPath { p in
            guard let path = selector.path else { return }
            let activeNodeIds = selector.activeNodeIds,
                selectingNodes = selector.selectingNodes,
                gridStack = selector.gridStack
            for nodeId in path.nodeIds {
                guard !selectingNodes,
                      activeNodeIds.contains(nodeId),
                      let node = path.node(id: nodeId),
                      let grid = gridStack.first(where: { $0.snapped(node.position) }) else { continue }
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

    @ViewBuilder func actionWheel(viewport: SizedViewportInfo) -> some View {
        let path = selector.path,
            nodeId = gestureContext.actionWheelNodeId
        if let path, let nodeId, let node = path.node(id: nodeId) {
            ActionWheel(
                offset: gestureContext.dragOffset,
                options: global.actionWheelOptions(context: gestureContext),
                hovering: .init(gestureContext, \.actionWheelOption)
            )
            .position(node.position.applying(viewport.worldToView))
        }
    }
}
