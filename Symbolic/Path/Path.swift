import Foundation
import SwiftUI

typealias SUPath = SwiftUI.Path

protocol SUPathAppendable {
    func append(to: inout SUPath)
}

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
    }

    struct Bezier: Impl {
        let control0: Point2
        let control1: Point2

        func with(control0: Point2) -> Self { .init(control0: control0, control1: control1) }
        func with(control1: Point2) -> Self { .init(control0: control0, control1: control1) }

        func with(offset: Vector2) -> Self { .init(control0: control0 + offset, control1: control1 + offset) }
        func with(offset0: Vector2) -> Self { .init(control0: control0 + offset0, control1: control1) }
        func with(offset1: Vector2) -> Self { .init(control0: control0, control1: control1 + offset1) }
    }

    struct Line: Impl {}

    enum Case { case arc, bezier, line }
    var `case`: Case {
        switch self {
        case .arc: .arc
        case .bezier: .bezier
        case .line: .line
        }
    }

    case arc(Arc)
    case bezier(Bezier)
    case line(Line)
}

extension PathEdge: PathEdgeImpl {
    private var impl: Impl {
        switch self {
        case let .arc(a): a
        case let .bezier(b): b
        case let .line(l): l
        }
    }

    private func impl(_ transform: (Impl) -> Impl) -> Self {
        switch self {
        case let .arc(a): .arc(transform(a) as! Arc)
        case let .bezier(b): .bezier(transform(b) as! Bezier)
        case let .line(l): .line(transform(l) as! Line)
        }
    }
}

// MARK: CustomStringConvertible

extension PathEdge.Arc: CustomStringConvertible {
    var description: String { "Arc(radius: \(radius.shortDescription), rotation: \(rotation.shortDescription), largeArc: \(largeArc), sweep: \(sweep))" }
}

extension PathEdge.Bezier: CustomStringConvertible {
    var description: String { "Bezier(c0: \(control0.shortDescription), c1: \(control1.shortDescription))" }
}

extension PathEdge.Line: CustomStringConvertible {
    var description: String { "Line" }
}

extension PathEdge: CustomStringConvertible {
    var description: String { impl.description }
}

// MARK: Transformable

extension PathEdge.Arc: Transformable {
    func applying(_ t: CGAffineTransform) -> Self { .init(radius: radius.applying(t), rotation: rotation, largeArc: largeArc, sweep: sweep) }
}

extension PathEdge.Bezier: Transformable {
    func applying(_ t: CGAffineTransform) -> Self { .init(control0: control0.applying(t), control1: control1.applying(t)) }
}

extension PathEdge.Line: Transformable {
    func applying(_ t: CGAffineTransform) -> Self { .init() }
}

extension PathEdge: Transformable {
    func applying(_ t: CGAffineTransform) -> Self { impl { $0.applying(t) } }
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

class Path: Identifiable, ReflectedStringConvertible, Equatable, Cloneable {
    typealias NodeEdgePair = (node: PathNode, edge: PathEdge)

    let id: UUID
    private(set) var pairs: [NodeEdgePair]
    private(set) var isClosed: Bool
    private(set) var nodeIdToIndex: [UUID: Int]

    var count: Int { pairs.count }

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

    var path: SUPath {
        SUPath { p in
            segments.forEach { $0.append(to: &p) }
            if isClosed {
                p.closeSubpath()
            }
        }
    }

    var boundingRect: CGRect { path.boundingRect }

    var hitPath: SUPath {
        path.strokedPath(StrokeStyle(lineWidth: 12, lineCap: .round))
    }

    required init(_ path: Path) {
        id = path.id
        pairs = path.pairs
        isClosed = path.isClosed
        nodeIdToIndex = path.nodeIdToIndex
    }

    required init(id: UUID, pairs: [NodeEdgePair], isClosed: Bool) {
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

    static func == (lhs: Path, rhs: Path) -> Bool { ObjectIdentifier(lhs) == ObjectIdentifier(rhs) }
}

extension Path: SUPathAppendable {
    func append(to path: inout SUPath) {
        path.addPath(self.path)
    }
}

// MARK: - clone with path update event

extension Path {
    func with(pairs: [NodeEdgePair], isClosed: Bool? = nil) -> Self {
        .init(id: id, pairs: pairs, isClosed: isClosed ?? self.isClosed)
    }

    func update(move: PathEvent.Update.Move) {
        pairs.indices.forEach { i in
            let (node, edge) = pairs[i]
            pairs[i].node = node.with(offset: move.offset)
            if case let .bezier(b) = edge {
                pairs[i].edge = .bezier(b.with(offset: move.offset))
            }
        }
    }

    func update(breakAfter: PathEvent.Update.BreakAfter) {
        guard let i = nodeIdToIndex[breakAfter.nodeId] else { return }
        if isClosed {
            pairs = Array(pairs[(i + 1)...]) + Array(pairs[...i])
            isClosed = false
        } else {
            pairs = Array(pairs[...i])
        }
    }

    func update(breakUntil: PathEvent.Update.BreakUntil) {
        guard let i = nodeIdToIndex[breakUntil.nodeId] else { return }
        if isClosed {
            pairs = Array(pairs[(i + 1)...]) + Array(pairs[...i])
            isClosed = false
        } else {
            pairs = Array(pairs[(i + 1)...])
        }
    }

    func update(edgeUpdate: PathEvent.Update.EdgeUpdate) {
        guard let i = nodeIdToIndex[edgeUpdate.fromNodeId] else { return }
        pairs[i].edge = edgeUpdate.edge
    }

    func update(nodeCreate: PathEvent.Update.NodeCreate) {
        var i = 0
        if let id = nodeCreate.prevNodeId {
            guard let prev = nodeIdToIndex[id] else { return }
            i = prev + 1
        }
        pairs.insert((nodeCreate.node, .line(PathEdge.Line())), at: i)
    }

    func update(nodeDelete: PathEvent.Update.NodeDelete) {
        guard let i = nodeIdToIndex[nodeDelete.nodeId] else { return }
        pairs.remove(at: i)
    }

    func update(nodeUpdate: PathEvent.Update.NodeUpdate) {
        guard let i = nodeIdToIndex[nodeUpdate.node.id] else { return }
        pairs[i].node = nodeUpdate.node
    }
}
