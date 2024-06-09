import SwiftUI

// MARK: - EdgeHandle

extension PathView {
    struct EdgeHandle: View, TracedView, EquatableBy, ComputedSelectorHolder {
        @EnvironmentObject var viewModel: PathViewModel

        let pathId: UUID
        let fromNodeId: UUID

        var equatableBy: some Equatable { pathId; fromNodeId }

        struct SelectorProps: Equatable { let pathId: UUID, fromNodeId: UUID }
        class Selector: SelectorBase {
            override var syncUpdate: Bool { true }
            @Selected({ global.path.path(id: $0.pathId)?.segment(from: $0.fromNodeId)?.applying(global.viewport.toView) }) var segment
        }

        @SelectorWrapper var selector

        @State private var edgeGestureContext = PathViewModel.EdgeGestureContext()

        var body: some View { trace {
            setupSelector(.init(pathId: pathId, fromNodeId: fromNodeId)) {
                content
            }
        } }
    }
}

// MARK: private

private extension PathView.EdgeHandle {
    @ViewBuilder var content: some View {
        if let segment = selector.segment {
            SUPath { p in segment.append(to: &p) }
                .strokedPath(StrokeStyle(lineWidth: 24, lineCap: .round))
                .fill(Color.invisibleSolid)
                .multipleGesture(viewModel.edgeGesture(fromId: fromNodeId, segment: segment, context: edgeGestureContext))
        }
    }

    var circleSize: Scalar { 16 }
    var lineWidth: Scalar { 2 }

    @ViewBuilder func circle(at point: Point2, color: Color) -> some View {
        Circle()
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth))
            .fill(color)
            .frame(size: .init(squared: circleSize))
            .invisibleSoildOverlay()
            .position(point)
    }
}

// MARK: - FocusedEdgeHandle

extension PathView {
    struct FocusedEdgeHandle: View, TracedView, EquatableBy, ComputedSelectorHolder {
        @EnvironmentObject var viewModel: PathViewModel

        let pathId: UUID
        let fromNodeId: UUID

        var equatableBy: some Equatable { pathId; fromNodeId }

        struct SelectorProps: Equatable { let pathId: UUID, fromNodeId: UUID }
        class Selector: SelectorBase {
            override var syncUpdate: Bool { true }
            @Selected({ global.path.path(id: $0.pathId)?.segment(from: $0.fromNodeId)?.applying(global.viewport.toView) }) var segment
            @Selected({ global.focusedPath.focusedSegmentId == $0.fromNodeId }) var focused
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

private extension PathView.FocusedEdgeHandle {
    var color: Color { .cyan }
    var lineWidth: Scalar { 1 }
    var circleSize: Scalar { 12 }
    var touchablePadding: Scalar { 24 }

    var circlePosition: Point2? {
        guard let segment = selector.segment else { return nil }
        let tessellated = segment.tessellated()
        let t = tessellated.approxPathParamT(lineParamT: 0.5).t
        return segment.position(paramT: t)
    }

    func subtractingCircle(at point: Point2) -> SUPath {
        SUPath { $0.addEllipse(in: .init(center: point, size: .init(squared: circleSize))) }
    }

    @ViewBuilder var content: some View {
        if let circlePosition, selector.focused {
            Circle()
                .stroke(color, style: .init(lineWidth: lineWidth))
                .fill(color.opacity(0.5))
                .frame(size: .init(squared: circleSize))
                .padding(touchablePadding)
                .invisibleSoildOverlay()
                .position(circlePosition)
                .if(selector.focused) { $0.overlay {
                    if let segment = selector.segment {
                        SUPath { p in
                            let tessellated = segment.tessellated()
                            let fromT = tessellated.approxPathParamT(lineParamT: 0.1).t
                            let toT = tessellated.approxPathParamT(lineParamT: 0.9).t
                            segment.subsegment(fromT: fromT, toT: toT).append(to: &p)
                        }
                        .strokedPath(StrokeStyle(lineWidth: 2, lineCap: .round))
                        .subtracting(subtractingCircle(at: circlePosition))
                        .fill(color)
                        .allowsHitTesting(false)
                    }
                }}
                .multipleGesture(viewModel.focusedEdgeGesture(fromId: fromNodeId))
        }
    }
}
