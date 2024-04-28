import Foundation
import SwiftUI

typealias SUPath = SwiftUI.Path

func appendNonMove(element: SUPath.Element, to path: inout SUPath) {
    switch element {
    case let .curve(to, control1, control2):
        path.addCurve(to: to, control1: control1, control2: control2)
    case let .line(to):
        path.addLine(to: to)
    case let .quadCurve(to, control):
        path.addQuadCurve(to: to, control: control)
    default:
        return
    }
}

// MARK: - PathEdge

protocol PathEdgeProtocol: CustomStringConvertible, Transformable {
    func draw(path: inout SUPath, to: Point2)
    func position(from: Point2, to: Point2, at t: CGFloat) -> Point2
}

struct PathLine: PathEdgeProtocol {
    var description: String { "Line" }

    func applying(_ t: CGAffineTransform) -> Self { Self() }

    func draw(path: inout SUPath, to: Point2) {
        path.addLine(to: to)
    }

    func position(from: Point2, to: Point2, at t: CGFloat) -> Point2 {
        let t = (0.0 ... 1.0).clamp(t)
        let p0 = Vector2(from)
        let p1 = Vector2(to)
        return Point2(p0 + (p1 - p0) * t)
    }
}

struct PathArc: PathEdgeProtocol {
    let radius: CGSize
    let rotation: Angle
    let largeArc: Bool
    let sweep: Bool

    func with(radius: CGSize) -> Self { Self(radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep) }
    func with(rotation: Angle) -> Self { Self(radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep) }
    func with(largeArc: Bool) -> Self { Self(radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep) }
    func with(sweep: Bool) -> Self { Self(radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep) }

    var description: String { "Arc(radius: \(radius.shortDescription), rotation: \(rotation.shortDescription), largeArc: \(largeArc), sweep: \(sweep))" }

    func applying(_ t: CGAffineTransform) -> Self { Self(radius: radius.applying(t), rotation: rotation, largeArc: largeArc, sweep: sweep) }

    func draw(path: inout SUPath, to: Point2) {
        guard let from = path.currentPoint else { return }
        guard let param = toParam(from: from, to: to).centerParam else { return }
        SUPath { $0.addRelativeArc(center: param.center, radius: 1, startAngle: param.startAngle, delta: param.deltaAngle, transform: param.transform) }
            .forEach { appendNonMove(element: $0, to: &path) }
    }

    func position(from: Point2, to: Point2, at t: CGFloat) -> Point2 {
        let t = (0.0 ... 1.0).clamp(t)
        guard let param = toParam(from: from, to: to).centerParam else { return from }
        let tParam = param.with(deltaAngle: param.deltaAngle * t)
        return tParam.endpointParam.to
    }

    func toParam(from: Point2, to: Point2) -> ArcEndpointParam {
        ArcEndpointParam(from: from, to: to, radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep)
    }
}

struct PathBezier: PathEdgeProtocol {
    let control0: Point2
    let control1: Point2

    func with(control0: Point2) -> Self { Self(control0: control0, control1: control1) }
    func with(control1: Point2) -> Self { Self(control0: control0, control1: control1) }

    var description: String { "Bezier(c0: \(control0.shortDescription), c1: \(control1.shortDescription))" }

    func applying(_ t: CGAffineTransform) -> Self { Self(control0: control0.applying(t), control1: control1.applying(t)) }

    func draw(path: inout SUPath, to: Point2) {
        path.addCurve(to: to, control1: control0, control2: control1)
    }

    func position(from: Point2, to: Point2, at t: CGFloat) -> Point2 {
        let t = (0.0 ... 1.0).clamp(t)
        let p0 = Vector2(from)
        let p1 = Vector2(control0)
        let p2 = Vector2(control1)
        let p3 = Vector2(to)
        return Point2(pow(1 - t, 3) * p0 + 3 * pow(1 - t, 2) * t * p1 + 3 * (1 - t) * pow(t, 2) * p2 + pow(t, 3) * p3)
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

    func applying(_ t: CGAffineTransform) -> Self {
        switch self {
        case let .Line(l): return .Line(l.applying(t))
        case let .Arc(a): return .Arc(a.applying(t))
        case let .Bezier(b): return .Bezier(b.applying(t))
        }
    }

    func draw(path: inout SUPath, to: Point2) { value.draw(path: &path, to: to) }

    func position(from: Point2, to: Point2, at t: CGFloat) -> Point2 { value.position(from: from, to: to, at: t) }
}

// MARK: - PathNode

struct PathNode: Identifiable {
    let id: UUID
    let position: Point2

