import SwiftUI

// MARK: - global actions

private extension GlobalStores {}

// MARK: - BezierHandle

extension FocusedPathView {
    struct BezierHandle: View, TracedView, EquatableBy, ComputedSelectorHolder {
        @ObservedObject var env: FocusedPathView.Selector
        let pathId: UUID, nodeId: UUID

        var equatableBy: some Equatable { pathId; nodeId }

        struct SelectorProps: Equatable { let pathId: UUID, nodeId: UUID }
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Formula({ global.path.get(id: $0.pathId) }) static var path
            @Formula({ global.pathProperty.get(id: $0.pathId) }) static var property
            @Formula({ path($0)?.nodeId(before: $0.nodeId) }) static var prevNodeId

            @Selected({ path($0)?.node(id: $0.nodeId) }) var node
            @Selected({ global.focusedPath.focusedNodeId == $0.nodeId }) var nodeFocused
            @Selected({ global.focusedPath.focusedSegmentId == $0.nodeId }) var segmentFocused
            @Selected({ global.focusedPath.focusedSegmentId == prevNodeId($0) }) var prevSegmentFocused
            @Selected({ property($0)?.segmentType(id: $0.nodeId) }) var segmentType
            @Selected({ props in prevNodeId(props).map { property(props)?.segmentType(id: $0) } }) var prevSegmentType
        }

        @SelectorWrapper var selector

        @State private var draggingOut = false
        @State private var draggingIn = false

        var body: some View { trace {
            setupSelector(.init(pathId: pathId, nodeId: nodeId)) {
                content
            }
        } }
    }
}

// MARK: private

private extension FocusedPathView.BezierHandle {
    var controlOutColor: Color { .green }
    var controlInColor: Color { .orange }
    var lineWidth: Scalar { 1 }
    var circleSize: Scalar { 8 }
    var touchablePadding: Scalar { 16 }

    @ViewBuilder var content: some View {
        let showControlOut = showControlOut
        let showControlIn = showControlIn
        if let node = selector.node, showControlOut || showControlIn {
            AnimatableReader(env.viewport) {
                let node = node.applying($0.worldToView)
                ZStack {
                    controlOut(node: node)
                        .opacity(showControlOut ? 1 : 0)
                    controlIn(node: node)
                        .opacity(showControlIn ? 1 : 0)
                }
            }
        }
    }

    var showControlOut: Bool {
        guard let node = selector.node else { return false }
        let segmentType = selector.segmentType
        let focused = selector.segmentFocused || selector.nodeFocused
        let valid = segmentType == .cubic || (segmentType == .auto && node.controlOut != .zero)
        return draggingOut || focused && valid
    }

    var showControlIn: Bool {
        guard let node = selector.node else { return false }
        let segmentType = selector.prevSegmentType
        let focused = selector.prevSegmentFocused || selector.nodeFocused
        let valid = segmentType == .cubic || (segmentType == .auto && node.controlIn != .zero)
        return draggingIn || focused && valid
    }

    @ViewBuilder func controlOut(node: PathNode) -> some View {
        line(from: node.position, to: node.positionOut, color: controlOutColor)
        circle(at: node.positionOut, color: controlOutColor)
            .multipleGesture(bezierGesture(isControlOut: true))
    }

    @ViewBuilder func controlIn(node: PathNode) -> some View {
        line(from: node.position, to: node.positionIn, color: controlInColor)
        circle(at: node.positionIn, color: controlInColor)
            .multipleGesture(bezierGesture(isControlOut: false))
    }

    func bezierGesture(isControlOut: Bool) -> MultipleGesture {
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            let (controlOutOffset, controlInOffset) = isControlOut ? (v.offset, .zero) : (.zero, v.offset)
            if isControlOut { draggingOut = pending } else { draggingIn = pending }
            global.documentUpdater.updateInView(focusedPath: .moveNodeControl(.init(nodeId: nodeId, controlInOffset: controlInOffset, controlOutOffset: controlOutOffset)), pending: pending)
        }
        return .init(
            onPress: { _ in global.canvasAction.start(continuous: .movePathBezierControl) },
            onPressEnd: { _, cancelled in
                global.canvasAction.end(continuous: .movePathBezierControl)
                if cancelled { global.documentUpdater.cancel() }
            },
            onDrag: { updateDrag($0, pending: true) },
            onDragEnd: { updateDrag($0) }
        )
    }

    func subtractingCircle(at point: Point2) -> SUPath {
        SUPath { $0.addEllipse(in: CGRect(center: point, size: CGSize(squared: circleSize))) }
    }

    @ViewBuilder func line(from: Point2, to: Point2, color: Color) -> some View {
        SUPath { p in
            p.move(to: from)
            p.addLine(to: to)
            p = p.strokedPath(StrokeStyle(lineWidth: lineWidth))
            p = p.subtracting(subtractingCircle(at: to))
        }
        .fill(color.opacity(0.5))
        .allowsHitTesting(false)
    }

    @ViewBuilder func circle(at point: Point2, color: Color) -> some View {
        Circle()
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth))
            .fill(color.opacity(0.5))
            .frame(size: .init(squared: circleSize))
            .padding(touchablePadding)
            .invisibleSoildOverlay()
            .position(point)
    }
}

extension FocusedPathView {
    struct BezierHandles: View, TracedView, SelectorHolder {
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Selected({ global.activeItem.focusedPath }) var path
            @Selected({ global.activeItem.focusedPathProperty }) var pathProperty
            @Selected({ global.focusedPath.focusedNodeId }) var focusedNodeId
            @Selected({ global.focusedPath.focusedSegmentId }) var focusedSegmentId
        }

        @SelectorWrapper var selector

        @State private var draggingIn = false
        @State private var draggingOut = false

        var body: some View { trace {
            setupSelector {
                content
            }
        } }
    }
}

private extension FocusedPathView.BezierHandles {
    @ViewBuilder var content: some View {
        EmptyView()
//        let showControlOut = showControlOut
//        let showControlIn = showControlIn
//        if let node = selector.node, showControlOut || showControlIn {
//            AnimatableReader(env.viewport) {
//                let node = node.applying($0.worldToView)
//                ZStack {
//                    controlOut(node: node)
//                        .opacity(showControlOut ? 1 : 0)
//                    controlIn(node: node)
//                        .opacity(showControlIn ? 1 : 0)
//                }
//            }
//        }
    }

    var controlOutColor: Color { .green }
    var controlInColor: Color { .orange }
    var lineWidth: Scalar { 1 }
    var circleSize: Scalar { 8 }
    var touchablePadding: Scalar { 16 }

    func showControlIn(nodeId: UUID) -> Bool {
        guard let prevId = selector.path?.nodeId(before: nodeId),
              let segmentType = selector.pathProperty?.segmentType(id: prevId),
              let node = selector.path?.node(id: nodeId) else { return false }
        let focused = selector.focusedSegmentId == prevId || selector.focusedNodeId == nodeId
        let valid = segmentType == .cubic || (segmentType == .auto && node.controlIn != .zero)
        return draggingIn || focused && valid
    }

    var controlIn: some View {
        EmptyView()
//        SUPath {
//            for a in
//        }
    }

    func appendLine(to path: inout SUPath, from: Point2, to: Point2, color _: Color) {
        var delta = to - from
        delta = delta.with(length: delta.length - circleSize / 2)
        path.move(to: from)
        path.addLine(to: from + delta)
    }

    func appendCircle(to path: inout SUPath, at point: Point2, color _: Color) {
        path.addEllipse(in: .init(center: point, size: .init(squared: circleSize)))
    }
}
