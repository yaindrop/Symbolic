import Foundation
import SwiftUI

extension PathView {
    // MARK: - EdgeHandle

    struct EdgeHandle: View, EquatableBy {
        @EnvironmentObject var viewModel: PathViewModel

        let fromId: UUID
        let segment: PathSegment
        let focusedPart: PathFocusedPart?

        var focused: Bool { focusedPart?.edgeId == fromId }

        var equatableBy: some Equatable { fromId; segment; focused }

        var body: some View { tracer.range("PathView EdgeHandle") {
            outline
            //        if let longPressPosition {
            //            circle(at: p, color: .teal)
            //        }
        }}

        @State private var gesture: MultipleGestureModel<PathSegment>?
        @State private var gestureContext: PathViewModel.EdgeGestureContext?

        @ViewBuilder private var outline: some View {
            SUPath { p in segment.append(to: &p) }
                .strokedPath(StrokeStyle(lineWidth: 24, lineCap: .round))
                .fill(Color.invisibleSolid)
                .if(gesture) {
                    $0.multipleGesture($1, segment)
                }
                .onAppear {
                    let pair = viewModel.edgeGesture(fromId: fromId)
                    gesture = pair?.0
                    gestureContext = pair?.1
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

    // MARK: - FocusedEdgeHandle

    struct FocusedEdgeHandle: View, EquatableBy {
        @EnvironmentObject var viewModel: PathViewModel

        let fromId: UUID
        let segment: PathSegment
        let focusedPart: PathFocusedPart?

        var focused: Bool { focusedPart?.edgeId == fromId }

        var equatableBy: some Equatable { fromId; segment; focused }

        var body: some View {
            if let circlePosition, focused {
                circle(at: circlePosition, color: .cyan)
            }
        }

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

        @State private var gesture: MultipleGestureModel<Point2>?

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
                .if(gesture) {
                    $0.multipleGesture($1, point)
                }
                .onAppear {
                    gesture = viewModel.focusedEdgeGesture(fromId: fromId)
                }
        }
    }
}
