import Foundation
import SwiftUI

// MARK: - ActivePathEdgeHandle

struct ActivePathEdgeHandle: View {
    let segment: PathSegment
    let data: PathSegmentData

    var body: some View {
        outline
    }

    @EnvironmentObject private var activePathModel: ActivePathModel

    private var segmentId: UUID { segment.id }

    private var focused: Bool { activePathModel.focusedEdgeId == segmentId }
    private func toggleFocus() {
        activePathModel.focusedPart = focused ? nil : .edge(segmentId)
    }

    @ViewBuilder private var outline: some View {
        if let nextNode = data.nextNode {
            SUPath { p in
                p.move(to: data.node)
                data.edge.draw(path: &p, to: nextNode)
            }
            .strokedPath(StrokeStyle(lineWidth: 24, lineCap: .round))
            .fill(Color.invisibleSolid)
            .onTapGesture {
                toggleFocus()
            }
        }
    }
}

// MARK: - ActivePathFocusedEdgeHandle

struct ActivePathFocusedEdgeHandle: View {
    let segment: PathSegment
    let data: PathSegmentData

    var body: some View {
        if let circlePosition, focused {
            circle(at: circlePosition, color: .teal)
        }
    }

    private static let lineWidth: CGFloat = 2
    private static let circleSize: CGFloat = 16
    private static let touchablePadding: CGFloat = 16

    @EnvironmentObject private var activePathModel: ActivePathModel
    @EnvironmentObject private var updater: PathUpdater

    private var segmentId: UUID { segment.id }

    private var focused: Bool { activePathModel.focusedEdgeId == segmentId }

    private var circlePosition: Point2? {
        if let nextNode = data.nextNode {
            data.edge.position(from: data.node, to: nextNode, at: 0.5)
        } else {
            nil
        }
    }

    @ViewBuilder private func circle(at point: Point2, color: Color) -> some View {
        Circle()
            .stroke(color, style: StrokeStyle(lineWidth: Self.lineWidth))
            .fill(color.opacity(0.5))
            .frame(width: Self.circleSize, height: Self.circleSize)
            .padding(Self.touchablePadding)
            .invisibleSoildOverlay()
            .position(point)
            .modifier(drag(origin: point))
    }

    private func drag(origin: Point2) -> DragGestureWithContext<Point2> {
        DragGestureWithContext(origin) { value, origin in
            updater.updateActivePath(aroundEdge: segmentId, offsetInView: origin.deltaVector(to: value.location), pending: true)
        } onEnded: { value, origin in
            updater.updateActivePath(aroundEdge: segmentId, offsetInView: origin.deltaVector(to: value.location))
        }
    }
}
