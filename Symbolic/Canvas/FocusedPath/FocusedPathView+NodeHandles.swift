import SwiftUI

private class GestureContext: ObservableObject {
    enum PendingAction {
        case moveNodes(PathAction.Update.MoveNodes)
        case addEndingNode(PathAction.Update.AddEndingNode)
        case moveNodeControl(PathAction.Update.MoveNodeControl)
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
        case var .moveNodeControl(action):
            action.offset = offset ?? action.offset
            documentUpdater.update(focusedPath: .moveNodeControl(action), pending: pending)
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

        func showActionWheel() {
            withAnimation { context.actionWheelNodeId = context.nodeId }
            if let nodeId = context.nodeId {
                focusedPath.setFocus(node: nodeId)
            }
        }

        func commitActionWheel() {
            guard context.actionWheelNodeId != nil else { return }
            context.actionWheelOption?.onPressEnd()
            withAnimation { context.actionWheelNodeId = nil }
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
                if focusedPath.selectingNodes {
                    canvasAction.start(triggering: .pathSelect)
                } else {
                    canvasAction.start(triggering: .pathNodeActions)
                }
            },
            onPressEnd: { _, cancelled in
                contextMenu.setHidden(false)
                context.nodeId = nil
                if cancelled { documentUpdater.cancel() }
                canvasAction.end(triggering: .pathNodeActions)
                canvasAction.end(continuous: .movePathNode)
                canvasAction.end(continuous: .addAndMoveEndingNode)
                canvasAction.end(continuous: .movePathBezierControl)
            },

            onTap: { _ in
                guard let nodeId = context.nodeId else { return }
                focusedPath.onTap(node: nodeId)
            },

            onLongPress: { _ in
                if focusedPath.selectingNodes {
                    canvasAction.end(triggering: .pathSelect)
                } else {
                    showActionWheel()
                    canvasAction.end(continuous: .movePathNode)
                    canvasAction.end(triggering: .pathNodeActions)
                }
            },
            onLongPressEnd: { _ in commitActionWheel() },

            onDrag: {
                updateDrag($0, pending: true)
                canvasAction.end(triggering: .pathNodeActions)
            },
            onDragEnd: { updateDrag($0) }
        )
    }

    func actionWheelOptions(context: GestureContext) -> [ActionWheel.Option] {
        guard let path = activeItem.focusedPath,
              let pathProperty = activeItem.focusedPathProperty,
              let nodeId = context.nodeId,
              let node = path.node(id: nodeId) else { return [] }

        let isEndingNode = path.isEndingNode(id: nodeId),
            prevId = path.nodeId(before: nodeId),
            prevSegment = prevId.map { path.segment(fromId: $0) },
            prevSegmentType = prevSegment.map { pathProperty.segmentType(id: prevId!).activeType(segment: $0) },
            hasCubicIn = prevSegmentType == .cubic,
            segment = path.segment(fromId: nodeId),
            segmentType = segment.map { pathProperty.segmentType(id: nodeId).activeType(segment: $0) },
            hasCubicOut = segmentType == .cubic

        return [
            .init(name: "Delete", imageName: "trash", tintColor: .red) {
                guard let nodeId = context.actionWheelNodeId else { return }
                documentUpdater.update(focusedPath: .deleteNodes(.init(nodeIds: [nodeId])))
            },
            isEndingNode ?
                .init(name: "Add", imageName: "plus.square", holdingDuration: 0.3) {
                    guard let nodeId = context.actionWheelNodeId else { return }
                    let offset = context.dragOffset.applying(viewport.toWorld)
                    start(context: context, action: .addEndingNode(.init(endingNodeId: nodeId, newNodeId: .init(), offset: offset)))
                    canvasAction.start(continuous: .addAndMoveEndingNode)
                } :
                .init(name: "Break", imageName: "scissors") {
                    guard let nodeId = context.actionWheelNodeId else { return }
                    documentUpdater.update(focusedPath: .breakAtNode(.init(nodeId: nodeId, newPathId: .init(), newNodeId: .init())))
                },
            node.cubicIn == .zero ?
                .init(name: "Move Cubic In", imageName: "arrow.left.to.line", disabled: !hasCubicIn, tintColor: .orange, holdingDuration: 0.3) {
                    guard let nodeId = context.actionWheelNodeId else { return }
                    let offset = context.dragOffset.applying(viewport.toWorld)
                    start(context: context, action: .moveNodeControl(.init(nodeId: nodeId, controlType: .cubicIn, offset: offset)))
                    canvasAction.start(continuous: .movePathBezierControl)
                } :
                .init(name: "Reset Cubic In", imageName: "circle.slash", disabled: !hasCubicIn, tintColor: .orange) {
                    guard let nodeId = context.actionWheelNodeId else { return }
                    var node = node
                    node.cubicIn = .zero
                    documentUpdater.update(focusedPath: .updateNode(.init(nodeId: nodeId, node: node)))
                },
            node.cubicOut == .zero ?
                .init(name: "Move Cubic Out", imageName: "arrow.right.to.line", disabled: !hasCubicOut, tintColor: .green, holdingDuration: 0.3) {
                    guard let nodeId = context.actionWheelNodeId else { return }
                    let offset = context.dragOffset.applying(viewport.toWorld)
                    start(context: context, action: .moveNodeControl(.init(nodeId: nodeId, controlType: .cubicOut, offset: offset)))
                    canvasAction.start(continuous: .movePathBezierControl)
                } :
                .init(name: "Reset Cubic Out", imageName: "circle.slash", disabled: !hasCubicOut, tintColor: .green) {
                    guard let nodeId = context.actionWheelNodeId else { return }
                    var node = node
                    node.cubicOut = .zero
                    documentUpdater.update(focusedPath: .updateNode(.init(nodeId: nodeId, node: node)))
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

    @ViewBuilder func indexMarks(viewport: SizedViewportInfo) -> some View {
        Canvas { ctx, _ in
            guard let path = selector.path else { return }
            for index in path.nodes.indices {
                guard let node = path.node(at: index) else { continue }
                let text = Text("\(index)").font(.system(size: 8)).foregroundStyle(.blue),
                    resolved = ctx.resolve(text),
                    size = resolved.measure(in: .init(squared: touchableSize)),
                    position = node.position.applying(viewport.worldToView) - Vector2(circleSize + size.width + 4, 0) / 2
                ctx.draw(resolved, in: .init(center: position, size: size))
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
