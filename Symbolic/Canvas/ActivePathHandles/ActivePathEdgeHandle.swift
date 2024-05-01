import Foundation
import SwiftUI

// MARK: - ActivePathEdgeHandle

struct ActivePathEdgeHandle: View {
    let fromId: UUID
    let segment: PathSegment

    var body: some View {
        outline
    }

    @State private var isLongPressDown = false

    @EnvironmentObject private var activePathModel: ActivePathModel

    private var focused: Bool { activePathModel.focusedEdgeId == fromId }
    private func toggleFocus() {
        activePathModel.focusedPart = focused ? nil : .edge(fromId)
    }

    @ViewBuilder private var outline: some View {
        SUPath { p in segment.append(to: &p) }
            .strokedPath(StrokeStyle(lineWidth: 24, lineCap: .round))
            .fill(Color.invisibleSolid)
            .modifier(TapDragPress())
    }
}

// MARK: - ActivePathFocusedEdgeHandle

struct ActivePathFocusedEdgeHandle: View {
    let fromId: UUID
    let segment: PathSegment

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

    private var focused: Bool { activePathModel.focusedEdgeId == fromId }

    private var circlePosition: Point2? { segment.position(paramT: 0.5) }

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
        func update(pending: Bool = false) -> (DragGesture.Value, Point2) -> Void {
            { value, origin in updater.updateActivePath(moveEdge: fromId, offsetInView: origin.deltaVector(to: value.location), pending: pending) }
        }
        return DragGestureWithContext(origin, onChanged: update(pending: true), onEnded: update())
    }
}
