import Foundation
import SwiftUI

fileprivate let subtracer = tracer.tagged("PathView")

extension PathView {
    // MARK: - EdgeKindHandle

    struct EdgeKindHandle: View {
        let fromId: UUID
        let toId: UUID
        let segment: PathSegment
        let focusedPart: PathFocusedPart?

        var body: some View { subtracer.range("EdgeKindHandle") { build {
            BezierHandle(fromId: fromId, toId: toId, segment: segment, focusedPart: focusedPart)
        }}}
    }

    // MARK: - BezierHandle

    struct BezierHandle: View, EquatableBy {
        @EnvironmentObject var viewModel: PathViewModel

        let fromId: UUID
        let toId: UUID
        let segment: PathSegment
        let focusedPart: PathFocusedPart?

        var nodeFocused: Bool { focusedPart?.nodeId == fromId }
        var edgeFocused: Bool { focusedPart?.edgeId == fromId }
        var nextFocused: Bool { focusedPart?.nodeId == toId }

        var equatableBy: some Equatable { fromId; toId; segment; nodeFocused; edgeFocused; nextFocused }

        var body: some View {
            ZStack {
                if edgeFocused || nodeFocused {
                    line(from: segment.from, to: segment.control0, color: .green)
                    circle(at: segment.control0, color: .green)
                        .if(gesture0) {
                            $0.multipleGesture($1, ())
                        }
                        .onAppear {
                            gesture0 = viewModel.bezierGesture(fromId: fromId, isControl0: true)
                        }
                }
                if edgeFocused || nextFocused {
                    line(from: segment.to, to: segment.control1, color: .orange)
                    circle(at: segment.control1, color: .orange)
                        .if(gesture1) {
                            $0.multipleGesture($1, ())
                        }
                        .onAppear {
                            gesture1 = viewModel.bezierGesture(fromId: fromId, isControl0: false)
                        }
                }
            }
        }

        // MARK: private

        private static let lineWidth: Scalar = 1
        private static let circleSize: Scalar = 12
        private static let touchablePadding: Scalar = 12

        @State private var gesture0: MultipleGestureModel<Void>?
        @State private var gesture1: MultipleGestureModel<Void>?

        private func subtractingCircle(at point: Point2) -> SUPath {
            SUPath { $0.addEllipse(in: CGRect(center: point, size: CGSize(squared: Self.circleSize))) }
        }

        @ViewBuilder private func line(from: Point2, to: Point2, color: Color) -> some View {
            SUPath { p in
                p.move(to: from)
                p.addLine(to: to)
                p = p.strokedPath(StrokeStyle(lineWidth: Self.lineWidth))
                p = p.subtracting(subtractingCircle(at: to))
            }
            .fill(color.opacity(0.5))
            .allowsHitTesting(false)
        }

        @ViewBuilder private func circle(at point: Point2, color: Color) -> some View {
            Circle()
                .stroke(color, style: StrokeStyle(lineWidth: Self.lineWidth))
                .fill(color.opacity(0.5))
                .frame(width: Self.circleSize, height: Self.circleSize)
                .padding(Self.touchablePadding)
                .invisibleSoildOverlay()
                .position(point)
        }
    }
}