import Foundation
import SwiftUI

// MARK: - ActivePathHandles

struct ActivePathHandles: View {
    var body: some View {
        if let activePath = activePathModel.pendingActivePath {
            Group {
                let segments = activePath.segments
                ForEach(segments) { s in ActivePathSegmentHandle(segment: s, data: s.data.applying(viewport.toView)) }
                ForEach(segments) { s in ActivePathNodeHandle(segment: s, data: s.data.applying(viewport.toView)) }
                ForEach(segments) { s in ActivePathEdgeHandle(segment: s, data: s.data.applying(viewport.toView)) }
            }
        }
    }

    @EnvironmentObject private var viewport: Viewport
    @EnvironmentObject private var documentModel: DocumentModel
    @EnvironmentObject private var pathStore: PathStore
    @EnvironmentObject private var activePathModel: ActivePathModel
}

// MARK: - ActivePathNodeHandle

struct ActivePathNodeHandle: View {
    let segment: PathSegment
    let data: PathSegmentData

    var body: some View {
        circle(at: data.node, color: .blue)
            .gesture(drag(updating: $dragging))
            .onTapGesture {
                print("focus node", nodeId)
                activePathModel.focusedPart = .node(nodeId)
            }
            .onChange(of: dragging) {
                if !dragging {
                    dragOriginPosition = nil
                }
            }
    }

    // MARK: private

    private static let lineWidth: CGFloat = 2
    private static let circleSize: CGFloat = 16
    private static let touchablePadding: CGFloat = 16

    @EnvironmentObject private var activePathModel: ActivePathModel
    @EnvironmentObject private var updater: PathUpdater

    @GestureState private var dragging: Bool = false
    @State var dragOriginPosition: CGPoint?

    private var nodeId: UUID { segment.node.id }

    @ViewBuilder private func circle(at point: Point2, color: Color) -> some View {
        Circle()
            .stroke(color, style: StrokeStyle(lineWidth: Self.lineWidth))
            .fill(color.opacity(0.5))
            .frame(width: Self.circleSize, height: Self.circleSize)
            .padding(Self.touchablePadding)
            .invisibleSoildOverlay()
            .position(point)
    }

    private func drag(updating v: GestureState<Bool>) -> some Gesture {
        let getLocation: (DragGesture.Value) -> Point2 = { $0.location }
        let getDelta: (DragGesture.Value) -> Vector2 = { dragOriginPosition?.deltaVector(to: getLocation($0)) ?? .zero }
        return DragGesture()
            .updating(flag: v)
            .onChanged { value in
                if dragOriginPosition == nil {
                    dragOriginPosition = data.node
                }
                updater.updateActivePath(nodeAndControl: nodeId, deltaInView: getDelta(value), pending: true)
            }
            .onEnded { value in
                updater.updateActivePath(nodeAndControl: nodeId, deltaInView: getDelta(value))
            }
    }
}

// MARK: - ActivePathSegmentHandle

struct ActivePathSegmentHandle: View {
    let segment: PathSegment
    let data: PathSegmentData

    var body: some View {
        outline
            .onTapGesture {
                print("focus edge", segmentId)
                activePathModel.focusedPart = .edge(segmentId)
            }
        if let nextNode = data.nextNode, focused {
            circle(at: data.edge.position(from: data.node, to: nextNode, at: 0.5), color: .teal)
        }
    }

    private static let lineWidth: CGFloat = 2
    private static let circleSize: CGFloat = 16
    private static let touchablePadding: CGFloat = 16

    @EnvironmentObject private var activePathModel: ActivePathModel

    private var segmentId: UUID { segment.id }
    private var focused: Bool { activePathModel.focusedEdgeId == segmentId }

    @ViewBuilder private var outline: some View {
        if let nextNode = data.nextNode {
            SUPath { p in
                p.move(to: data.node)
                data.edge.draw(path: &p, to: nextNode)
            }
            .strokedPath(StrokeStyle(lineWidth: 24, lineCap: .round))
            .fill(Color.invisibleSolid)
            .allowsHitTesting(!focused)
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
    }
}

// MARK: - ActivePathEdgeHandle

struct ActivePathEdgeHandle: View {
    let segment: PathSegment
    let data: PathSegmentData

