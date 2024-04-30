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
}

enum PathEdge {
    fileprivate typealias Impl = PathEdgeImpl
    struct Line: Impl {
        var description: String { "Line" }

        func applying(_ t: CGAffineTransform) -> Self { Self() }

        func draw(path: inout SUPath, to: Point2) {
            path.addLine(to: to)
        }
    }

    struct Arc: Impl {
        let radius: CGSize
        let rotation: Angle
        let largeArc: Bool
        let sweep: Bool

        func with(radius: CGSize) -> Self { Self(radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep) }
        func with(rotation: Angle) -> Self { Self(radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep) }
        func with(largeArc: Bool) -> Self { Self(radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep) }
        func with(sweep: Bool) -> Self { Self(radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep) }

        func toParams(from: Point2, to: Point2) -> EndpointParams {
            EndpointParams(from: from, to: to, radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep)
        }

        var description: String { "Arc(radius: \(radius.shortDescription), rotation: \(rotation.shortDescription), largeArc: \(largeArc), sweep: \(sweep))" }

        func applying(_ t: CGAffineTransform) -> Self { Self(radius: radius.applying(t), rotation: rotation, largeArc: largeArc, sweep: sweep) }

        func draw(path: inout SUPath, to: Point2) {
            guard let from = path.currentPoint else { return }
            let params = toParams(from: from, to: to).centerParams
            SUPath { $0.addRelativeArc(center: params.center, radius: 1, startAngle: params.startAngle, delta: params.deltaAngle, transform: params.transform) }
                .forEach { appendNonMove(element: $0, to: &path) }
        }
    }

    struct Bezier: Impl {
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
    }

    case line(Line)
    case arc(Arc)
    case bezier(Bezier)
}

extension PathEdge: PathEdgeImpl {
    var description: String { impl.description }

    func applying(_ t: CGAffineTransform) -> Self {
        switch self {
        case let .line(l): .line(l.applying(t))
        case let .arc(a): .arc(a.applying(t))
        case let .bezier(b): .bezier(b.applying(t))
        }
    }

    func draw(path: inout SUPath, to: Point2) { impl.draw(path: &path, to: to) }

    private var impl: Impl {
        switch self {
        case let .line(l): l
        case let .arc(a): a
        case let .bezier(b): b
        }
    }
}

// MARK: - PathSegment

fileprivate protocol Tessellatable {
    func tessellated(count: Int) -> PolyLine
}

fileprivate protocol PathSegmentImpl: Transformable, Parametrizable, Tessellatable {
    var from: Point2 { get }
    var to: Point2 { get }
    var edge: PathEdge { get }
}

enum PathSegment {
    fileprivate typealias Impl = PathSegmentImpl
    struct Arc: Impl {
        let arc: PathEdge.Arc
        let from: Point2, to: Point2

        var edge: PathEdge { .arc(arc) }
        func applying(_ t: CGAffineTransform) -> Self { Self(arc: arc.applying(t), from: from.applying(t), to: to.applying(t)) }

        func position(paramT: CGFloat) -> Point2 {
            arc.toParams(from: from, to: to).centerParams.position(paramT: paramT)
        }

        func tessellated(count: Int = 16) -> PolyLine {
            let params = arc.toParams(from: from, to: to).centerParams
            let points = (0 ... count).map { i -> Point2 in params.position(paramT: CGFloat(i) / CGFloat(count)) }
            return PolyLine(points: points)
        }
    }

    struct Bezier: Impl {
        let bezier: PathEdge.Bezier
        let from: Point2, to: Point2

        var edge: PathEdge { .bezier(bezier) }
        func applying(_ t: CGAffineTransform) -> Self { Self(bezier: bezier.applying(t), from: from.applying(t), to: to.applying(t)) }

        func position(paramT: CGFloat) -> Point2 {
            let t = (0.0 ... 1.0).clamp(paramT)
            let p0 = Vector2(from), p1 = Vector2(bezier.control0), p2 = Vector2(bezier.control1), p3 = Vector2(to)
            return Point2(pow(1 - t, 3) * p0 + 3 * pow(1 - t, 2) * t * p1 + 3 * (1 - t) * pow(t, 2) * p2 + pow(t, 3) * p3)
        }

        func tessellated(count: Int = 16) -> PolyLine {
            let points = (0 ... count).map { i in position(paramT: CGFloat(i) / CGFloat(count)) }
            return PolyLine(points: points)
        }
    }

    struct Line: Impl {
        let line: PathEdge.Line
        let from: Point2, to: Point2

        var edge: PathEdge { .line(line) }
        func applying(_ t: CGAffineTransform) -> Self { Self(line: line.applying(t), from: from.applying(t), to: to.applying(t)) }

