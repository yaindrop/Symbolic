import SwiftUI

private class GestureContext {
    var nodeId: UUID?
    var controlType: PathBezierControlType = .cubicIn
}

// MARK: - global actions

private extension GlobalStores {
    func controlGesture(context: GestureContext) -> MultipleGesture {
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            guard let nodeId = context.nodeId else { return }
            let controlType = context.controlType,
                offset = v.offset.applying(viewport.toWorld)
            documentUpdater.update(focusedPath: .moveNodeControl(.init(nodeId: nodeId, controlType: controlType, offset: offset)), pending: pending)
        }
        return .init(
            onPress: { info in
                let location = info.location.applying(viewport.toWorld)
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
            cubicIn(viewport: $0)
            cubicOut(viewport: $0)
            quadratic(viewport: $0)
            touchables(viewport: $0)
        }
    }

    var cubicInColor: Color { .orange }
    var cubicOutColor: Color { .green }
    var quadraticColor: Color { .purple }
    var lineWidth: Scalar { 1 }
    var circleSize: Scalar { 8 }
    var touchableSize: Scalar { 32 }

    @ViewBuilder func cubicIn(viewport: SizedViewportInfo) -> some View {
        SUPath { p in
            guard let path = selector.path else { return }
            for nodeId in selector.cubicInNodeIds {
                guard let node = path.node(id: nodeId) else { continue }
                let position = node.position.applying(viewport.worldToView),
                    control = node.positionIn.applying(viewport.worldToView)
                appendLine(to: &p, from: position, to: control)
                appendCircle(to: &p, at: control)
            }
        }
        .stroke(cubicInColor, style: StrokeStyle(lineWidth: lineWidth))
        .fill(cubicInColor.opacity(0.5))
        .allowsHitTesting(false)
    }

    @ViewBuilder func cubicOut(viewport: SizedViewportInfo) -> some View {
        SUPath { p in
            guard let path = selector.path else { return }
            for nodeId in selector.cubicOutNodeIds {
                guard let node = path.node(id: nodeId) else { continue }
                let position = node.position.applying(viewport.worldToView),
                    control = node.positionOut.applying(viewport.worldToView)
                appendLine(to: &p, from: position, to: control)
                appendCircle(to: &p, at: control)
            }
        }
        .stroke(cubicOutColor, style: StrokeStyle(lineWidth: lineWidth))
        .fill(cubicOutColor.opacity(0.5))
        .allowsHitTesting(false)
    }

    @ViewBuilder func quadratic(viewport: SizedViewportInfo) -> some View {
        SUPath { p in
            guard let path = selector.path else { return }
            for nodeId in selector.quadraticFromNodeIds {
                guard let segment = path.segment(fromId: nodeId),
                      let quadratic = segment.quadratic else { continue }
                let from = segment.from.applying(viewport.worldToView),
                    to = segment.to.applying(viewport.worldToView),
                    control = quadratic.applying(viewport.worldToView)
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

    @ViewBuilder func touchables(viewport: SizedViewportInfo) -> some View {
        SUPath { p in
            guard let path = selector.path else { return }
            for nodeId in selector.cubicInNodeIds {
                guard let node = path.node(id: nodeId) else { continue }
                let control = node.positionIn.applying(viewport.worldToView)
                appendTouchableRect(to: &p, at: control)
            }
            for nodeId in selector.cubicOutNodeIds {
                guard let node = path.node(id: nodeId) else { continue }
                let control = node.positionOut.applying(viewport.worldToView)
                appendTouchableRect(to: &p, at: control)
            }
            for nodeId in selector.quadraticFromNodeIds {
                guard let segment = path.segment(fromId: nodeId),
                      let quadratic = segment.quadratic else { continue }
                let control = quadratic.applying(viewport.worldToView)
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
