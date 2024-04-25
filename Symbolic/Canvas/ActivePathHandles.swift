import Combine
import Foundation
import SwiftUI

fileprivate extension EnvironmentValues {
    struct PathNodeIdKey: EnvironmentKey {
        static let defaultValue = UUID()
    }

    var pathNodeId: UUID {
        get { self[PathNodeIdKey.self] }
        set { self[PathNodeIdKey.self] = newValue }
    }
}

fileprivate class Updater: ObservableObject {
    var activePath: Path?
    var viewport: Viewport?

    func update(edge fromNodeId: UUID, with bezierInView: PathBezier, ended: Bool) {
        guard let activePath else { return }
        guard let viewport else { return }
        let bezier = bezierInView.applying(viewport.info.viewToWorld)
        let event = DocumentEvent(inPath: activePath.id, updateEdgeFrom: fromNodeId, .Bezier(bezier))
        (ended ? eventSubject : pendingEventSubject).send(event)
    }

    func update(edge fromNodeId: UUID, with arcInView: PathArc, ended: Bool) {
        guard let activePath else { return }
        guard let viewport else { return }
        let arc = arcInView.applying(viewport.info.viewToWorld)
        let event = DocumentEvent(inPath: activePath.id, updateEdgeFrom: fromNodeId, .Arc(arc))
        (ended ? eventSubject : pendingEventSubject).send(event)
    }

    func onEvent(_ callback: @escaping (DocumentEvent) -> Void) {
        eventSubject.sink { value in callback(value) }.store(in: &subscriptions)
    }

    func onPendingEvent(_ callback: @escaping (DocumentEvent) -> Void) {
        pendingEventSubject.sink { value in callback(value) }.store(in: &subscriptions)
    }

    private var subscriptions = Set<AnyCancellable>()
    private var eventSubject = PassthroughSubject<DocumentEvent, Never>()
    private var pendingEventSubject = PassthroughSubject<DocumentEvent, Never>()
}

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
            .onAppear {
                updater.activePath = activePath
                updater.viewport = viewport
                updater.onPendingEvent { pathStore.pendingEvent = $0 }
                updater.onEvent {
                    pathStore.pendingEvent = nil
                    documentModel.sendEvent($0)
                }
            }
            .environmentObject(updater)
        }
    }

    @StateObject private var updater: Updater = Updater()
    @EnvironmentObject private var viewport: Viewport
    @EnvironmentObject private var documentModel: DocumentModel
    @EnvironmentObject private var pathStore: PathStore
    @EnvironmentObject private var activePathModel: ActivePathModel
}

struct ActivePathVertexHandle: View {
    let data: PathVertexData

    var body: some View {
        Circle().fill(.blue.opacity(0.5)).frame(width: 8, height: 8).position(data.node)
    }
}

struct ActivePathSegmentHandle: View {
    let data: PathSegmentData

    var body: some View {
        SUPath { p in
            p.move(to: data.from)
            data.edge.draw(path: &p, to: data.to)
        }
        .strokedPath(StrokeStyle(lineWidth: 16, lineCap: .round))
        .fill(.blue.opacity(0.5))
    }
}

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

struct ActivePathBezierHandle: View {
    let bezier: PathBezier
    let from: Point2
    let to: Point2

    var control0: Point2 { dragging0 ?? bezier.control0 }
    var control1: Point2 { dragging1 ?? bezier.control1 }

    @ViewBuilder func link(from: Point2, to: Point2, color: Color) -> some View {
        SUPath { p in
            p.move(to: from)
            p.addLine(to: to)
        }.stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: Self.lineWidth, dash: [Self.lineWidth * 2]))
    }

    @ViewBuilder func circle(at point: Point2, color: Color) -> some View {
        Circle()
            .stroke(color, style: StrokeStyle(lineWidth: Self.lineWidth))
            .fill(color.opacity(0.5))
            .frame(width: Self.circleSize, height: Self.circleSize)
            .position(point)
    }

    func drag(updating v: GestureState<Point2?>, callback: @escaping (Point2) -> PathBezier) -> some Gesture {
        DragGesture()
            .updating(v) { value, state, _ in state = value.location }
            .onChanged { updater.update(edge: fromId, with: callback($0.location), ended: false) }
            .onEnded { updater.update(edge: fromId, with: callback($0.location), ended: true) }
    }

    var body: some View {
        ZStack {
            link(from: from, to: control0, color: .green)
            circle(at: control0, color: .green)
                .gesture(drag(updating: $dragging0, callback: { bezier.with(control0: $0) }))
            link(from: to, to: control1, color: .orange)
            circle(at: control1, color: .orange)
                .gesture(drag(updating: $dragging1, callback: { bezier.with(control1: $0) }))
        }
    }

    private static let lineWidth: CGFloat = 4
    private static let circleSize: CGFloat = 32

    @Environment(\.pathNodeId) private var fromId: UUID
    @EnvironmentObject private var updater: Updater
    @GestureState private var dragging0: Point2?
    @GestureState private var dragging1: Point2?
}

struct ActivePathArcHandle: View {
    let arc: PathArc
    let from: Point2
    let to: Point2

    var body: some View {
        let param = arc.toParam(from: from, to: to).centerParam!
        SUPath { p in
            p.move(to: .zero)
            p.addLine(to: Point2(param.radius.width, 0))
            p.move(to: .zero)
            p.addLine(to: Point2(0, param.radius.height))
        }
        .stroke(.yellow.opacity(0.5), style: StrokeStyle(lineWidth: 4, dash: [8]))
        .frame(width: param.radius.width, height: param.radius.height)
        .rotationEffect(param.rotation, anchor: UnitPoint(x: 0, y: 0))
        .position(param.center + Vector2(param.radius.width / 2, param.radius.height / 2))
        Circle().fill(.yellow).frame(width: 8, height: 8).position(param.center)
        Circle()
            .fill(.brown.opacity(0.5))
            .frame(width: 1, height: 1)
            .scaleEffect(x: param.radius.width * 2, y: param.radius.height * 2)
            .rotationEffect(param.rotation)
            .position(param.center)
    }

    @Environment(\.pathNodeId) private var fromId: UUID
    @EnvironmentObject private var updater: Updater
    @GestureState private var dragging0: Point2?
    @GestureState private var dragging1: Point2?
}
