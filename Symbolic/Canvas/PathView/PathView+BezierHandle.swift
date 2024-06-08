import Foundation
import SwiftUI

// MARK: - BezierHandle

extension PathView {
    struct BezierHandle: View, TracedView, EquatableBy, ComputedSelectorHolder {
        struct SelectorProps: Equatable { let pathId: UUID, fromNodeId: UUID }
        class Selector: SelectorBase {
            override var syncUpdate: Bool { true }

            @Selected({ global.path.path(id: $0.pathId)?.segment(from: $0.fromNodeId)?.applying(global.viewport.toView) }) var segment
            @Selected({ global.focusedPath.focusedNodeId == $0.fromNodeId }) var nodeFocused
            @Selected({ global.focusedPath.focusedSegmentId == $0.fromNodeId }) var segmentFocused
            @Selected({ global.focusedPath.focusedNodeId == global.path.path(id: $0.pathId)?.node(after: $0.fromNodeId)?.id }) var nextFocused
        }

        @SelectorWrapper var selector

        @EnvironmentObject var viewModel: PathViewModel

        let pathId: UUID
        let fromNodeId: UUID

        var equatableBy: some Equatable { pathId; fromNodeId }

        var body: some View { trace {
            setupSelector(.init(pathId: pathId, fromNodeId: fromNodeId)) {
                content
            }
        } }

        // MARK: private

        private static let lineWidth: Scalar = 1
        private static let circleSize: Scalar = 8
        private static let touchablePadding: Scalar = 16

        private var content: some View {
            ZStack {
                control0
                control1
            }
        }

        @ViewBuilder private var control0: some View {
            if let segment = selector.segment {
                if selector.segmentFocused || selector.nodeFocused {
                    line(from: segment.from, to: segment.control0, color: .green)
                    circle(at: segment.control0, color: .green)
                        .multipleGesture(viewModel.bezierGesture(fromId: fromNodeId, isControl0: true))
                }
            }
        }

        @ViewBuilder private var control1: some View {
            if let segment = selector.segment {
                if selector.segmentFocused || selector.nextFocused {
                    line(from: segment.to, to: segment.control1, color: .orange)
                    circle(at: segment.control1, color: .orange)
                        .multipleGesture(viewModel.bezierGesture(fromId: fromNodeId, isControl0: false))
                }
            }
        }

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