        func position(paramT: CGFloat) -> Point2 {
            let t = (0.0 ... 1.0).clamp(paramT)
            let p0 = Vector2(from), p1 = Vector2(to)
            return Point2(p0 + (p1 - p0) * t)
        }

        func tessellated(count: Int = 16) -> PolyLine {
            let points = (0 ... count).map { i in position(paramT: CGFloat(i) / CGFloat(count)) }
            return PolyLine(points: points)
        }
    }

    case line(Line)
    case arc(Arc)
    case bezier(Bezier)

    init(from: Point2, to: Point2, edge: PathEdge) {
        switch edge {
        case let .line(line): self = .line(.init(line: line, from: from, to: to))
        case let .arc(arc): self = .arc(.init(arc: arc, from: from, to: to))
        case let .bezier(bezier): self = .bezier(.init(bezier: bezier, from: from, to: to))
        }
    }
}

extension PathSegment: PathSegmentImpl {
    private var impl: Impl {
        switch self {
        case let .line(line): line
        case let .arc(arc): arc
        case let .bezier(bezier): bezier
        }
    }

    var from: CGPoint { impl.from }
    var to: CGPoint { impl.to }
    var edge: PathEdge { impl.edge }

    func applying(_ t: CGAffineTransform) -> Self {
        switch self {
        case let .line(l): .line(l.applying(t))
        case let .arc(a): .arc(a.applying(t))
        case let .bezier(b): .bezier(b.applying(t))
        }
    }

    func position(paramT: CGFloat) -> Point2 { impl.position(paramT: paramT) }

    func tessellated(count: Int = 16) -> PolyLine { impl.tessellated(count: count) }
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

// MARK: - Path

class Path: Identifiable, ReflectedStringConvertible, Equatable {
    typealias NodeEdgePair = (node: PathNode, edge: PathEdge)

    let id: UUID
    let pairs: [NodeEdgePair]
    let isClosed: Bool
    let nodeIdToIndex: [UUID: Int]

    var nodes: [PathNode] { pairs.map { $0.node } }
    var segments: [PathSegment] { pairs.compactMap { segment(from: $0.node.id) } }

    func segment(from id: UUID) -> PathSegment? {
        guard let i = nodeIdToIndex[id] else { return nil }
        let isLast = i + 1 == pairs.count
        if isLast && !isClosed {
            return nil
        }
        let (node, edge) = pairs[i]
        let (nextNode, _) = pairs[isLast ? 0 : i + 1]
        return PathSegment(from: node.position, to: nextNode.position, edge: edge)
    }

    func pair(at i: Int) -> NodeEdgePair? {
        guard (0 ..< pairs.count).contains(i) else { return nil }
        return pairs[i]
    }

    func pair(id: UUID) -> NodeEdgePair? {
        guard let i = nodeIdToIndex[id] else { return nil }
        return pairs[i]
    }

    func pair(before: UUID) -> NodeEdgePair? {
        guard let i = nodeIdToIndex[before] else { return nil }
        if i == 0 {
            return isClosed ? pairs.last : nil
        }
        return pairs[i - 1]
    }

    func pair(after: UUID) -> NodeEdgePair? {
        guard let i = nodeIdToIndex[after] else { return nil }
        if i + 1 == pairs.count {
            return isClosed ? pairs.first : nil
        }
        return pairs[i + 1]
    }

    func node(at i: Int) -> PathNode? { pair(at: i)?.node }
    func node(id: UUID) -> PathNode? { pair(id: id)?.node }
    func node(before: UUID) -> PathNode? { pair(before: before)?.node }
    func node(after: UUID) -> PathNode? { pair(after: after)?.node }

    func edge(at i: Int) -> PathEdge? { pair(at: i)?.edge }
    func edge(id: UUID) -> PathEdge? { pair(id: id)?.edge }
    func edge(before: UUID) -> PathEdge? { pair(before: before)?.edge }
    func edge(after: UUID) -> PathEdge? { pair(after: after)?.edge }

    lazy var path: SUPath = {
        SUPath { p in
            guard let firstNode = node(at: 0) else { return }
            p.move(to: firstNode.position)
            for s in segments {
                s.edge.draw(path: &p, to: s.to)
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
        var nodeIdToIndex: [UUID: Int] = [:]
        for (i, p) in pairs.enumerated() {
            nodeIdToIndex[p.node.id] = i
        }

        self.id = id
        self.pairs = pairs
        self.isClosed = isClosed
        self.nodeIdToIndex = nodeIdToIndex
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
        pairs[i].node = nodeUpdate.node
        return with(pairs: pairs)
    }
}
