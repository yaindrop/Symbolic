import Foundation
import SwiftUI

// MARK: - ActivePathEdgeKindHandle

struct ActivePathEdgeKindHandle: View {
    let fromId: UUID
    let toId: UUID
    let segment: PathSegment

    var body: some View { tracer.range("ActivePathEdgeKindHandle body") {
        if case let .arc(arc) = segment {
            ActivePathArcHandle(fromId: fromId, toId: toId, segment: arc)
        } else if case let .bezier(bezier) = segment {
            ActivePathBezierHandle(fromId: fromId, toId: toId, segment: bezier)
        }
    }}
}

// MARK: - ActivePathBezierHandle

struct ActivePathBezierHandle: View, EnableActivePathInteractor, EnablePathUpdaterInView {
    @Environment(ViewportModel.self) var viewport: ViewportModel
    @Environment(PathModel.self) var pathModel: PathModel
    @Environment(PendingPathModel.self) var pendingPathModel: PendingPathModel
    @Environment(ActivePathModel.self) var activePathModel: ActivePathModel
    @Environment(PathUpdateModel.self) var pathUpdateModel: PathUpdateModel

    let fromId: UUID
    let toId: UUID
    let segment: PathSegment.Bezier

    var body: some View {
        ZStack {
            if edgeFocused || nodeFocused {
                line(from: segment.from, to: bezier.control0, color: .green)
                circle(at: bezier.control0, color: .green)
                    .multipleGesture(dragControl0, ()) {
                        func update(pending: Bool = false) -> (DragGesture.Value, Void) -> Void {
                            { v, _ in pathUpdaterInView.updateActivePath(edge: fromId, bezier: bezier.with(control0: v.location), pending: pending) }
                        }
                        $0.onDrag(update(pending: true))
                        $0.onDragEnd(update())
                    }
            }
            if edgeFocused || nextFocused {
                line(from: segment.to, to: bezier.control1, color: .orange)
                circle(at: bezier.control1, color: .orange)
                    .multipleGesture(dragControl1, ()) {
                        func update(pending: Bool = false) -> (DragGesture.Value, Void) -> Void {
                            { v, _ in pathUpdaterInView.updateActivePath(edge: fromId, bezier: bezier.with(control1: v.location), pending: pending) }
                        }
                        $0.onDrag(update(pending: true))
                        $0.onDragEnd(update())
                    }
            }
        }
    }

    // MARK: private

    private static let lineWidth: Scalar = 1
    private static let circleSize: Scalar = 12
    private static let touchablePadding: Scalar = 12

    @State private var dragControl0 = MultipleGestureModel<Void>()
    @State private var dragControl1 = MultipleGestureModel<Void>()

    private var bezier: PathEdge.Bezier { segment.bezier }

    private var edgeFocused: Bool { activePathInteractor.focusedEdgeId == fromId }
    private var nodeFocused: Bool { activePathInteractor.focusedNodeId == fromId }
    private var nextFocused: Bool { activePathInteractor.focusedNodeId == toId }

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

// MARK: - ActivePathArcHandle

struct ActivePathArcHandle: View, EnableActivePathInteractor, EnablePathUpdaterInView {
    @Environment(ViewportModel.self) var viewport: ViewportModel
    @Environment(PathModel.self) var pathModel: PathModel
    @Environment(PendingPathModel.self) var pendingPathModel: PendingPathModel
    @Environment(ActivePathModel.self) var activePathModel: ActivePathModel
    @Environment(PathUpdateModel.self) var pathUpdateModel: PathUpdateModel

    let fromId: UUID
    let toId: UUID
    let segment: PathSegment.Arc

    var body: some View {
        if edgeFocused || nodeFocused || nextFocused {
            ZStack {
                ellipse
                radiusLine
                //            centerCircle
                radiusWidthRect
                radiusHeightRect
            }
        }
    }

    // MARK: private

    private static let lineWidth: Scalar = 1
    private static let circleSize: Scalar = 12
    private static let rectSize: CGSize = CGSize(16, 9)
    private static let touchablePadding: Scalar = 12

    private var arc: PathEdge.Arc { segment.arc }

    private var edgeFocused: Bool { activePathInteractor.focusedEdgeId == fromId.id }
    private var nodeFocused: Bool { activePathInteractor.focusedNodeId == fromId.id }
    private var nextFocused: Bool { activePathInteractor.focusedNodeId == toId }

