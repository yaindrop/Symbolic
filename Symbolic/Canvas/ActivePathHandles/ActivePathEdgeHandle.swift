import Foundation
import SwiftUI

// MARK: - ActivePathEdgeHandle

struct ActivePathEdgeHandle: View {
    let fromId: UUID
    let segment: PathSegment

    var body: some View {
        outline
        if let longPressPosition {
            let t = segment.paramT(closestTo: longPressPosition).t
            let p = segment.position(paramT: t)
            circle(at: p, color: .teal)
            SUPath {
                $0.move(to: longPressPosition)
                $0.addLine(to: p)
            }.stroke(.red)
        }
    }

    @State private var longPressPosition: Point2?

    @EnvironmentObject private var activePathModel: ActivePathModel

    private var focused: Bool { activePathModel.focusedEdgeId == fromId }
    private func toggleFocus() {
        activePathModel.focusedPart = focused ? nil : .edge(fromId)
    }

    @ViewBuilder private var outline: some View {
        SUPath { p in segment.append(to: &p) }
            .strokedPath(StrokeStyle(lineWidth: 24, lineCap: .round))
            .fill(Color.invisibleSolid)
            .modifier(MultipleGestureModifier((),
                                              onTap: { _, _ in toggleFocus() },
                                              onLongPress: { v, _ in longPressPosition = v.location },
                                              onLongPressEnd: { _, _ in longPressPosition = nil },
                                              onDrag: { v, _ in if longPressPosition != nil { longPressPosition = v.location }}))
    }

    private static let circleSize: CGFloat = 16
    private static let lineWidth: CGFloat = 2

    @ViewBuilder private func circle(at point: Point2, color: Color) -> some View {
        Circle()
            .stroke(color, style: StrokeStyle(lineWidth: Self.lineWidth))
            .fill(color.opacity(0.5))
            .frame(width: Self.circleSize, height: Self.circleSize)
            .invisibleSoildOverlay()
            .position(point)
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

    private var circlePosition: Point2? { segment.tessellated().position(paramT: 0.5) }

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

    private func drag(origin: Point2) -> MultipleGestureModifier<Point2> {
        func update(pending: Bool = false) -> (DragGesture.Value, Point2) -> Void {
            { value, origin in updater.updateActivePath(moveEdge: fromId, offsetInView: origin.deltaVector(to: value.location), pending: pending) }
        }
        return MultipleGestureModifier(origin, onDrag: update(pending: true), onDragEnd: update())
    }
}
