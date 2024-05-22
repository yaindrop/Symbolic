import Foundation
import SwiftUI

typealias SUPath = SwiftUI.Path

protocol SUPathAppendable {
    func append(to: inout SUPath)
}

// MARK: - PathEdge

enum PathEdge {
    struct Arc {
        let radius: CGSize
        let rotation: Angle
        let largeArc: Bool
        let sweep: Bool

        func with(radius: CGSize) -> Self { .init(radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep) }
        func with(rotation: Angle) -> Self { .init(radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep) }
        func with(largeArc: Bool) -> Self { .init(radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep) }
        func with(sweep: Bool) -> Self { .init(radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep) }
    }

    struct Bezier {
        let control0: Point2
        let control1: Point2

        func with(control0: Point2) -> Self { .init(control0: control0, control1: control1) }
        func with(control1: Point2) -> Self { .init(control0: control0, control1: control1) }

        func with(offset: Vector2) -> Self { .init(control0: control0 + offset, control1: control1 + offset) }
        func with(offset0: Vector2) -> Self { .init(control0: control0 + offset0, control1: control1) }
        func with(offset1: Vector2) -> Self { .init(control0: control0, control1: control1 + offset1) }
    }

    struct Line {}

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

// MARK: Impl

fileprivate protocol PathEdgeImpl: CustomStringConvertible, Transformable, Equatable {}

extension PathEdge.Arc: PathEdgeImpl {}

extension PathEdge.Bezier: PathEdgeImpl {}

extension PathEdge.Line: PathEdgeImpl {}

extension PathEdge: PathEdgeImpl {
    fileprivate typealias Impl = any PathEdgeImpl

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

extension PathEdge: TriviallyCloneable {}

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

struct PathNode: Identifiable, Equatable {
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

extension PathNode: TriviallyCloneable {}

// MARK: - Path

class Path: Identifiable, ReflectedStringConvertible, Equatable, Cloneable, EnableCachedLazy {
    struct NodeEdgePair: TriviallyCloneable {
        var node: PathNode, edge: PathEdge

        init(_ node: PathNode, _ edge: PathEdge) {
            self.node = node
            self.edge = edge
        }
    }

    typealias PairMap = OrderedMap<UUID, NodeEdgePair>

    let id: UUID
    private(set) var pairs: PairMap
    private(set) var isClosed: Bool

    func nodeIndex(id: UUID) -> Int? { pairs.keys.firstIndex(of: id) }

    var count: Int { pairs.count }

    var nodes: [PathNode] { pairs.values.map { $0.node } }
    var segments: [PathSegment] { pairs.values.compactMap { segment(from: $0.node.id) } }

    func segment(from id: UUID) -> PathSegment? {
        guard let i = nodeIndex(id: id) else { return nil }
        let isLast = i + 1 == pairs.count
        if isLast && !isClosed {
            return nil
        }
        guard let curr = pairs[i], let next = pairs[isLast ? 0 : i + 1] else { return nil }
        return PathSegment(from: curr.node.position, to: next.node.position, edge: curr.edge)
    }

    func pair(at i: Int) -> NodeEdgePair? {
        guard (0 ..< pairs.count).contains(i) else { return nil }
        return pairs[i]
    }

    func pair(id: UUID) -> NodeEdgePair? {
        guard let i = nodeIndex(id: id) else { return nil }
        return pairs[i]
    }

    func pair(before: UUID) -> NodeEdgePair? {
        guard let i = nodeIndex(id: before) else { return nil }
        if i == 0 {
            return isClosed ? pairs.last : nil
        }
        return pairs[i - 1]
    }

    func pair(after: UUID) -> NodeEdgePair? {
        guard let i = nodeIndex(id: after) else { return nil }
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

    func isFirstNode(id: UUID) -> Bool {
        !isClosed && pairs.first?.node.id == id
    }

    func isLastNode(id: UUID) -> Bool {
        !isClosed && pairs.last?.node.id == id
    }

    func isEndingNode(id: UUID) -> Bool {
        isFirstNode(id: id) || isLastNode(id: id)
    }

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

    static func == (lhs: Path, rhs: Path) -> Bool { ObjectIdentifier(lhs) == ObjectIdentifier(rhs) }

    required init(_ path: Path) {
        id = path.id
        pairs = path.pairs
        isClosed = path.isClosed
    }

    required init(id: UUID, pairs: PairMap, isClosed: Bool) {
        self.id = id
        self.pairs = pairs
        self.isClosed = isClosed
    }

    convenience init(pairs: PairMap, isClosed: Bool) { self.init(id: UUID(), pairs: pairs, isClosed: isClosed) }
}

extension Path: SUPathAppendable {
    func append(to path: inout SUPath) {
        let _r = tracer.range("Path append to"); defer { _r() }
        path.addPath(self.path)
    }
}

// MARK: - clone with path update event

extension Path {
    func with(pairs: PairMap, isClosed: Bool? = nil) -> Self {
        .init(id: id, pairs: pairs, isClosed: isClosed ?? self.isClosed)
    }

    func update(move: PathEvent.Update.Move) {
        let _r = tracer.range("Path.update move"); defer { _r() }
        for id in pairs.keys {
            guard var pair = pairs[id] else { return }
            pair.node = pair.node.with(offset: move.offset)
            if case let .bezier(b) = pair.edge {
                pair.edge = .bezier(b.with(offset: move.offset))
            }
            pairs[id] = pair
        }
    }

    func update(breakAfter: PathEvent.Update.BreakAfter) {
        let _r = tracer.range("Path.update breakAfter"); defer { _r() }
        guard let i = nodeIndex(id: breakAfter.nodeId) else { return }
        if isClosed {
            pairs.mutateKeys { $0 = Array($0[(i + 1)...]) + Array($0[...i]) }
            isClosed = false
        } else {
            pairs.mutateKeys { $0 = Array($0[...i]) }
        }
    }

    func update(breakUntil: PathEvent.Update.BreakUntil) {
        let _r = tracer.range("Path.update breakUntil"); defer { _r() }
        guard let i = nodeIndex(id: breakUntil.nodeId) else { return }
        if isClosed {
            pairs.mutateKeys { $0 = Array($0[(i + 1)...]) + Array($0[...i]) }
            isClosed = false
        } else {
            pairs.mutateKeys { $0 = Array($0[(i + 1)...]) }
        }
    }

    func update(edgeUpdate: PathEvent.Update.EdgeUpdate) {
        let _r = tracer.range("Path.update edgeUpdate"); defer { _r() }
        pairs[edgeUpdate.fromNodeId]?.edge = edgeUpdate.edge
    }

    func update(nodeCreate: PathEvent.Update.NodeCreate) {
        let _r = tracer.range("Path.update nodeCreate"); defer { _r() }
        let prevNodeId = nodeCreate.prevNodeId, node = nodeCreate.node
        var i = 0
        if let prevNodeId {
            guard let prev = nodeIndex(id: prevNodeId) else { return }
            i = prev + 1
        }
        pairs.insert((node.id, .init(nodeCreate.node, .line(PathEdge.Line()))), at: i)
    }

    func update(nodeDelete: PathEvent.Update.NodeDelete) {
        let _r = tracer.range("Path.update nodeDelete"); defer { _r() }
        pairs.removeValue(forKey: nodeDelete.nodeId)
    }

    func update(nodeUpdate: PathEvent.Update.NodeUpdate) {
        let _r = tracer.range("Path.update nodeUpdate"); defer { _r() }
        pairs[nodeUpdate.node.id]?.node = nodeUpdate.node
    }
}
