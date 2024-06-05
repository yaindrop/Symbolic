import Foundation
import SwiftUI

private let subtracer = tracer.tagged("PathView")

// MARK: - EdgeHandle

extension PathView {
    struct EdgeHandle: View, EquatableBy {
        @EnvironmentObject var viewModel: PathViewModel

        let property: PathProperty
        let focusedPart: PathFocusedPart?

        let fromId: UUID
        let segment: PathSegment

        var focused: Bool { focusedPart?.edgeId == fromId }

        var equatableBy: some Equatable { fromId; segment; focused }

        var body: some View { subtracer.range("EdgeHandle") {
            outline
        }}

        @State private var edgeGestureContext = PathViewModel.EdgeGestureContext()

        @ViewBuilder private var outline: some View {
            SUPath { p in segment.append(to: &p) }
                .strokedPath(StrokeStyle(lineWidth: 24, lineCap: .round))
                .fill(Color.invisibleSolid)
                .multipleGesture(viewModel.edgeGesture(fromId: fromId, segment: segment, context: edgeGestureContext))
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
    struct FocusedEdgeHandle: View, EquatableBy {
        @EnvironmentObject var viewModel: PathViewModel

        let property: PathProperty
        let focusedPart: PathFocusedPart?

        let fromId: UUID
        let segment: PathSegment

        var focused: Bool { focusedPart?.edgeId == fromId }

        var equatableBy: some Equatable { fromId; segment; focused }

        var body: some View { subtracer.range("FocusedEdgeHandle") { build {
            if let circlePosition, focused {
                circle(at: circlePosition, color: .cyan)
            }
        }}}

        private static let lineWidth: Scalar = 2
        private static let circleSize: Scalar = 16
        private static let touchablePadding: Scalar = 16

        private var circlePosition: Point2? {
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
                .if(focused) { $0.overlay {
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
                }}
                .multipleGesture(viewModel.focusedEdgeGesture(fromId: fromId))
        }
    }
}
