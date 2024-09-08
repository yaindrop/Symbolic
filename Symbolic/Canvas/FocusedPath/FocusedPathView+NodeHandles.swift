import SwiftUI

private class GestureContext: ObservableObject {
    enum PendingAction {
        case moveNodes(PathAction.Update.MoveNodes)
        case addEndingNode(PathAction.Update.AddEndingNode)
        case moveNodeControl(PathAction.Update.MoveNodeControl)
    }

    struct PendingSelection {
        var originActiveNodeIds: Set<UUID>
    }

    struct PendingActionWheel {
        var nodeId: UUID
        var offset: Vector2
        var option: ActionWheel.Option?
    }

    var nodeId: UUID?
    var pendingAction: PendingAction?
    var pendingSelection: PendingSelection?
    @Published var pendingActionWheel: PendingActionWheel?

    var pendingActionWheelOption: ActionWheel.Option? { get { pendingActionWheel?.option } set { pendingActionWheel?.option = newValue }}

    func setup(_ nodeId: UUID) {
        self.nodeId = nodeId
        pendingAction = nil
        pendingActionWheel = nil
        pendingSelection = nil
    }
}

// MARK: - global actions

private extension GlobalStores {
    func start(context: GestureContext, action: GestureContext.PendingAction) {
        context.pendingActionWheel = nil
        context.pendingAction = action
        update(action: action, pending: true)
    }

    func update(action: GestureContext.PendingAction, offset: Vector2? = nil, pending: Bool = false) {
        switch action {
        case var .moveNodes(action):
            offset.map { action.offset = $0 }
            documentUpdater.update(focusedPath: .moveNodes(action), pending: pending)
        case var .addEndingNode(action):
            offset.map { action.offset = $0 }
            documentUpdater.update(focusedPath: .addEndingNode(action), pending: pending)
        case var .moveNodeControl(action):
            offset.map { action.offset = $0 }
            documentUpdater.update(focusedPath: .moveNodeControl(action), pending: pending)
        }
    }

    func nodesGesture(context: GestureContext) -> MultipleGesture {
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            let offset = v.offset.applying(activeSymbol.viewToSymbol)
            dragActionWheel(v)
            dragPendingSelection(offset: offset)
            guard context.pendingSelection == nil,
                  context.pendingActionWheel == nil else { return }
            if let action = context.pendingAction {
                update(action: action, offset: offset, pending: pending)
            } else {
                guard let nodeId = context.nodeId else { return }
                let multiDrag = focusedPath.selectingNodes && focusedPath.activeNodeIds.contains(nodeId)
                let nodeIds = multiDrag ? .init(focusedPath.activeNodeIds) : [nodeId]
                start(context: context, action: .moveNodes(.init(nodeIds: nodeIds, offset: offset)))
            }
        }

        func startPendingSelection() {
            context.pendingSelection = .init(originActiveNodeIds: focusedPath.activeNodeIds)
        }

        func dragPendingSelection(offset: Vector2) {
            guard let nodeId = context.nodeId else { return }
            if let pendingSelection = context.pendingSelection {
                focusedPath.selection(activeNodeIds: pendingSelection.originActiveNodeIds, dragFrom: nodeId, offset: offset)
            }
        }

        func startActionWheel() {
            guard let nodeId = context.nodeId else { return }
            withAnimation { context.pendingActionWheel = .init(nodeId: nodeId, offset: .zero) }
            if let nodeId = context.nodeId {
                focusedPath.setFocus(node: nodeId)
            }
        }

        func dragActionWheel(_ v: DragGesture.Value) {
            context.pendingActionWheel?.offset = v.offset
        }

        func endActionWheel() {
            guard let pendingActionWheel = context.pendingActionWheel else { return }
            pendingActionWheel.option?.onPressEnd()
            withAnimation { context.pendingActionWheel = nil }
        }

        return .init(
            configs: .init(durationThreshold: 0.2),
            onPress: { info in
                contextMenu.setHidden(true)
                let location = info.location.applying(activeSymbol.viewToSymbol)
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
                    startPendingSelection()
                    canvasAction.end(triggering: .pathSelect)
                } else {
                    startActionWheel()
                    canvasAction.end(triggering: .pathNodeActions)
                }
                canvasAction.end(continuous: .movePathNode)
            },
            onLongPressEnd: { _ in endActionWheel() },

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

