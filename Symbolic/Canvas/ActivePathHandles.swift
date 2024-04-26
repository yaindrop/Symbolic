import Foundation
import SwiftUI

// MARK: - EnvironmentValues

fileprivate extension EnvironmentValues {
    struct PathNodeIdKey: EnvironmentKey {
        static let defaultValue = UUID()
    }

    var pathNodeId: UUID {
        get { self[PathNodeIdKey.self] }
        set { self[PathNodeIdKey.self] = newValue }
    }
}

// MARK: - ActivePathHandles

struct ActivePathHandles: View {
    var body: some View {
        if let activePath = activePathModel.activePath {
            Group {
                ForEach(activePath.segments) { s in
                    ActivePathSegmentHandle(data: s.data.applying(viewport.info.worldToView))
                        .environment(\.pathNodeId, s.id)
                }
                ForEach(activePath.vertices) { v in
                    ActivePathVertexHandle(data: v.data.applying(viewport.info.worldToView))
                        .environment(\.pathNodeId, v.id)
                }
                ForEach(activePath.segments) { s in
                    ActivePathEdgeHandle(data: s.data.applying(viewport.info.worldToView))
                        .environment(\.pathNodeId, s.id)
                }
            }
        }
    }

    @EnvironmentObject private var viewport: Viewport
    @EnvironmentObject private var documentModel: DocumentModel
    @EnvironmentObject private var pathStore: PathStore
    @EnvironmentObject private var activePathModel: ActivePathModel
}

// MARK: - ActivePathVertexHandle

struct ActivePathVertexHandle: View {
    let data: PathVertexData

    var body: some View {
        circle(at: node, color: .blue)
            .gesture(drag(updating: $dragging))
    }

    // MARK: private

    private static let lineWidth: CGFloat = 2
    private static let circleSize: CGFloat = 16
    private static let touchablePadding: CGFloat = 24

    @Environment(\.pathNodeId) private var nodeId: UUID
    @EnvironmentObject private var updater: PathUpdater
    @GestureState private var dragging: Point2?

    private var node: Point2 { dragging ?? data.node }

    @ViewBuilder private func circle(at point: Point2, color: Color) -> some View {
        Circle()
            .stroke(color, style: StrokeStyle(lineWidth: Self.lineWidth))
            .fill(color.opacity(0.5))
            .frame(width: Self.circleSize, height: Self.circleSize)
            .padding(Self.touchablePadding)
            .invisibleSoildOverlay()
            .position(point)
    }

    private func drag(updating v: GestureState<Point2?>) -> some Gesture {
        DragGesture()
            .updating(v) { value, state, _ in state = value.location }
            .onChanged { updater.activePathHandle(node: nodeId, with: $0.location, pending: true) }
            .onEnded { updater.activePathHandle(node: nodeId, with: $0.location) }
    }
}

// MARK: - ActivePathSegmentHandle

struct ActivePathSegmentHandle: View {
    let data: PathSegmentData

    var body: some View {
        SUPath { p in
            p.move(to: data.from)
            data.edge.draw(path: &p, to: data.to)
        }
        .strokedPath(StrokeStyle(lineWidth: 16, lineCap: .round))
        .fill(.blue.opacity(0.2))
    }
}

// MARK: - ActivePathEdgeHandle

struct ActivePathEdgeHandle: View {
    let data: PathSegmentData

    var body: some View {
        if case let .Arc(arc) = data.edge {
            ActivePathArcHandle(arc: arc, from: data.from, to: data.to)
        } else if case let .Bezier(bezier) = data.edge {
            ActivePathBezierHandle(bezier: bezier, from: data.from, to: data.to)
        }
    }
}

// MARK: - ActivePathBezierHandle

struct ActivePathBezierHandle: View {
    let bezier: PathBezier
    let from: Point2
    let to: Point2

    var body: some View {
        ZStack {
            line(from: from, to: control0, color: .green)
            circle(at: control0, color: .green)
                .gesture(drag(updating: $dragging0) { bezier.with(control0: $0) })
            line(from: to, to: control1, color: .orange)
            circle(at: control1, color: .orange)
                .gesture(drag(updating: $dragging1) { bezier.with(control1: $0) })
        }
    }

    // MARK: private

    private static let lineWidth: CGFloat = 1
    private static let circleSize: CGFloat = 12
    private static let touchablePadding: CGFloat = 24

    @Environment(\.pathNodeId) private var fromId: UUID
    @EnvironmentObject private var updater: PathUpdater
    @GestureState private var dragging0: Point2?
    @GestureState private var dragging1: Point2?

    private var control0: Point2 { dragging0 ?? bezier.control0 }
    private var control1: Point2 { dragging1 ?? bezier.control1 }

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

    private func drag(updating v: GestureState<Point2?>, callback: @escaping (Point2) -> PathBezier) -> some Gesture {
        DragGesture()
            .updating(v) { value, state, _ in state = value.location }
            .onChanged { updater.activePathHandle(edge: fromId, with: callback($0.location), pending: true) }
            .onEnded { updater.activePathHandle(edge: fromId, with: callback($0.location)) }
    }
}

// MARK: - ActivePathArcHandle

struct ActivePathArcHandle: View {
    let arc: PathArc
    let from: Point2
    let to: Point2

    var body: some View {
        ellipse
        radiusLine
//        centerCircle
        radiusWidthRect
            .gesture(dragRadius(updating: $draggingRadiusW) { arc.with(radius: radius.with(width: $0)) })
        radiusHeightRect
            .gesture(dragRadius(updating: $draggingRadiusH) { arc.with(radius: radius.with(height: $0)) })
    }

    // MARK: private

    private static let lineWidth: CGFloat = 1
    private static let circleSize: CGFloat = 12
    private static let rectSize: CGSize = CGSize(16, 9)
    private static let touchablePadding: CGFloat = 24

    @Environment(\.pathNodeId) private var fromId: UUID
    @EnvironmentObject private var updater: PathUpdater
    @GestureState private var draggingRadiusW: CGFloat?
    @GestureState private var draggingRadiusH: CGFloat?

    private var radius: CGSize { CGSize(draggingRadiusW ?? arc.radius.width, draggingRadiusH ?? arc.radius.height) }
    private var endPointParam: ArcEndpointParam { arc.with(radius: radius).toParam(from: from, to: to) }
    private var param: ArcCenterParam { endPointParam.centerParam! }
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
    }

    private func dragRadius(updating v: GestureState<CGFloat?>, callback: @escaping (CGFloat) -> PathArc) -> some Gesture {
        let center = arc.toParam(from: from, to: to).centerParam!.center
        let getValue = { (position: Point2) in position.distance(to: center) * 2 }
        return DragGesture()
            .updating(v) { value, state, _ in state = getValue(value.location) }
            .onChanged { updater.activePathHandle(edge: fromId, with: callback(getValue($0.location)), pending: true) }
            .onEnded { updater.activePathHandle(edge: fromId, with: callback(getValue($0.location))) }
    }
}
