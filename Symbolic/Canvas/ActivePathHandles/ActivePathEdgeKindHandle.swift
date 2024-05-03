import Foundation
import SwiftUI

// MARK: - ActivePathEdgeKindHandle

struct ActivePathEdgeKindHandle: View {
    let fromId: UUID
    let toId: UUID
    let segment: PathSegment

    var body: some View {
        if case let .arc(arc) = segment {
            ActivePathArcHandle(fromId: fromId, toId: toId, segment: arc)
        } else if case let .bezier(bezier) = segment {
            ActivePathBezierHandle(fromId: fromId, toId: toId, segment: bezier)
        }
    }
}

// MARK: - ActivePathBezierHandle

struct ActivePathBezierHandle: View {
    let fromId: UUID
    let toId: UUID
    let segment: PathSegment.Bezier

    var body: some View {
        ZStack {
            if edgeFocused || nodeFocused {
                line(from: segment.from, to: bezier.control0, color: .green)
                circle(at: bezier.control0, color: .green)
                    .modifier(drag { bezier.with(control0: $0) })
            }
            if edgeFocused || nextFocused {
                line(from: segment.to, to: bezier.control1, color: .orange)
                circle(at: bezier.control1, color: .orange)
                    .modifier(drag { bezier.with(control1: $0) })
            }
        }
    }

    // MARK: private

    private static let lineWidth: CGFloat = 1
    private static let circleSize: CGFloat = 12
    private static let touchablePadding: CGFloat = 12

    @EnvironmentObject private var activePathModel: ActivePathModel
    @EnvironmentObject private var updater: PathUpdater

    private var bezier: PathEdge.Bezier { segment.bezier }

    private var edgeFocused: Bool { activePathModel.focusedEdgeId == fromId }
    private var nodeFocused: Bool { activePathModel.focusedNodeId == fromId }
    private var nextFocused: Bool { activePathModel.focusedNodeId == toId }

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

    private func drag(getBezier: @escaping (Point2) -> PathEdge.Bezier) -> MultipleGestureModifier<Void> {
        func update(pending: Bool = false) -> (DragGesture.Value, Any) -> Void {
            { value, _ in updater.updateActivePath(edge: fromId, bezierInView: getBezier(value.location), pending: pending) }
        }
        return MultipleGestureModifier((), onDrag: update(pending: true), onDragEnd: update())
    }
}

// MARK: - ActivePathArcHandle

struct ActivePathArcHandle: View {
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

    private static let lineWidth: CGFloat = 1
    private static let circleSize: CGFloat = 12
    private static let rectSize: CGSize = CGSize(16, 9)
    private static let touchablePadding: CGFloat = 12

    @EnvironmentObject private var activePathModel: ActivePathModel
    @EnvironmentObject private var updater: PathUpdater

    private var arc: PathEdge.Arc { segment.arc }

    private var edgeFocused: Bool { activePathModel.focusedEdgeId == fromId.id }
    private var nodeFocused: Bool { activePathModel.focusedNodeId == fromId.id }
    private var nextFocused: Bool { activePathModel.focusedNodeId == toId }

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

    @ViewBuilder private var radiusWidthRect: some View {
        Rectangle()
            .stroke(.pink, style: StrokeStyle(lineWidth: Self.lineWidth))
            .fill(.pink.opacity(0.5))
            .frame(width: Self.rectSize.width, height: Self.rectSize.height)
            .padding(Self.touchablePadding)
            .invisibleSoildOverlay()
            .rotationEffect(arc.rotation)
            .position(radiusHalfWidthEnd)
            .modifier(dragRadius { arc.with(radius: radius.with(width: $0)) })
    }

    @ViewBuilder private var radiusHeightRect: some View {
        Rectangle()
            .stroke(.pink, style: StrokeStyle(lineWidth: Self.lineWidth))
            .fill(.pink.opacity(0.5))
            .frame(width: Self.rectSize.height, height: Self.rectSize.width)
            .padding(Self.touchablePadding)
            .invisibleSoildOverlay()
            .rotationEffect(arc.rotation)
            .position(radiusHalfHeightEnd)
            .modifier(dragRadius { arc.with(radius: radius.with(height: $0)) })
    }

    private func dragRadius(getArc: @escaping (CGFloat) -> PathEdge.Arc) -> MultipleGestureModifier<Point2> {
        func update(pending: Bool = false) -> (DragGesture.Value, Point2) -> Void {
            { value, origin in updater.updateActivePath(edge: fromId, arcInView: getArc(value.location.distance(to: origin) * 2), pending: pending) }
        }
        return MultipleGestureModifier(center, onDrag: update(pending: true), onDragEnd: update())
    }
}