import SwiftUI

private class GestureContext: ObservableObject {
    enum PendingAction {
        case moveNodes(PathAction.Update.MoveNodes)
        case addEndingNode(PathAction.Update.AddEndingNode)
    }

    var nodeId: UUID?

    @Published var dragOffset: Vector2 = .zero
    var pendingAction: PendingAction?

    @Published var actionWheelNodeId: UUID?
    var actionWheelOption: ActionWheel.Option?

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
    func start(context: GestureContext, action: GestureContext.PendingAction) {
        context.actionWheelNodeId = nil
        context.pendingAction = action
        update(action: action, pending: true)
    }

    func update(action: GestureContext.PendingAction, offset: Vector2? = nil, pending: Bool = false) {
        switch action {
        case var .moveNodes(action):
            action.offset = offset ?? action.offset
            documentUpdater.update(focusedPath: .moveNodes(action), pending: pending)
        case var .addEndingNode(action):
            action.offset = offset ?? action.offset
            documentUpdater.update(focusedPath: .addEndingNode(action), pending: pending)
        }
    }

    func nodesGesture(context: GestureContext) -> MultipleGesture {
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            context.dragOffset = v.offset
            guard context.actionWheelNodeId == nil else { return }
            let offset = v.offset.applying(viewport.toWorld)
            if let action = context.pendingAction {
                update(action: action, offset: offset, pending: pending)
            } else {
                guard let nodeId = context.nodeId else { return }
                let multiDrag = focusedPath.selectingNodes && focusedPath.activeNodeIds.contains(nodeId)
                let nodeIds = multiDrag ? .init(focusedPath.activeNodeIds) : [nodeId]
                start(context: context, action: .moveNodes(.init(nodeIds: nodeIds, offset: offset)))
            }
        }

        return .init(
            configs: .init(durationThreshold: 0.2),
            onPress: { info in
                contextMenu.setHidden(true)
                let location = info.location.applying(viewport.toWorld)
                guard let path = activeItem.focusedPath,
                      let nodeId = path.nodeId(closestTo: location) else { return }
                context.setup(nodeId)
                canvasAction.start(continuous: .movePathNode)
                canvasAction.start(triggering: .pathNodeActions)
            },
            onPressEnd: { _, cancelled in
                contextMenu.setHidden(false)
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
                contextMenu.setHidden(false)
                context.actionWheelOption?.onPressEnd()
                withAnimation { context.actionWheelNodeId = nil }
            },

            onDrag: { updateDrag($0, pending: true) },
            onDragEnd: { updateDrag($0) }
        )
    }

    func actionWheelOptions(context: GestureContext) -> [ActionWheel.Option] {
        var nodeId: UUID? { context.actionWheelNodeId }
        var isEndingNode: Bool {
            guard let nodeId = context.nodeId,
                  let path = activeItem.focusedPath else { return false }
            return path.isEndingNode(id: nodeId)
        }
        var hasPrev: Bool {
            guard let nodeId = context.nodeId,
                  let path = activeItem.focusedPath else { return false }
            return path.nodeId(before: nodeId) != nil
        }
        var hasNext: Bool {
            guard let nodeId = context.nodeId,
                  let path = activeItem.focusedPath else { return false }
            return path.nodeId(after: nodeId) != nil
        }
        return [
            .init(name: "Delete", imageName: "trash", tintColor: .red) {
                guard let nodeId else { return }
                documentUpdater.update(focusedPath: .deleteNodes(.init(nodeIds: [nodeId])))
            },
            isEndingNode ?
                .init(name: "Add", imageName: "plus.square", holdingDuration: 0.5) {
                    guard let nodeId else { return }
                    let offset = context.dragOffset.applying(viewport.toWorld)
                    start(context: context, action: .addEndingNode(.init(endingNodeId: nodeId, newNodeId: .init(), offset: offset)))
                } :
                .init(name: "Break", imageName: "scissors") {
                    guard let nodeId else { return }
                    documentUpdater.update(focusedPath: .breakAtNode(.init(nodeId: nodeId, newPathId: .init(), newNodeId: .init())))
                },
            .init(name: "Combine Prev", imageName: "arrow.right.to.line", disabled: !hasPrev, tintColor: .orange) {
                guard let nodeId else { return }
                documentUpdater.update(focusedPath: .combineNode(.init(nodeId: nodeId, isNext: false)))
            },
            .init(name: "Combine Next", imageName: "arrow.left.to.line", disabled: !hasNext, tintColor: .green) {
                guard let nodeId else { return }
                documentUpdater.update(focusedPath: .combineNode(.init(nodeId: nodeId, isNext: true)))
            },
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
            indexMarks(viewport: $0)
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
    var textSize: Scalar { 16 }

    @ViewBuilder func indexMarks(viewport: SizedViewportInfo) -> some View {
        Canvas { ctx, _ in
            guard let path = selector.path else { return }
            for index in path.nodes.indices {
                guard let node = path.node(at: index) else { continue }
                let position = node.position.applying(viewport.worldToView) - Vector2(textSize / 2, textSize / 2),
                    size = CGSize(squared: textSize),
                    text = Text("\(index)").font(.system(size: 8)).foregroundStyle(.blue)
                ctx.draw(ctx.resolve(text), in: .init(center: position, size: size))
            }
        }
        .allowsHitTesting(false)
    }

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
