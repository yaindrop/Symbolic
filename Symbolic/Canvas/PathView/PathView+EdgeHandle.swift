import Foundation
import SwiftUI

private let subtracer = tracer.tagged("PathView")

// MARK: - EdgeHandle

extension PathView {
    struct EdgeHandle: View, EquatableBy, ComputedSelectorHolder {
        struct SelectorProps: Equatable { let pathId: UUID, fromNodeId: UUID }
        class Selector: SelectorBase {
            override var syncUpdate: Bool { true }

            @Selected({ global.path.path(id: $0.pathId)?.segment(from: $0.fromNodeId)?.applying(global.viewport.toView) }) var segment
        }

        @SelectorWrapper var selector

        @EnvironmentObject var viewModel: PathViewModel

        let pathId: UUID
        let fromNodeId: UUID

        var equatableBy: some Equatable { pathId; fromNodeId }

        var body: some View { subtracer.range("EdgeHandle") {
            setupSelector(.init(pathId: pathId, fromNodeId: fromNodeId)) {
                outline
            }
        }}

        @State private var edgeGestureContext = PathViewModel.EdgeGestureContext()

        @ViewBuilder private var outline: some View {
            if let segment = selector.segment {
                SUPath { p in segment.append(to: &p) }
                    .strokedPath(StrokeStyle(lineWidth: 24, lineCap: .round))
                    .fill(Color.invisibleSolid)
                    .multipleGesture(viewModel.edgeGesture(fromId: fromNodeId, segment: segment, context: edgeGestureContext))
            }
        }

        private static let circleSize: Scalar = 16
        private static let lineWidth: Scalar = 2

        @ViewBuilder private func circle(at point: Point2, color: Color) -> some View {
            Circle()
                .stroke(color, style: StrokeStyle(lineWidth: Self.lineWidth))
                .fill(color)
                .frame(width: Self.circleSize, height: Self.circleSize)
                .invisibleSoildOverlay()
                .position(point)
        }
    }
}

// MARK: - FocusedEdgeHandle

extension PathView {
    struct FocusedEdgeHandle: View, EquatableBy, ComputedSelectorHolder {
        struct SelectorProps: Equatable { let pathId: UUID, fromNodeId: UUID }
        class Selector: SelectorBase {
            override var syncUpdate: Bool { true }

            @Selected({ global.path.path(id: $0.pathId)?.segment(from: $0.fromNodeId)?.applying(global.viewport.toView) }) var segment
            @Selected({ global.activeItem.pathFocusedPart?.edgeId == $0.fromNodeId }) var focused
        }

        @SelectorWrapper var selector

        @EnvironmentObject var viewModel: PathViewModel

        let pathId: UUID
        let fromNodeId: UUID

        var equatableBy: some Equatable { pathId; fromNodeId }

        var body: some View { subtracer.range("FocusedEdgeHandle") {
            setupSelector(.init(pathId: pathId, fromNodeId: fromNodeId)) {
                if let circlePosition, selector.focused {
                    circle(at: circlePosition, color: .cyan)
                }
            }
        }}

        private static let lineWidth: Scalar = 2
        private static let circleSize: Scalar = 16
        private static let touchablePadding: Scalar = 16

        private var circlePosition: Point2? {
            guard let segment = selector.segment else { return nil }
            let tessellated = segment.tessellated()
            let t = tessellated.approxPathParamT(lineParamT: 0.5).t
            return segment.position(paramT: t)
        }

        private func subtractingCircle(at point: Point2) -> SUPath {
            SUPath { $0.addEllipse(in: CGRect(center: point, size: CGSize(squared: Self.circleSize))) }
        }

        @ViewBuilder private func circle(at point: Point2, color: Color) -> some View {
            Circle()
                .stroke(color, style: StrokeStyle(lineWidth: Self.lineWidth))
                .fill(color.opacity(0.5))
                .frame(width: Self.circleSize, height: Self.circleSize)
                .padding(Self.touchablePadding)
                .invisibleSoildOverlay()
                .position(point)
                .if(selector.focused) { $0.overlay {
                    if let segment = selector.segment {
                        SUPath { p in
                            let tessellated = segment.tessellated()
                            let fromT = tessellated.approxPathParamT(lineParamT: 0.1).t
                            let toT = tessellated.approxPathParamT(lineParamT: 0.9).t
                            segment.subsegment(fromT: fromT, toT: toT).append(to: &p)
                        }
                        .strokedPath(StrokeStyle(lineWidth: 2, lineCap: .round))
                        .subtracting(subtractingCircle(at: point))
                        .fill(color)
                        .allowsHitTesting(false)
                    }
                }}
                .multipleGesture(viewModel.focusedEdgeGesture(fromId: fromNodeId))
        }
    }
}
