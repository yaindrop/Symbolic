import Foundation
import SwiftUI

private let subtracer = tracer.tagged("PathView")

// MARK: - BezierHandle

extension PathView {
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
                        .multipleGesture(viewModel.bezierGesture(fromId: fromId, isControl0: true))
                }
                if edgeFocused || nextFocused {
                    line(from: segment.to, to: segment.control1, color: .orange)
                    circle(at: segment.control1, color: .orange)
                        .multipleGesture(viewModel.bezierGesture(fromId: fromId, isControl0: false))
                }
            }
        }

        // MARK: private

        private static let lineWidth: Scalar = 1
        private static let circleSize: Scalar = 12
        private static let touchablePadding: Scalar = 12

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
