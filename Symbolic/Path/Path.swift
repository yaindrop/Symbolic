import Foundation
import SwiftUI

typealias SUPath = SwiftUI.Path

// MARK: - PathEdge

fileprivate protocol PathEdgeImpl: CustomStringConvertible, Transformable {}

enum PathEdge {
    fileprivate typealias Impl = PathEdgeImpl

    struct Arc: Impl {
        let radius: CGSize
        let rotation: Angle
        let largeArc: Bool
        let sweep: Bool

        func with(radius: CGSize) -> Self { .init(radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep) }
        func with(rotation: Angle) -> Self { .init(radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep) }
        func with(largeArc: Bool) -> Self { .init(radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep) }
        func with(sweep: Bool) -> Self { .init(radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep) }

        var description: String { "Arc(radius: \(radius.shortDescription), rotation: \(rotation.shortDescription), largeArc: \(largeArc), sweep: \(sweep))" }

        func applying(_ t: CGAffineTransform) -> Self { .init(radius: radius.applying(t), rotation: rotation, largeArc: largeArc, sweep: sweep) }
    }

    struct Bezier: Impl {
        let control0: Point2
        let control1: Point2

        func with(control0: Point2) -> Self { .init(control0: control0, control1: control1) }
        func with(control1: Point2) -> Self { .init(control0: control0, control1: control1) }

        func with(offset: Vector2) -> Self { .init(control0: control0 + offset, control1: control1 + offset) }
        func with(offset0: Vector2) -> Self { .init(control0: control0 + offset0, control1: control1) }
        func with(offset1: Vector2) -> Self { .init(control0: control0, control1: control1 + offset1) }

        var description: String { "Bezier(c0: \(control0.shortDescription), c1: \(control1.shortDescription))" }

        func applying(_ t: CGAffineTransform) -> Self { .init(control0: control0.applying(t), control1: control1.applying(t)) }
    }

    struct Line: Impl {
        var description: String { "Line" }

        func applying(_ t: CGAffineTransform) -> Self { .init() }
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

    private var impl: Impl {
        switch self {
        case let .line(l): l
        case let .arc(a): a
        case let .bezier(b): b
        }
    }
}

// MARK: - PathNode

struct PathNode: Identifiable {
    let id: UUID
    let position: Point2

    func with(position: Point2) -> Self { .init(id: id, position: position) }
    func with(offset: Vector2) -> Self { .init(id: id, position: position + offset) }

    init(position: Point2) {
        id = UUID()
        self.position = position
    }

    init(id: UUID, position: Point2) {
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
            segments.forEach { $0.append(to: &p) }
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

    func append(to path: inout SUPath) {
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