    var body: some View {
        if let nextNode = data.nextNode {
            if case let .Arc(arc) = data.edge {
                ActivePathArcHandle(segment: segment, arc: arc, from: data.node, to: nextNode)
            } else if case let .Bezier(bezier) = data.edge {
                ActivePathBezierHandle(segment: segment, bezier: bezier, from: data.node, to: nextNode)
            }
        }
    }
}

// MARK: - ActivePathBezierHandle

struct ActivePathBezierHandle: View {
    let segment: PathSegment
    let bezier: PathBezier
    let from: Point2
    let to: Point2

    var body: some View {
        ZStack {
            if edgeFocused || nodeFocused {
                line(from: from, to: bezier.control0, color: .green)
                circle(at: bezier.control0, color: .green)
                    .gesture(drag(updating: $draggingControl0) { bezier.with(control0: $0) })
            }
            if edgeFocused || nextFocused {
                line(from: to, to: bezier.control1, color: .orange)
                circle(at: bezier.control1, color: .orange)
                    .gesture(drag(updating: $draggingControl1) { bezier.with(control1: $0) })
            }
        }
    }

    // MARK: private

    private static let lineWidth: CGFloat = 1
    private static let circleSize: CGFloat = 12
    private static let touchablePadding: CGFloat = 12

    @EnvironmentObject private var activePathModel: ActivePathModel
    @EnvironmentObject private var updater: PathUpdater

    @GestureState private var draggingControl0: Bool = false
    @GestureState private var draggingControl1: Bool = false

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

    private func drag(updating v: GestureState<Bool>, getBezier: @escaping (Point2) -> PathBezier) -> some Gesture {
        DragGesture()
            .updating(flag: v)
            .onChanged { updater.updateActivePath(edge: segment.id, bezierInView: getBezier($0.location), pending: true) }
            .onEnded { updater.updateActivePath(edge: segment.id, bezierInView: getBezier($0.location)) }
    }
}

// MARK: - ActivePathArcHandle

struct ActivePathArcHandle: View {
    let segment: PathSegment
    let arc: PathArc
    let from: Point2
    let to: Point2

    var body: some View {
        if edgeFocused || nodeFocused || nextFocused {
            ZStack {
                ellipse
                radiusLine
                //            centerCircle
                radiusWidthRect
                    .gesture(dragRadius(updating: $draggingRadiusW) { arc.with(radius: radius.with(width: $0)) })
                radiusHeightRect
                    .gesture(dragRadius(updating: $draggingRadiusH) { arc.with(radius: radius.with(height: $0)) })
            }
            .onChange(of: draggingRadius) {
                if draggingRadius == false {
                    dragOriginCenter = nil
                }
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

    @GestureState private var draggingRadiusW: Bool = false
    @GestureState private var draggingRadiusH: Bool = false
    var draggingRadius: Bool { draggingRadiusW || draggingRadiusH }
    @State var dragOriginCenter: CGPoint?

    private var edgeFocused: Bool { activePathModel.focusedEdgeId == segment.node.id }
    private var nodeFocused: Bool { activePathModel.focusedNodeId == segment.node.id }
    private var nextFocused: Bool { activePathModel.focusedNodeId == segment.nextNode?.id }

    private var radius: CGSize { arc.radius }
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

    private func dragRadius(updating v: GestureState<Bool>, callback: @escaping (CGFloat) -> PathArc) -> some Gesture {
        let getValue: (Point2) -> CGFloat = { $0.distance(to: dragOriginCenter!) * 2 }
        return DragGesture()
            .updating(flag: v)
            .onChanged {
                if dragOriginCenter == nil {
                    dragOriginCenter = center
                }
                updater.updateActivePath(edge: segment.id, arcInView: callback(getValue($0.location)), pending: true)
            }
            .onEnded { updater.updateActivePath(edge: segment.id, arcInView: callback(getValue($0.location))) }
    }
}
