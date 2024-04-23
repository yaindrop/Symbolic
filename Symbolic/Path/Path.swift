import Foundation
import SwiftUI

// MARK: - PathEdge

protocol PathEdgeProtocol: CustomStringConvertible {
    func draw(path: inout SwiftUI.Path, to: Point2)
}

struct PathLine: PathEdgeProtocol {
    var description: String { "Line" }

    func draw(path: inout SwiftUI.Path, to: Point2) {
        path.addLine(to: to)
    }
}

struct PathArc: PathEdgeProtocol {
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

struct PathBezier: PathEdgeProtocol {
    let control0: Point2
    let control1: Point2

    var description: String { "Bezier(c0: \(control0.shortDescription), c1: \(control1.shortDescription))" }

    func draw(path: inout SwiftUI.Path, to: Point2) {
        path.addCurve(to: to, control1: control0, control2: control1)
    }
}

enum PathEdge: PathEdgeProtocol {
    case Line(PathLine)
    case Arc(PathArc)
    case Bezier(PathBezier)

    var value: PathEdgeProtocol {
        switch self {
        case let .Line(l): return l
        case let .Arc(a): return a
        case let .Bezier(b): return b
        }
    }

    var description: String { value.description }

    func draw(path: inout SwiftUI.Path, to: Point2) { value.draw(path: &path, to: to) }
}

// MARK: - PathNode

struct PathNode: Identifiable {
    let id = UUID()
    let position: Point2
}

struct PathSegment: Identifiable {
    let index: Int
    let edge: PathEdge
    let from: PathNode
    let to: PathNode

    var id: UUID { from.id }

    var hitPath: SwiftUI.Path {
        var p = SwiftUI.Path()
        p.move(to: from.position)
        edge.draw(path: &p, to: to.position)
        return p.strokedPath(StrokeStyle(lineWidth: 10, lineCap: .round))
    }
}

struct PathVertex: Identifiable {
    let index: Int
    let node: PathNode
    let prev: PathEdge?
    let next: PathEdge?

    var id: UUID { node.id }
}

// MARK: - Path

class Path: Identifiable, ReflectedStringConvertible {
    typealias NodeEdgePair = (PathNode, PathEdge)

    let id: UUID
    let pairs: [NodeEdgePair]
    let isClosed: Bool

    var nodes: [PathNode] { pairs.map { $0.0 } }

    var segments: [PathSegment] {
        pairs.enumerated().compactMap { i, pair in
            let isLast = i + 1 == pairs.count
            if isLast && !isClosed {
                return nil
            }
            let (node, edge) = pair
            let (nextNode, _) = pairs[isLast ? 0 : i + 1]
            return PathSegment(index: i, edge: edge, from: node, to: nextNode)
        }
    }

    var vertices: [PathVertex] {
        pairs.enumerated().compactMap { i, pair in
            let (node, edge) = pair
            var prevEdge: PathEdge?
            var nextEdge: PathEdge?
            if isClosed {
                prevEdge = pairs[i == 0 ? pairs.count - 1 : i - 1].1
                nextEdge = edge
            } else {
                if i > 0 { prevEdge = pairs[i - 1].1 }
                if i + 1 < pairs.count { nextEdge = edge }
            }
            return PathVertex(index: i, node: node, prev: prevEdge, next: nextEdge)
        }
    }

    lazy var path: SwiftUI.Path = {
        print(self)
        var p = SwiftUI.Path()
        guard let first = pairs.first else { return p }
        p.move(to: first.0.position)
        for s in segments {
            s.edge.draw(path: &p, to: s.to.position)
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

    private init(id: UUID, pairs: [NodeEdgePair], isClosed: Bool) {
        self.id = id
        self.pairs = pairs
        self.isClosed = isClosed
    }

    convenience init(pairs: [NodeEdgePair], isClosed: Bool) { self.init(id: UUID(), pairs: pairs, isClosed: isClosed) }

    func draw(path: inout SwiftUI.Path) {
        path.addPath(self.path)
    }

    func nodeViews() -> some View {
        ForEach(nodes, id: \.id) { v in
            Circle().fill(.blue.opacity(0.5)).frame(width: 4, height: 4).position(v.position)
        }
    }

    func controlViews() -> some View {
        let arcs = segments.compactMap { s in if case let .Arc(arc) = s.edge { (s.from, s.to, arc) } else { nil } }
        let beziers = segments.compactMap { s in if case let .Bezier(bezier) = s.edge { (s.from, s.to, bezier) } else { nil } }
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

// MARK: - path event handlers

extension Path {
    func edgeUpdated(edgeUpdate: PathEdgeUpdate) -> Path {
        guard let i = (pairs.firstIndex { node, _ in node.id == edgeUpdate.fromNodeId }) else { return self }
        var pairs: [NodeEdgePair] = pairs
        pairs[i].1 = edgeUpdate.edge
        return Path(id: id, pairs: pairs, isClosed: isClosed)
    }

    func nodeCreated(nodeCreate: PathNodeCreate) -> Path {
        var i = 0
        if let id = nodeCreate.prevNodeId {
            guard let prevNodeIndex = (pairs.firstIndex { node, _ in node.id == id }) else { return self }
            i = prevNodeIndex + 1
        }
        var pairs: [NodeEdgePair] = pairs
        pairs.insert((nodeCreate.node, .Line(PathLine())), at: i)
        return Path(id: id, pairs: pairs, isClosed: isClosed)
    }

    func nodeDeleted(nodeDelete: PathNodeDelete) -> Path {
        guard let i = (pairs.firstIndex { node, _ in node.id == nodeDelete.nodeId }) else { return self }
        var pairs: [NodeEdgePair] = pairs
        pairs.remove(at: i)
        return Path(id: id, pairs: pairs, isClosed: isClosed)
    }

    func nodeUpdated(nodeUpdate: PathNodeUpdate) -> Path {
        guard let i = (pairs.firstIndex { node, _ in node.id == nodeUpdate.node.id }) else { return self }
        var pairs: [NodeEdgePair] = pairs
        pairs[i].0 = nodeUpdate.node
        return Path(id: id, pairs: pairs, isClosed: isClosed)
    }
}