    func with(position: Point2) -> Self { Self(id: id, position: position) }

    init(position: Point2) {
        id = UUID()
        self.position = position
    }

    private init(id: UUID, position: Point2) {
        self.id = id
        self.position = position
    }
}

struct PathSegmentData: Transformable {
    let edge: PathEdge
    let from: Point2
    let to: Point2

    func applying(_ t: CGAffineTransform) -> Self { Self(edge: edge.applying(t), from: from.applying(t), to: to.applying(t)) }
}

struct PathSegment: Identifiable {
    static let hitPathLineWidth: CGFloat = 12

    let index: Int
    let edge: PathEdge
    let from: PathNode
    let to: PathNode

    var id: UUID { from.id }

    var data: PathSegmentData { PathSegmentData(edge: edge, from: from.position, to: to.position) }

    var hitPath: SUPath {
        SUPath { p in
            p.move(to: from.position)
            edge.draw(path: &p, to: to.position)
        }.strokedPath(StrokeStyle(lineWidth: Self.hitPathLineWidth, lineCap: .round))
    }
}

struct PathVertexData {
    let node: Point2
    let prev: PathEdge?
    let next: PathEdge?

    func applying(_ t: CGAffineTransform) -> Self { Self(node: node.applying(t), prev: prev, next: next) }
}

struct PathVertex: Identifiable {
    let index: Int
    let node: PathNode
    let prev: PathEdge?
    let next: PathEdge?

    var id: UUID { node.id }

    var data: PathVertexData { PathVertexData(node: node.position, prev: prev, next: next) }
}

// MARK: - Path

class Path: Identifiable, ReflectedStringConvertible, Equatable {
    typealias NodeEdgePair = (PathNode, PathEdge)

    let id: UUID
    let pairs: [NodeEdgePair]
    let isClosed: Bool

    var nodes: [PathNode] { pairs.map { $0.0 } }

    func node(id: UUID) -> PathNode? { nodes.first { $0.id == id }}

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

    lazy var path: SUPath = {
        var p = SUPath()
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

    lazy var hitPath: SUPath = {
        var p = SUPath()
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

    func draw(path: inout SUPath) {
        path.addPath(self.path)
    }

    static func == (lhs: Path, rhs: Path) -> Bool { ObjectIdentifier(lhs) == ObjectIdentifier(rhs) }
}

// MARK: - clone with path update event

extension Path {
    func with(pairs: [NodeEdgePair]) -> Path { Path(id: id, pairs: pairs, isClosed: isClosed) }

    func with(edgeUpdate: PathEdgeUpdate) -> Path {
        guard let i = (pairs.firstIndex { node, _ in node.id == edgeUpdate.fromNodeId }) else { return self }
        var pairs: [NodeEdgePair] = pairs
        pairs[i].1 = edgeUpdate.edge
        return with(pairs: pairs)
    }

    func with(nodeCreate: PathNodeCreate) -> Path {
        var i = 0
        if let id = nodeCreate.prevNodeId {
            guard let prevNodeIndex = (pairs.firstIndex { node, _ in node.id == id }) else { return self }
            i = prevNodeIndex + 1
        }
        var pairs: [NodeEdgePair] = pairs
        pairs.insert((nodeCreate.node, .Line(PathLine())), at: i)
        return with(pairs: pairs)
    }

    func with(nodeDelete: PathNodeDelete) -> Path {
        guard let i = (pairs.firstIndex { node, _ in node.id == nodeDelete.nodeId }) else { return self }
        var pairs: [NodeEdgePair] = pairs
        pairs.remove(at: i)
        return with(pairs: pairs)
    }

    func with(nodeUpdate: PathNodeUpdate) -> Path {
        guard let i = (pairs.firstIndex { node, _ in node.id == nodeUpdate.node.id }) else { return self }
        var pairs: [NodeEdgePair] = pairs
        pairs[i].0 = nodeUpdate.node
        return with(pairs: pairs)
    }
}
