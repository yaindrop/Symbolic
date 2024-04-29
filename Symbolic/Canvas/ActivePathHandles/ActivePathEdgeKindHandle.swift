import Foundation
import SwiftUI

// MARK: - ActivePathEdgeKindHandle

struct ActivePathEdgeKindHandle: View {
    let segment: PathSegment
    let data: PathSegment.Data

    var body: some View {
        if let nextNode = data.nextNode {
            if case let .arc(arc) = data.edge {
                ActivePathArcHandle(segment: segment, arc: arc, from: data.node, to: nextNode)
            } else if case let .bezier(bezier) = data.edge {
                ActivePathBezierHandle(segment: segment, bezier: bezier, from: data.node, to: nextNode)
            }
        }
    }
}

// MARK: - ActivePathBezierHandle

struct ActivePathBezierHandle: View {
    let segment: PathSegment
    let bezier: PathEdge.Bezier
    let from: Point2
    let to: Point2

    var body: some View {
        ZStack {
            if edgeFocused || nodeFocused {
                line(from: from, to: bezier.control0, color: .green)
                circle(at: bezier.control0, color: .green)
                    .modifier(drag { bezier.with(control0: $0) })
            }
            if edgeFocused || nextFocused {
                line(from: to, to: bezier.control1, color: .orange)
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

    private var edgeFocused: Bool { activePathModel.focusedEdgeId == segment.node.id }
    private var nodeFocused: Bool { activePathModel.focusedNodeId == segment.node.id }
    private var nextFocused: Bool { activePathModel.focusedNodeId == segment.nextNode?.id }

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

    private func drag(getBezier: @escaping (Point2) -> PathEdge.Bezier) -> DragGestureWithContext<Void> {
        func update(pending: Bool = false) -> (DragGesture.Value, Any) -> Void {
            { value, _ in updater.updateActivePath(edge: segment.id, bezierInView: getBezier(value.location), pending: pending) }
        }
        return DragGestureWithContext((), onChanged: update(pending: true), onEnded: update())
    }
}

// MARK: - ActivePathArcHandle

struct ActivePathArcHandle: View {
    let segment: PathSegment
    let arc: PathEdge.Arc
    let from: Point2
    let to: Point2

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

    private var edgeFocused: Bool { activePathModel.focusedEdgeId == segment.node.id }
    private var nodeFocused: Bool { activePathModel.focusedNodeId == segment.node.id }
    private var nextFocused: Bool { activePathModel.focusedNodeId == segment.nextNode?.id }

    private var radius: CGSize { arc.radius }
    private var endPointParam: PathEdge.Arc.EndpointParam { arc.with(radius: radius).toParam(from: from, to: to) }
    private var param: PathEdge.Arc.CenterParam { endPointParam.centerParam! }
    private var center: Point2 { param.center }
    private var radiusWidthEnd: Point2 { (center + Vector2.unitX).applying(param.transform) }
    private var radiusHeightEnd: Point2 { (center + Vector2.unitY).applying(param.transform) }
    private var radiusHalfWidthEnd: Point2 { (center + Vector2.unitX / 2).applying(param.transform) }
    private var radiusHalfHeightEnd: Point2 { (center + Vector2.unitY / 2).applying(param.transform) }

    @ViewBuilder private var ellipse: some View {
        Circle()
            .fill(.red.opacity(0.2))
            .frame(width: 1, height: 1)
            .scaleEffect(x: radius.width * 2, y: radius.height * 2)
            .rotationEffect(param.rotation)
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

    private func dragRadius(getArc: @escaping (CGFloat) -> PathEdge.Arc) -> DragGestureWithContext<Point2> {
        func update(pending: Bool = false) -> (DragGesture.Value, Point2) -> Void {
            { value, origin in updater.updateActivePath(edge: segment.id, arcInView: getArc(value.location.distance(to: origin) * 2), pending: pending) }
        }
        return DragGestureWithContext(center, onChanged: update(pending: true), onEnded: update())
    }
}
