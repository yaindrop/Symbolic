import Foundation
import SwiftUI

// MARK: - DragGestureWithContext

struct DragGestureWithContext<Context>: ViewModifier {
    func body(content: Content) -> some View {
        content
            .gesture(gesture)
            .onChange(of: dragging) {
                if !dragging {
                    context = nil
                }
            }
    }

    init(getContext: @escaping () -> Context,
         onChanged: @escaping (DragGesture.Value, Context) -> Void,
         onEnded: @escaping (DragGesture.Value, Context) -> Void) {
        self.getContext = getContext
        self.onChanged = onChanged
        self.onEnded = onEnded
    }

    private let getContext: () -> Context
    private let onChanged: (DragGesture.Value, Context) -> Void
    private let onEnded: (DragGesture.Value, Context) -> Void

    @State private var context: Context?
    @GestureState private var dragging: Bool = false

    private var gesture: some Gesture {
        DragGesture()
            .updating(flag: $dragging)
            .onChanged { value in
                if let context {
                    onChanged(value, context)
                } else {
                    let context = getContext()
                    self.context = context
                    onChanged(value, context)
                }
            }
            .onEnded { value in
                if let context {
                    onEnded(value, context)
                }
            }
    }
}

extension DragGestureWithContext where Context == Void {
    init(onChanged: @escaping (DragGesture.Value, Context) -> Void,
         onEnded: @escaping (DragGesture.Value, Context) -> Void) {
        self.init(getContext: {}, onChanged: onChanged, onEnded: onEnded)
    }
}

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
            .modifier(drag)
            .onTapGesture {
                print("focus node", nodeId)
                activePathModel.focusedPart = .node(nodeId)
            }
    }

    // MARK: private

    private static let lineWidth: CGFloat = 2
    private static let circleSize: CGFloat = 16
    private static let touchablePadding: CGFloat = 16

    @EnvironmentObject private var activePathModel: ActivePathModel
    @EnvironmentObject private var updater: PathUpdater

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

    private var drag: DragGestureWithContext<Point2> {
        DragGestureWithContext {
            data.node
        } onChanged: { value, origin in
            updater.updateActivePath(aroundNode: nodeId, offsetInView: origin.deltaVector(to: value.location), pending: true)
        } onEnded: { value, origin in
            updater.updateActivePath(aroundNode: nodeId, offsetInView: origin.deltaVector(to: value.location))
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
        if let circlePosition, focused {
            circle(at: circlePosition, color: .teal)
                .modifier(drag(origin: circlePosition))
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

    private func drag(origin: Point2) -> DragGestureWithContext<Point2> {
        DragGestureWithContext {
            origin
        } onChanged: { value, origin in
            updater.updateActivePath(aroundEdge: segmentId, offsetInView: origin.deltaVector(to: value.location), pending: true)
        } onEnded: { value, origin in
            updater.updateActivePath(aroundEdge: segmentId, offsetInView: origin.deltaVector(to: value.location))
        }
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

    private func drag(getBezier: @escaping (Point2) -> PathBezier) -> DragGestureWithContext<Void> {
        DragGestureWithContext { value, _ in
            updater.updateActivePath(edge: segment.id, bezierInView: getBezier(value.location), pending: true)
        } onEnded: { value, _ in
            updater.updateActivePath(edge: segment.id, bezierInView: getBezier(value.location))
        }
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
                    .modifier(dragRadius { arc.with(radius: radius.with(width: $0)) })
                radiusHeightRect
                    .modifier(dragRadius { arc.with(radius: radius.with(height: $0)) })
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

    private func dragRadius(getArc: @escaping (CGFloat) -> PathArc) -> DragGestureWithContext<Point2> {
        DragGestureWithContext {
            center
        } onChanged: { value, origin in
            updater.updateActivePath(edge: segment.id, arcInView: getArc(value.location.distance(to: origin) * 2), pending: true)
        } onEnded: { value, origin in
            updater.updateActivePath(edge: segment.id, arcInView: getArc(value.location.distance(to: origin) * 2))
        }
    }
}
