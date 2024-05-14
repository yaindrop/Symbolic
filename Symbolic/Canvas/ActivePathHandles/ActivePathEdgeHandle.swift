import Foundation
import SwiftUI

// MARK: - ActivePathEdgeHandle

struct ActivePathEdgeHandle: View, EnableActivePathInteractor, EnablePathUpdaterInView {
    @EnvironmentObject var viewport: ViewportModel
    @EnvironmentObject var pathModel: PathModel
    @EnvironmentObject var pendingPathModel: PendingPathModel
    @EnvironmentObject var activePathModel: ActivePathModel
    @EnvironmentObject var pathUpdateModel: PathUpdateModel

    let fromId: UUID
    let segment: PathSegment

    var body: some View { tracer.range("ActivePathEdgeHandle body") {
        outline
        //        if let longPressPosition {
        //            circle(at: p, color: .teal)
        //        }
    }}

    @State private var longPressParamT: Scalar?
    @State private var longPressSplitNodeId: UUID?

    private var focused: Bool { activePathInteractor.focusedEdgeId == fromId }
    private func toggleFocus() {
        focused ? activePathInteractor.clearFocus() : activePathInteractor.setFocus(edge: fromId)
    }

    @StateObject private var multipleGesture = MultipleGestureModel<PathSegment>()

    @ViewBuilder private var outline: some View {
        SUPath { p in segment.append(to: &p) }
            .strokedPath(StrokeStyle(lineWidth: 24, lineCap: .round))
            .fill(Color.invisibleSolid)
            .multipleGesture(multipleGesture, segment) {
                func split(at paramT: Scalar) {
                    longPressParamT = paramT
                    let id = UUID()
                    longPressSplitNodeId = id
                    activePathInteractor.setFocus(node: id)
                }
                func moveSplitNode(to p: Point2, pending: Bool = false) {
                    guard let longPressParamT, let longPressSplitNodeId else { return }
                    pathUpdaterInView.updateActivePath(splitSegment: fromId, paramT: longPressParamT, newNodeId: longPressSplitNodeId, position: p, pending: pending)
                    if !pending {
                        self.longPressParamT = nil
                    }
                }
                func updateDrag(pending: Bool = false) -> (DragGesture.Value, Any) -> Void {
                    { v, _ in
                        if longPressSplitNodeId == nil {
                            pathUpdaterInView.updateActivePath(moveByOffset: Vector2(v.translation), pending: pending)
                        } else {
                            moveSplitNode(to: v.location, pending: pending)
                        }
                    }
                }
                func updateLongPress(segment: PathSegment, pending: Bool = false) {
                    guard let longPressParamT else { return }
                    moveSplitNode(to: segment.position(paramT: longPressParamT), pending: pending)
                }
                $0.onTap { _, _ in toggleFocus() }
                $0.onLongPress { v, s in
                    split(at: s.paramT(closestTo: v.location).t)
                    updateLongPress(segment: s, pending: true)
                }
                $0.onLongPressEnd { _, s in updateLongPress(segment: s) }
                $0.onDrag(updateDrag(pending: true))
                $0.onDragEnd(updateDrag())
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

// MARK: - ActivePathFocusedEdgeHandle

struct ActivePathFocusedEdgeHandle: View, EnableActivePathInteractor, EnablePathUpdaterInView {
    @EnvironmentObject var viewport: ViewportModel
    @EnvironmentObject var pathModel: PathModel
    @EnvironmentObject var pendingPathModel: PendingPathModel
    @EnvironmentObject var activePathModel: ActivePathModel
    @EnvironmentObject var pathUpdateModel: PathUpdateModel

    let fromId: UUID
    let segment: PathSegment

    var body: some View {
        if let circlePosition, focused {
            circle(at: circlePosition, color: .cyan)
        }
    }

    private static let lineWidth: Scalar = 2
    private static let circleSize: Scalar = 16
    private static let touchablePadding: Scalar = 16

    private var focused: Bool { activePathInteractor.focusedEdgeId == fromId }

    private var circlePosition: Point2? {
        let tessellated = segment.tessellated()
        let t = tessellated.approxPathParamT(lineParamT: 0.5).t
        return segment.position(paramT: t)
    }

    private func subtractingCircle(at point: Point2) -> SUPath {
        SUPath { $0.addEllipse(in: CGRect(center: point, size: CGSize(squared: Self.circleSize))) }
    }

    @StateObject private var dragGesture = MultipleGestureModel<Point2>()

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
            .multipleGesture(dragGesture, point) {
                func update(pending: Bool = false) -> (DragGesture.Value, Point2) -> Void {
                    { value, origin in pathUpdaterInView.updateActivePath(moveEdge: fromId, offset: origin.offset(to: value.location), pending: pending) }
                }
                $0.onDrag(update(pending: true))
                $0.onDragEnd(update())
            }
    }
}
