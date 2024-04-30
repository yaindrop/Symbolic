import Foundation
import SwiftUI

typealias SUPath = SwiftUI.Path

fileprivate func appendNonMove(element: SUPath.Element, to path: inout SUPath) {
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

fileprivate protocol PathEdgeImpl: CustomStringConvertible, Transformable {
    func draw(path: inout SUPath, to: Point2)
    func position(from: Point2, to: Point2, paramT t: CGFloat) -> Point2
}

enum PathEdge {
    struct Line: PathEdgeImpl {
        var description: String { "Line" }

        func applying(_ t: CGAffineTransform) -> Self { Self() }

        func draw(path: inout SUPath, to: Point2) {
            path.addLine(to: to)
        }

        func position(from: Point2, to: Point2, paramT t: CGFloat) -> Point2 {
            let t = (0.0 ... 1.0).clamp(t)
            let p0 = Vector2(from)
            let p1 = Vector2(to)
            return Point2(p0 + (p1 - p0) * t)
        }
    }

    struct Arc: PathEdgeImpl {
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
            let param = toParam(from: from, to: to).centerParam
            SUPath { $0.addRelativeArc(center: param.center, radius: 1, startAngle: param.startAngle, delta: param.deltaAngle, transform: param.transform) }
                .forEach { appendNonMove(element: $0, to: &path) }
        }

        func position(from: Point2, to: Point2, paramT t: CGFloat) -> Point2 {
            let t = (0.0 ... 1.0).clamp(t)
            let param = toParam(from: from, to: to).centerParam
            let tParam = param.with(deltaAngle: param.deltaAngle * t)
            return tParam.endpointParam.to
        }

        func toParam(from: Point2, to: Point2) -> EndpointParam {
            EndpointParam(from: from, to: to, radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep)
        }
    }

    struct Bezier: PathEdgeImpl {
        let control0: Point2
        let control1: Point2

        func with(control0: Point2) -> Self { Self(control0: control0, control1: control1) }
        func with(control1: Point2) -> Self { Self(control0: control0, control1: control1) }
        func with(offset: Vector2) -> Self { Self(control0: control0 + offset, control1: control1 + offset) }

        var description: String { "Bezier(c0: \(control0.shortDescription), c1: \(control1.shortDescription))" }

        func applying(_ t: CGAffineTransform) -> Self { Self(control0: control0.applying(t), control1: control1.applying(t)) }

        func draw(path: inout SUPath, to: Point2) {
            path.addCurve(to: to, control1: control0, control2: control1)
        }

        func position(from: Point2, to: Point2, paramT t: CGFloat) -> Point2 {
            let t = (0.0 ... 1.0).clamp(t)
            let p0 = Vector2(from)
            let p1 = Vector2(control0)
            let p2 = Vector2(control1)
            let p3 = Vector2(to)
            return Point2(pow(1 - t, 3) * p0 + 3 * pow(1 - t, 2) * t * p1 + 3 * (1 - t) * pow(t, 2) * p2 + pow(t, 3) * p3)
        }
    }

    case line(Line)
    case arc(Arc)
    case bezier(Bezier)
}

extension PathEdge: PathEdgeImpl {
    fileprivate var impl: PathEdgeImpl {
        switch self {
        case let .line(l): l
        case let .arc(a): a
        case let .bezier(b): b
        }
    }

    var description: String { impl.description }

    func applying(_ t: CGAffineTransform) -> Self {
        switch self {
        case let .line(l): .line(l.applying(t))
        case let .arc(a): .arc(a.applying(t))
        case let .bezier(b): .bezier(b.applying(t))
        }
    }

    func draw(path: inout SUPath, to: Point2) { impl.draw(path: &path, to: to) }

    func position(from: Point2, to: Point2, paramT t: CGFloat) -> Point2 { impl.position(from: from, to: to, paramT: t) }
}

// MARK: - PathNode

struct PathNode: Identifiable {
    let id: UUID
    let position: Point2

    func with(position: Point2) -> Self { Self(id: id, position: position) }
    func with(offset: Vector2) -> Self { Self(id: id, position: position + offset) }

