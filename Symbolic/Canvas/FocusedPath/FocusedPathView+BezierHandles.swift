import SwiftUI

private class GestureContext {
    var nodeId: UUID?
    var controlType: PathNodeControlType = .cubicIn
}

// MARK: - global actions

private extension GlobalStores {
    func controlGesture(context: GestureContext) -> MultipleGesture {
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            guard let nodeId = context.nodeId else { return }
            let controlType = context.controlType,
                offset = v.offset.applying(viewport.viewToWorld)
            documentUpdater.update(focusedPath: .moveNodeControl(.init(nodeId: nodeId, controlType: controlType, offset: offset)), pending: pending)
        }
        return .init(
            onPress: { info in
                let location = info.location.applying(viewport.viewToWorld)
                guard let (nodeId, controlType) = focusedPath.controlNodeId(closestTo: location) else { return }
                context.nodeId = nodeId
                context.controlType = controlType
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
            @Selected({ global.focusedPath.cubicInNodeIds }) var cubicInNodeIds
            @Selected({ global.focusedPath.cubicOutNodeIds }) var cubicOutNodeIds
            @Selected({ global.focusedPath.quadraticFromNodeIds }) var quadraticFromNodeIds
            @Selected({ global.activeSymbol.symbolToWorld }) var symbolToWorld
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

// MARK: private

private extension FocusedPathView.BezierHandles {
    @ViewBuilder var content: some View {
        AnimatableReader(selector.viewport) {
            let transform = selector.symbolToWorld.concatenating($0.worldToView)
            cubicIn(transform: transform)
            cubicOut(transform: transform)
            quadratic(transform: transform)
            touchables(transform: transform)
        }
    }

    var cubicInColor: Color { .orange }
    var cubicOutColor: Color { .green }
    var quadraticColor: Color { .purple }
    var lineWidth: Scalar { 1 }
    var circleSize: Scalar { 8 }
    var touchableSize: Scalar { 32 }

    @ViewBuilder func cubicIn(transform: CGAffineTransform) -> some View {
        SUPath { p in
            guard let path = selector.path else { return }
            for nodeId in selector.cubicInNodeIds {
                guard let node = path.node(id: nodeId) else { continue }
                let position = node.position.applying(transform),
                    control = node.positionIn.applying(transform)
                appendLine(to: &p, from: position, to: control)
                appendCircle(to: &p, at: control)
            }
        }
        .stroke(cubicInColor, style: StrokeStyle(lineWidth: lineWidth))
        .fill(cubicInColor.opacity(0.5))
        .allowsHitTesting(false)
    }

    @ViewBuilder func cubicOut(transform: CGAffineTransform) -> some View {
        SUPath { p in
            guard let path = selector.path else { return }
            for nodeId in selector.cubicOutNodeIds {
                guard let node = path.node(id: nodeId) else { continue }
                let position = node.position.applying(transform),
                    control = node.positionOut.applying(transform)
                appendLine(to: &p, from: position, to: control)
                appendCircle(to: &p, at: control)
            }
        }
        .stroke(cubicOutColor, style: StrokeStyle(lineWidth: lineWidth))
        .fill(cubicOutColor.opacity(0.5))
        .allowsHitTesting(false)
    }

    @ViewBuilder func quadratic(transform: CGAffineTransform) -> some View {
        SUPath { p in
            guard let path = selector.path else { return }
            for nodeId in selector.quadraticFromNodeIds {
                guard let segment = path.segment(fromId: nodeId),
                      let quadratic = segment.quadratic else { continue }
                let from = segment.from.applying(transform),
                    to = segment.to.applying(transform),
                    control = quadratic.applying(transform)
                appendLine(to: &p, from: from, to: control)
                appendLine(to: &p, from: to, to: control)
                appendCircle(to: &p, at: control)
            }
        }
        .stroke(quadraticColor, style: StrokeStyle(lineWidth: lineWidth))
        .fill(quadraticColor.opacity(0.5))
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

    @ViewBuilder func touchables(transform: CGAffineTransform) -> some View {
        SUPath { p in
            guard let path = selector.path else { return }
            for nodeId in selector.cubicInNodeIds {
                guard let node = path.node(id: nodeId) else { continue }
                let control = node.positionIn.applying(transform)
                appendTouchableRect(to: &p, at: control)
            }
            for nodeId in selector.cubicOutNodeIds {
                guard let node = path.node(id: nodeId) else { continue }
                let control = node.positionOut.applying(transform)
                appendTouchableRect(to: &p, at: control)
            }
            for nodeId in selector.quadraticFromNodeIds {
                guard let segment = path.segment(fromId: nodeId),
                      let quadratic = segment.quadratic else { continue }
                let control = quadratic.applying(transform)
                appendTouchableRect(to: &p, at: control)
            }
        }
        .fill(debugFocusedPath ? .red.opacity(0.1) : .clear)
        .multipleGesture(global.controlGesture(context: gestureContext))
    }

    func appendTouchableRect(to path: inout SUPath, at point: Point2) {
        path.addRect(.init(center: point, size: .init(squared: touchableSize)))
    }
}
