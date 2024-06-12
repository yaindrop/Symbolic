import SwiftUI

private extension GlobalStore {
    func bezierGesture(fromId: UUID, isControl0: Bool) -> MultipleGesture {
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            let offset0 = isControl0 ? v.offset : .zero
            let offset1 = isControl0 ? .zero : v.offset
            documentUpdater.updateInView(focusedPath: .moveEdgeControl(.init(fromNodeId: fromId, offset0: offset0, offset1: offset1)), pending: pending)
        }
        return .init(
            onPress: { canvasAction.start(continuous: .movePathBezierControl) },
            onPressEnd: { cancelled in
                canvasAction.end(continuous: .movePathBezierControl)
                if cancelled { documentUpdater.cancel() }
            },
            onDrag: { updateDrag($0, pending: true) },
            onDragEnd: { updateDrag($0) }
        )
    }
}

// MARK: - BezierHandle

extension FocusedPathView {
    struct BezierHandle: View, TracedView, EquatableBy, ComputedSelectorHolder {
        let pathId: UUID, fromNodeId: UUID

        var equatableBy: some Equatable { pathId; fromNodeId }

        struct SelectorProps: Equatable { let pathId: UUID, fromNodeId: UUID }
        class Selector: SelectorBase {
            override var syncUpdate: Bool { true }
            @Formula({ global.path.get(id: $0.pathId) }) static var path
            @Formula({ global.pathProperty.get(id: $0.pathId) }) static var property
            @Formula({ path($0)?.node(after: $0.fromNodeId)?.id }) static var nextNodeId
            @Selected({ path($0)?.segment(from: $0.fromNodeId)?.applying(global.viewport.toView) }) var segment
            @Selected({ global.focusedPath.focusedSegmentId == $0.fromNodeId }) var segmentFocused
            @Selected({ global.focusedPath.focusedNodeId == $0.fromNodeId }) var nodeFocused
            @Selected({ global.focusedPath.focusedNodeId == nextNodeId($0) }) var nextFocused
            @Selected({ property($0)?.edgeType(id: $0.fromNodeId) }) var edgeType
        }

        @SelectorWrapper var selector

        var body: some View { trace {
            setupSelector(.init(pathId: pathId, fromNodeId: fromNodeId)) {
                content
            }
        } }
    }
}

// MARK: private

private extension FocusedPathView.BezierHandle {
    var control0Color: Color { .green }
    var control1Color: Color { .orange }
    var lineWidth: Scalar { 1 }
    var circleSize: Scalar { 8 }
    var touchablePadding: Scalar { 16 }

    var content: some View {
        ZStack {
            control0
            control1
        }
    }

    var showControl0: Bool {
        guard let segment = selector.segment else { return false }
        let focused = selector.segmentFocused || selector.nodeFocused
        let valid = selector.edgeType == .cubic || (selector.edgeType == .auto && segment.edge.control0 != .zero)
        return focused && valid
    }

    @ViewBuilder var control0: some View {
        if let segment = selector.segment, showControl0 {
            line(from: segment.from, to: segment.control0, color: control0Color)
            circle(at: segment.control0, color: control0Color)
                .multipleGesture(global.bezierGesture(fromId: fromNodeId, isControl0: true))
        }
    }

    var showControl1: Bool {
        guard let segment = selector.segment else { return false }
        let focused = selector.segmentFocused || selector.nextFocused
        let valid = selector.edgeType == .cubic || (selector.edgeType == .auto && segment.edge.control1 != .zero)
        return focused && valid
    }

    @ViewBuilder var control1: some View {
        if let segment = selector.segment, showControl1 {
            line(from: segment.to, to: segment.control1, color: control1Color)
            circle(at: segment.control1, color: control1Color)
                .multipleGesture(global.bezierGesture(fromId: fromNodeId, isControl0: false))
        }
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
