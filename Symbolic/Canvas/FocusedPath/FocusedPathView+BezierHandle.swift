import SwiftUI

private class GestureContext {
    var nodeId: UUID?
    var isControlOut: Bool = false
}

// MARK: - global actions

private extension GlobalStores {
    func controlGesture(context: GestureContext) -> MultipleGesture {
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            guard let nodeId = context.nodeId else { return }
            let isControlOut = context.isControlOut
            let (controlOutOffset, controlInOffset) = isControlOut ? (v.offset, .zero) : (.zero, v.offset)
//            if isControlOut { draggingOut = pending } else { draggingIn = pending }
            documentUpdater.updateInView(focusedPath: .moveNodeControl(.init(nodeId: nodeId, controlInOffset: controlInOffset, controlOutOffset: controlOutOffset)), pending: pending)
        }
        return .init(
            onPress: { info in
                let location = info.location.applying(viewport.toWorld)
                guard let (nodeId, isControlOut) = focusedPath.controlNodeId(closestTo: location) else { return }
                context.nodeId = nodeId
                context.isControlOut = isControlOut
                canvasAction.start(continuous: .movePathBezierControl)
            },
            onPressEnd: { _, cancelled in
                context.nodeId = nil
                canvasAction.end(continuous: .movePathBezierControl)
                if cancelled { documentUpdater.cancel() }
            },
            onDrag: { updateDrag($0, pending: true) },
            onDragEnd: { updateDrag($0) }
        )
    }
}

// MARK: - BezierHandles

extension FocusedPathView {
    struct BezierHandles: View, TracedView, SelectorHolder {
        class Selector: SelectorBase {
            @Selected(configs: .init(syncNotify: true), { global.viewport.sizedInfo }) var viewport
            @Selected(configs: .init(syncNotify: true), { global.activeItem.focusedPath }) var path
            @Selected({ global.activeItem.focusedPathProperty }) var pathProperty
            @Selected({ global.focusedPath.controlInNodeIds }) var controlInNodeIds
            @Selected({ global.focusedPath.controlOutNodeIds }) var controlOutNodeIds
        }

        @SelectorWrapper var selector

        @State private var gestureContext = GestureContext()

        @State private var draggingIn = false
        @State private var draggingOut = false

        var body: some View { trace {
            setupSelector {
                content
            }
        } }
    }
}

// MARK: private

private extension FocusedPathView.BezierHandles {
    @ViewBuilder var content: some View {
        AnimatableReader(selector.viewport) {
            controlOut(viewport: $0)
            controlIn(viewport: $0)
            touchables(viewport: $0)
        }
    }

    var controlOutColor: Color { .green }
    var controlInColor: Color { .orange }
    var lineWidth: Scalar { 1 }
    var circleSize: Scalar { 8 }
    var touchableSize: Scalar { 32 }

    @ViewBuilder func controlIn(viewport: SizedViewportInfo) -> some View {
        SUPath { p in
            guard let path = selector.path else { return }
            for nodeId in selector.controlInNodeIds {
                guard let node = path.node(id: nodeId) else { continue }
                let position = node.position.applying(viewport.worldToView),
                    positionIn = node.positionIn.applying(viewport.worldToView)
                appendLine(to: &p, from: position, to: positionIn)
                appendCircle(to: &p, at: positionIn)
            }
        }
        .stroke(controlInColor, style: StrokeStyle(lineWidth: lineWidth))
        .fill(controlInColor.opacity(0.5))
        .allowsHitTesting(false)
    }

    @ViewBuilder func controlOut(viewport: SizedViewportInfo) -> some View {
        SUPath { p in
            guard let path = selector.path else { return }
            for nodeId in selector.controlOutNodeIds {
                guard let node = path.node(id: nodeId) else { continue }
                let position = node.position.applying(viewport.worldToView),
                    positionOut = node.positionOut.applying(viewport.worldToView)
                appendLine(to: &p, from: position, to: positionOut)
                appendCircle(to: &p, at: positionOut)
            }
        }
        .stroke(controlOutColor, style: StrokeStyle(lineWidth: lineWidth))
        .fill(controlOutColor.opacity(0.5))
        .allowsHitTesting(false)
    }

    func appendLine(to path: inout SUPath, from: Point2, to: Point2) {
        var delta = to - from
        delta = delta.with(length: delta.length - circleSize / 2)
        path.move(to: from)
        path.addLine(to: from + delta)
    }

    func appendCircle(to path: inout SUPath, at point: Point2) {
        path.addEllipse(in: .init(center: point, size: .init(squared: circleSize)))
    }

    @ViewBuilder func touchables(viewport: SizedViewportInfo) -> some View {
        SUPath { p in
            guard let path = selector.path else { return }
            for nodeId in selector.controlOutNodeIds {
                guard let node = path.node(id: nodeId) else { continue }
                let position = node.positionOut.applying(viewport.worldToView)
                appendTouchableRect(to: &p, at: position)
            }
            for nodeId in selector.controlInNodeIds {
                guard let node = path.node(id: nodeId) else { continue }
                let position = node.positionIn.applying(viewport.worldToView)
                appendTouchableRect(to: &p, at: position)
            }
        }
        .fill(debugFocusedPath ? .red.opacity(0.1) : .clear)
        .multipleGesture(global.controlGesture(context: gestureContext))
    }

    func appendTouchableRect(to path: inout SUPath, at point: Point2) {
        path.addRect(.init(center: point, size: .init(squared: touchableSize)))
    }
}