    private var radius: CGSize { arc.radius }
    private var endPointParams: PathSegment.Arc.EndpointParams { segment.params }
    private var params: PathSegment.Arc.CenterParams { endPointParams.centerParams }
    private var center: Point2 { params.center }
    private var radiusWidthEnd: Point2 { (center + Vector2.unitX).applying(params.transform) }
    private var radiusHeightEnd: Point2 { (center + Vector2.unitY).applying(params.transform) }
    private var radiusHalfWidthEnd: Point2 { (center + Vector2.unitX / 2).applying(params.transform) }
    private var radiusHalfHeightEnd: Point2 { (center + Vector2.unitY / 2).applying(params.transform) }

    @ViewBuilder private var ellipse: some View {
        Circle()
            .fill(.red.opacity(0.2))
            .frame(width: 1, height: 1)
            .scaleEffect(x: radius.width * 2, y: radius.height * 2)
            .rotationEffect(params.rotation)
            .position(center)
            .allowsHitTesting(false)
    }

//    private func subtractingCircle(at point: Point2) -> SUPath {
//        SUPath { $0.addEllipse(in: CGRect(center: point, size: CGSize(squared: Self.circleSize))) }
//    }

    private func subtractingRect(at point: Point2, size: CGSize) -> SUPath {
        SUPath { $0.addRect(CGRect(center: point, size: size)) }
    }

    @ViewBuilder private var radiusLine: some View {
        SUPath { p in
            p.move(to: center)
            p.addLine(to: radiusWidthEnd)
            p.move(to: center)
            p.addLine(to: radiusHeightEnd)
            p = p.strokedPath(StrokeStyle(lineWidth: Self.lineWidth))
//            p = p.subtracting(subtractingCircle(at: center))
            p = p.subtracting(subtractingRect(at: radiusHalfWidthEnd, size: Self.rectSize))
            p = p.subtracting(subtractingRect(at: radiusHalfHeightEnd, size: Self.rectSize.flipped))
        }
        .fill(.pink.opacity(0.5))
        .allowsTightening(false)
    }

    @ViewBuilder private var radiusRect: some View {
        EmptyView()
    }

//    @ViewBuilder private var centerCircle: some View {
//        Circle()
//            .stroke(.pink, style: StrokeStyle(lineWidth: Self.lineWidth))
//            .fill(.pink.opacity(0.5))
//            .frame(width: Self.circleSize, height: Self.circleSize)
//            .padding(Self.touchablePadding)
//            .invisibleSoildOverlay()
//            .position(center)
//    }

    @State private var dragRadiusWidth = MultipleGestureModel<Point2>()

    @ViewBuilder private var radiusWidthRect: some View {
        Rectangle()
            .stroke(.pink, style: StrokeStyle(lineWidth: Self.lineWidth))
            .fill(.pink.opacity(0.5))
            .frame(width: Self.rectSize.width, height: Self.rectSize.height)
            .padding(Self.touchablePadding)
            .invisibleSoildOverlay()
            .rotationEffect(arc.rotation)
            .position(radiusHalfWidthEnd)
            .multipleGesture(dragRadiusHeight, center) {
                func update(pending: Bool = false) -> (DragGesture.Value, Point2) -> Void {
                    { pathUpdaterInView.updateActivePath(edge: fromId, arc: arc.with(radius: radius.with(width: $0.location.distance(to: $1) * 2)), pending: pending) }
                }
                $0.onDrag(update(pending: true))
                $0.onDragEnd(update())
            }
    }

    @State private var dragRadiusHeight = MultipleGestureModel<Point2>()

    @ViewBuilder private var radiusHeightRect: some View {
        Rectangle()
            .stroke(.pink, style: StrokeStyle(lineWidth: Self.lineWidth))
            .fill(.pink.opacity(0.5))
            .frame(width: Self.rectSize.height, height: Self.rectSize.width)
            .padding(Self.touchablePadding)
            .invisibleSoildOverlay()
            .rotationEffect(arc.rotation)
            .position(radiusHalfHeightEnd)
            .multipleGesture(dragRadiusHeight, center) {
                func update(pending: Bool = false) -> (DragGesture.Value, Point2) -> Void {
                    { pathUpdaterInView.updateActivePath(edge: fromId, arc: arc.with(radius: radius.with(height: $0.location.distance(to: $1) * 2)), pending: pending) }
                }
                $0.onDrag(update(pending: true))
                $0.onDragEnd(update())
            }
    }
}