        var offset: Vector2? { context.pendingActionWheel?.offset.applying(activeSymbol.viewToSymbol) }
        return [
            .init(name: "Delete", imageName: "trash", tintColor: .red) {
                documentUpdater.update(focusedPath: .deleteNodes(.init(nodeIds: [nodeId])))
            },
            isEndingNode ?
                .init(name: "Add", imageName: "plus.square", holdingDuration: 0.3) {
                    guard let offset else { return }
                    start(context: context, action: .addEndingNode(.init(endingNodeId: nodeId, newNodeId: .init(), offset: offset)))
                    canvasAction.start(continuous: .addAndMoveEndingNode)
                } :
                .init(name: "Break", imageName: "scissors") {
                    documentUpdater.update(focusedPath: .split(.init(nodeId: nodeId, newPathId: .init(), newNodeId: .init())))
                },
            node.cubicIn == .zero ?
                .init(name: "Move Cubic In", imageName: "arrow.left.to.line", disabled: !hasCubicIn, tintColor: .orange, holdingDuration: 0.3) {
                    guard let offset else { return }
                    start(context: context, action: .moveNodeControl(.init(nodeId: nodeId, controlType: .cubicIn, offset: offset)))
                    canvasAction.start(continuous: .movePathBezierControl)
                } :
                .init(name: "Reset Cubic In", imageName: "circle.slash", disabled: !hasCubicIn, tintColor: .orange) {
                    var node = node
                    node.cubicIn = .zero
                    documentUpdater.update(focusedPath: .updateNode(.init(nodeId: nodeId, node: node)))
                },
            node.cubicOut == .zero ?
                .init(name: "Move Cubic Out", imageName: "arrow.right.to.line", disabled: !hasCubicOut, tintColor: .green, holdingDuration: 0.3) {
                    guard let offset else { return }
                    start(context: context, action: .moveNodeControl(.init(nodeId: nodeId, controlType: .cubicOut, offset: offset)))
                    canvasAction.start(continuous: .movePathBezierControl)
                } :
                .init(name: "Reset Cubic Out", imageName: "circle.slash", disabled: !hasCubicOut, tintColor: .green) {
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
        @Environment(\.transformToView) var transformToView

        struct SelectorProps: Equatable { let pathId: UUID, nodeId: UUID }
        class Selector: SelectorBase {
            @Selected({ global.activeItem.focusedPath }, .syncNotify) var path
            @Selected({ global.focusedPath.activeNodeIds }) var activeNodeIds
            @Selected({ global.focusedPath.selectingNodes }, .animation(.faster)) var selectingNodes
            @Selected({ global.activeSymbol.editingSymbol?.grids }) var grids
            @Selected({ global.activeItem.focusedPathProperty }) var pathProperty
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
        indexMarks
        snappedMarks
        shapes(nodeType: .corner)
        shapes(nodeType: .locked)
        shapes(nodeType: .mirrored)
        activeMarks
        touchables
        actionWheel
    }

    var circleSize: Scalar { 12 }
    var rectSize: Scalar { circleSize / 2 * 1.7725 } // sqrt of pi
    var touchableSize: Scalar { 40 }

    @ViewBuilder var indexMarks: some View {
        Canvas { ctx, _ in
            guard let path = selector.path else { return }
            for index in path.nodes.indices {
                guard let node = path.node(at: index) else { continue }
                let text = Text("\(index)").font(.system(size: 8)).foregroundStyle(.blue),
                    resolved = ctx.resolve(text),
                    size = resolved.measure(in: .init(squared: touchableSize)),
                    position = node.position.applying(transformToView) - Vector2(circleSize + size.width + 4, 0) / 2
                ctx.draw(resolved, in: .init(center: position, size: size))
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder func shapes(nodeType: PathNodeType) -> some View {
        SUPath { p in
            guard let path = selector.path else { return }
            let pathProperty = selector.pathProperty,
                selectingNodes = selector.selectingNodes
            for nodeId in path.nodeIds {
                guard pathProperty?.nodeType(id: nodeId) == nodeType,
                      let node = path.node(id: nodeId) else { continue }
                let position = node.position.applying(transformToView)
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

    @ViewBuilder var touchables: some View {
        SUPath { p in
            guard let path = selector.path else { return }
            for nodeId in path.nodeIds {
                guard let node = path.node(id: nodeId) else { continue }
                let position = node.position.applying(transformToView),
                    size = CGSize(squared: touchableSize)
                p.addRect(.init(center: position, size: size))
            }
        }
        .fill(debugFocusedPath ? .blue.opacity(0.1) : .invisibleSolid)
        .multipleGesture(global.nodesGesture(context: gestureContext))
    }

    @ViewBuilder var activeMarks: some View {
        SUPath { p in
            guard let path = selector.path else { return }
            let activeNodeIds = selector.activeNodeIds,
                selectingNodes = selector.selectingNodes
            for nodeId in path.nodeIds {
                guard !selectingNodes,
                      activeNodeIds.contains(nodeId),
                      let node = path.node(id: nodeId) else { continue }
                let position = node.position.applying(transformToView),
                    size = CGSize(squared: circleSize / 2)
                p.addEllipse(in: .init(center: position, size: size))
            }
        }
        .fill(.blue)
        .allowsHitTesting(false)
    }

    @ViewBuilder var snappedMarks: some View {
        SUPath { p in
            guard let path = selector.path,
                  let grids = selector.grids else { return }
            let activeNodeIds = selector.activeNodeIds,
                selectingNodes = selector.selectingNodes
            for nodeId in path.nodeIds {
                guard !selectingNodes,
                      activeNodeIds.contains(nodeId),
                      let node = path.node(id: nodeId),
                      let grid = grids.first(where: { $0.snapped(node.position) }) else { continue }
                let position = node.position.applying(transformToView)
                p.move(to: position - .init(9, 0))
                p.addLine(to: position + .init(9, 0))
                p.move(to: position - .init(0, 9))
                p.addLine(to: position + .init(0, 9))
            }
        }
        .stroke(.blue.opacity(0.5))
        .allowsHitTesting(false)
    }

    @ViewBuilder var actionWheel: some View {
        if let pendingActionWheel = gestureContext.pendingActionWheel, let path = selector.path, let node = path.node(id: pendingActionWheel.nodeId) {
            ActionWheel(
                offset: pendingActionWheel.offset,
                options: global.actionWheelOptions(context: gestureContext),
                hovering: .init(gestureContext, \.pendingActionWheelOption)
            )
            .position(node.position.applying(transformToView))
        }
    }
}
