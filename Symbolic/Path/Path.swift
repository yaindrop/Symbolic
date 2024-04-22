import Foundation
import SwiftUI

protocol PathActionProtocol: CustomStringConvertible {
    func draw(path: inout SwiftUI.Path, to: Point2)
}

struct PathLine: PathActionProtocol {
    var description: String { "Line" }

    func draw(path: inout SwiftUI.Path, to: Point2) {
        path.addLine(to: to)
    }
}

struct PathArc: PathActionProtocol {
    let radius: CGSize
    let rotation: Angle
    let largeArc: Bool
    let sweep: Bool

    var description: String { "Arc(radius: \(radius.shortDescription), rotation: \(rotation.shortDescription), largeArc: \(largeArc), sweep: \(sweep))" }

    func toParam(from: Point2, to: Point2) -> ArcEndpointParam {
        ArcEndpointParam(from: from, to: to, radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep)
    }

    func draw(path: inout SwiftUI.Path, to: Point2) {
        guard let from = path.currentPoint else { return }
        guard let param = toParam(from: from, to: to).centerParam else { return }
        print(param)
        path.addArc(center: param.center, radius: 1, startAngle: param.startAngle, endAngle: param.endAngle, clockwise: param.clockwise, transform: param.transform)
    }
}

struct PathBezier: PathActionProtocol {
    let control0: Point2
    let control1: Point2

    var description: String { "Bezier(c0: \(control0.shortDescription), c1: \(control1.shortDescription))" }

    func draw(path: inout SwiftUI.Path, to: Point2) {
        path.addCurve(to: to, control1: control0, control2: control1)
    }
}

enum PathAction: PathActionProtocol {
    case Line(PathLine)
    case Arc(PathArc)
    case Bezier(PathBezier)

    var value: PathActionProtocol {
        switch self {
        case let .Line(l): return l
        case let .Arc(a): return a
        case let .Bezier(b): return b
        }
    }

    var description: String { value.description }

    func draw(path: inout SwiftUI.Path, to: Point2) { value.draw(path: &path, to: to) }
}

struct PathVertex: Identifiable {
    let id = UUID()
    let position: Point2
}

struct PathSegment {
    let from: PathVertex
    let to: PathVertex
    let action: PathAction

    var hitPath: SwiftUI.Path {
        var p = SwiftUI.Path()
        p.move(to: from.position)
        action.draw(path: &p, to: to.position)
        return p.strokedPath(StrokeStyle(lineWidth: 10, lineCap: .round))
    }
}

typealias PathVertexActionPair = (PathVertex, PathAction)

class Path: Identifiable, ReflectedStringConvertible {
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

    lazy var path: SwiftUI.Path = {
        print(self)
        var p = SwiftUI.Path()
        guard let first = pairs.first else { return p }
        p.move(to: first.0.position)
        for s in segments {
            s.action.draw(path: &p, to: s.to.position)
        }
        if isClosed {
            p.closeSubpath()
        }
        return p
    }()

    lazy var boundingRect: CGRect = { path.boundingRect }()

    lazy var hitPath: SwiftUI.Path = {
        var p = SwiftUI.Path()
        for s in segments {
            p.addPath(s.hitPath)
        }
        return p
    }()

    private init(id: UUID, pairs: [PathVertexActionPair], isClosed: Bool) {
        self.id = id
        self.pairs = pairs
        self.isClosed = isClosed
    }

    convenience init(pairs: [PathVertexActionPair], isClosed: Bool) { self.init(id: UUID(), pairs: pairs, isClosed: isClosed) }

    func draw(path: inout SwiftUI.Path) {
        path.addPath(self.path)
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
            ForEach(segments, id: \.from.id) { s in s.hitPath.fill(.blue.opacity(0.5)) }
            ForEach(arcs, id: \.0.id) { v, n, arc in
                let param = arc.toParam(from: v.position, to: n.position).centerParam!
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