    init(position: Point2) {
        id = UUID()
        self.position = position
    }

    private init(id: UUID, position: Point2) {
        self.id = id
        self.position = position
    }
}

// MARK: - PathSegment

struct PathSegment: Identifiable {
    struct Data: Transformable {
        let node: Point2, edge: PathEdge, prevNode: Point2?, prevEdge: PathEdge?, nextNode: Point2?, nextEdge: PathEdge?

        func applying(_ t: CGAffineTransform) -> Self {
            Self(node: node.applying(t), edge: edge.applying(t), prevNode: prevNode?.applying(t), prevEdge: prevEdge?.applying(t), nextNode: nextNode?.applying(t), nextEdge: nextEdge?.applying(t))
        }
    }

    let index: Int
    let node: PathNode
    let edge: PathEdge

    let prevNode: PathNode?
    let prevEdge: PathEdge?
    let nextNode: PathNode?
    let nextEdge: PathEdge?

    var id: UUID { node.id }
    var prevId: UUID? { prevNode?.id }
    var nextId: UUID? { nextNode?.id }

    var data: Data { Data(node: node.position, edge: edge, prevNode: prevNode?.position, prevEdge: prevEdge, nextNode: nextNode?.position, nextEdge: nextEdge) }
}

// MARK: - Path

class Path: Identifiable, ReflectedStringConvertible, Equatable {
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
            let isFirst = i == 0
            var prevNode: PathNode?, prevEdge: PathEdge?
            if !(isFirst && !isClosed) {
                (prevNode, prevEdge) = pairs[isFirst ? pairs.count - 1 : i - 1]
            }
            let (node, edge) = pair
            let (nextNode, nextEdge) = pairs[isLast ? 0 : i + 1]
            return PathSegment(index: i, node: node, edge: edge, prevNode: prevNode, prevEdge: prevEdge, nextNode: nextNode, nextEdge: nextEdge)
        }
    }

    func node(id: UUID) -> PathNode? { nodes.first { $0.id == id }}
    func segment(id: UUID) -> PathSegment? { segments.first { $0.id == id }}

    lazy var path: SUPath = {
        SUPath { p in
            guard let first = pairs.first else { return }
            p.move(to: first.0.position)
            for s in segments {
                guard let to = s.nextNode?.position else { break }
                s.edge.draw(path: &p, to: to)
            }
            if isClosed {
                p.closeSubpath()
            }
        }
    }()

    lazy var boundingRect: CGRect = { path.boundingRect }()

    lazy var hitPath: SUPath = {
        path.strokedPath(StrokeStyle(lineWidth: 12, lineCap: .round))
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

    func with(edgeUpdate: PathEvent.Update.EdgeUpdate) -> Path {
        guard let i = (pairs.firstIndex { node, _ in node.id == edgeUpdate.fromNodeId }) else { return self }
        var pairs: [NodeEdgePair] = pairs
        pairs[i].1 = edgeUpdate.edge
        return with(pairs: pairs)
    }

    func with(nodeCreate: PathEvent.Update.NodeCreate) -> Path {
        var i = 0
        if let id = nodeCreate.prevNodeId {
            guard let prevNodeIndex = (pairs.firstIndex { node, _ in node.id == id }) else { return self }
            i = prevNodeIndex + 1
        }
        var pairs: [NodeEdgePair] = pairs
        pairs.insert((nodeCreate.node, .line(PathEdge.Line())), at: i)
        return with(pairs: pairs)
    }

    func with(nodeDelete: PathEvent.Update.NodeDelete) -> Path {
        guard let i = (pairs.firstIndex { node, _ in node.id == nodeDelete.nodeId }) else { return self }
        var pairs: [NodeEdgePair] = pairs
        pairs.remove(at: i)
        return with(pairs: pairs)
    }

    func with(nodeUpdate: PathEvent.Update.NodeUpdate) -> Path {
        guard let i = (pairs.firstIndex { node, _ in node.id == nodeUpdate.node.id }) else { return self }
        var pairs: [NodeEdgePair] = pairs
        pairs[i].0 = nodeUpdate.node
        return with(pairs: pairs)
    }
}
