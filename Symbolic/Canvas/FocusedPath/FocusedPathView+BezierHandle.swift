import SwiftUI

// MARK: - BezierHandle

extension FocusedPathView {
    struct BezierHandle: View, TracedView, EquatableBy, ComputedSelectorHolder {
        let pathId: UUID, fromNodeId: UUID

        var equatableBy: some Equatable { pathId; fromNodeId }

        struct SelectorProps: Equatable { let pathId: UUID, fromNodeId: UUID }
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Formula({ global.path.get(id: $0.pathId) }) static var path
            @Formula({ global.pathProperty.get(id: $0.pathId) }) static var property
            @Formula({ path($0)?.node(after: $0.fromNodeId)?.id }) static var nextNodeId

            @Selected({ global.viewport.sizedInfo }) var viewport
            @Selected({ path($0)?.segment(from: $0.fromNodeId) }) var segment
            @Selected({ global.focusedPath.focusedSegmentId == $0.fromNodeId }) var segmentFocused
            @Selected({ global.focusedPath.focusedNodeId == $0.fromNodeId }) var nodeFocused
            @Selected({ global.focusedPath.focusedNodeId == nextNodeId($0) }) var nextFocused
            @Selected({ property($0)?.edgeType(id: $0.fromNodeId) }) var edgeType
        }

        @SelectorWrapper var selector

        @State private var dragging0 = false
        @State private var dragging1 = false

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

    @ViewBuilder var content: some View {
        if let segment = selector.segment {
            AnimatableReader(selector.viewport) {
                let segment = segment.applying($0.worldToView)
                ZStack {
                    control0(segment: segment)
                    control1(segment: segment)
                }
            }
        }
    }

    func showControl0(segment: PathSegment) -> Bool {
        let focused = selector.segmentFocused || selector.nodeFocused
        let valid = selector.edgeType == .cubic || (selector.edgeType == .auto && segment.edge.control0 != .zero)
        return dragging0 || focused && valid
    }

    @ViewBuilder func control0(segment: PathSegment) -> some View {
        if showControl0(segment: segment) {
            line(from: segment.from, to: segment.control0, color: control0Color)
            circle(at: segment.control0, color: control0Color)
                .multipleGesture(bezierGesture(isControl0: true))
        }
    }

    func showControl1(segment: PathSegment) -> Bool {
        let focused = selector.segmentFocused || selector.nextFocused
        let valid = selector.edgeType == .cubic || (selector.edgeType == .auto && segment.edge.control1 != .zero)
        return dragging1 || focused && valid
    }

    @ViewBuilder func control1(segment: PathSegment) -> some View {
        if showControl1(segment: segment) {
            line(from: segment.to, to: segment.control1, color: control1Color)
            circle(at: segment.control1, color: control1Color)
                .multipleGesture(bezierGesture(isControl0: false))
        }
    }

    func bezierGesture(isControl0: Bool) -> MultipleGesture {
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            let offset0 = isControl0 ? v.offset : .zero
            let offset1 = isControl0 ? .zero : v.offset
            if isControl0 { dragging0 = pending } else { dragging1 = pending }
            global.documentUpdater.updateInView(focusedPath: .moveEdgeControl(.init(fromNodeId: fromNodeId, offset0: offset0, offset1: offset1)), pending: pending)
        }
        return .init(
            onPress: { global.canvasAction.start(continuous: .movePathBezierControl) },
            onPressEnd: { cancelled in
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
