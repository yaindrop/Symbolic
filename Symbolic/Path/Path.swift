import Foundation
import SwiftUI

struct PathLine {
    func draw(path: inout SwiftUI.Path, to: Point2) {
        path.addLine(to: to)
    }
}

struct PathArc {
    let radius: CGSize
    let rotation: Angle
    let largeArc: Bool
    let sweep: Bool

    func toParam(from: Point2, to: Point2) -> ArcEndpointParam {
        ArcEndpointParam(from: from, to: to, radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep)
    }

    func draw(path: inout SwiftUI.Path, to: Point2) {
        guard let from = path.currentPoint else { return }
        var endPointparam = toParam(from: from, to: to)
        guard let param = endPointparam.centerParam?.value else { return }
        print(param)
        path.addArc(center: param.center, radius: 1, startAngle: param.startAngle, endAngle: param.endAngle, clockwise: param.clockwise, transform: param.transform)
    }
}

struct PathBezier {
    let control0: Point2
    let control1: Point2

    func draw(path: inout SwiftUI.Path, to: Point2) {
        path.addCurve(to: to, control1: control0, control2: control1)
    }
}

enum PathAction {
    case Line(PathLine)
    case Arc(PathArc)
    case Bezier(PathBezier)
    func draw(path: inout SwiftUI.Path, to: Point2) {
        switch self {
        case let .Line(l):
            l.draw(path: &path, to: to)
        case let .Arc(a):
            a.draw(path: &path, to: to)
        case let .Bezier(b):
            b.draw(path: &path, to: to)
        }
    }
}

struct PathVertex: Identifiable {
    let id = UUID()
    let position: Point2
}

struct PathSegment {
    let from: PathVertex
    let to: PathVertex
    let action: PathAction
}

typealias PathVertexActionPair = (PathVertex, PathAction)

struct Path: Identifiable {
    let id: UUID
    let pairs: [PathVertexActionPair]
    let isClosed: Bool

    var vertices: [PathVertex] { pairs.map { $0.0 } }

    var segments: [PathSegment] {
        pairs.enumerated().compactMap { i, pair in
            let (v, action) = pair
            let nextIndex = i + 1 == pairs.count ? 0 : i + 1
            let next = pairs[nextIndex].0
            if !isClosed && nextIndex == 0 {
                return nil
            }
            return PathSegment(from: v, to: next, action: action)
        }
    }

    init(pairs: [PathVertexActionPair], isClosed: Bool) {
        id = UUID()
        self.pairs = pairs
        self.isClosed = isClosed
    }

    private init(id: UUID, pairs: [PathVertexActionPair], isClosed: Bool) {
        self.id = id
        self.pairs = pairs
        self.isClosed = isClosed
    }

    func draw(path: inout SwiftUI.Path) {
        print(self)
        guard let first = pairs.first else { return }
        path.move(to: first.0.position)
        for s in segments {
            s.action.draw(path: &path, to: s.to.position)
        }
        if isClosed {
            path.closeSubpath()
        }
    }

    func vertexViews() -> some View {
        ForEach(vertices, id: \.id) { v in
            Circle().fill(.blue.opacity(0.5)).frame(width: 4, height: 4).position(v.position)
        }
    }

    func controlViews() -> some View {
        let arcs = segments.compactMap { s in if case let .Arc(arc) = s.action { (s.from, s.to, arc) } else { nil } }
        let beziers = segments.compactMap { s in if case let .Bezier(bezier) = s.action { (s.from, s.to, bezier) } else { nil } }
        return Group {
            ForEach(arcs, id: \.0.id) { v, n, arc in
                var endPointParam = arc.toParam(from: v.position, to: n.position)
                let param = endPointParam.centerParam!.value
                SwiftUI.Path { p in
                    p.move(to: .zero)
                    p.addLine(to: Point2(param.radius.width, 0))
                    p.move(to: .zero)
                    p.addLine(to: Point2(0, param.radius.height))
                }
                .stroke(.yellow.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2]))
                .frame(width: param.radius.width, height: param.radius.height)
                .rotationEffect(param.rotation, anchor: UnitPoint(x: 0, y: 0))
                .position(param.center + Vector2(param.radius.width / 2, param.radius.height / 2))
                Circle().fill(.yellow).frame(width: 4, height: 4).position(param.center)
                Circle()
                    .fill(.brown.opacity(0.5))
                    .frame(width: 1, height: 1)
                    .scaleEffect(x: param.radius.width * 2, y: param.radius.height * 2)
                    .rotationEffect(param.rotation)
                    .position(param.center)
            }
            ForEach(beziers, id: \.0.id) { v, n, bezier in
                SwiftUI.Path { p in
                    p.move(to: v.position)
                    p.addLine(to: bezier.control0)
                }.stroke(.green.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2]))
                SwiftUI.Path { p in
                    p.move(to: n.position)
                    p.addLine(to: bezier.control1)
                }.stroke(.orange.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2]))
                Circle()
                    .fill(.green)
                    .frame(width: 4, height: 4)
                    .position(bezier.control0)
                Circle()
                    .fill(.orange)
                    .frame(width: 4, height: 4)
                    .position(bezier.control1)
            }
        }
    }
}

extension Path {
    func actionUpdated(actionUpdate: PathActionUpdate) -> Path {
        guard let i = (pairs.firstIndex { vertex, _ in vertex.id == actionUpdate.fromVertexId }) else { return self }
        var pairs: [PathVertexActionPair] = pairs
        pairs[i].1 = actionUpdate.action
        return Path(id: id, pairs: pairs, isClosed: isClosed)
    }

    func vertexCreated(vertexCreate: PathVertexCreate) -> Path {
        var i = 0
        if let id = vertexCreate.prevVertexId {
            guard let prevVertexIndex = (pairs.firstIndex { vertex, _ in vertex.id == id }) else { return self }
            i = prevVertexIndex + 1
        }
        var pairs: [PathVertexActionPair] = pairs
        pairs.insert((vertexCreate.vertex, .Line(PathLine())), at: i)
        return Path(id: id, pairs: pairs, isClosed: isClosed)
    }

    func vertexDeleted(vertexDelete: PathVertexDelete) -> Path {
        guard let i = (pairs.firstIndex { vertex, _ in vertex.id == vertexDelete.vertexId }) else { return self }
        var pairs: [PathVertexActionPair] = pairs
        pairs.remove(at: i)
        return Path(id: id, pairs: pairs, isClosed: isClosed)
    }

    func vertexUpdated(vertexUpdate: PathVertexUpdate) -> Path {
        guard let i = (pairs.firstIndex { vertex, _ in vertex.id == vertexUpdate.vertex.id }) else { return self }
        var pairs: [PathVertexActionPair] = pairs
        pairs[i].0 = vertexUpdate.vertex
        return Path(id: id, pairs: pairs, isClosed: isClosed)
    }
}
