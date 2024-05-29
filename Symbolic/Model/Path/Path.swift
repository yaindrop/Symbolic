import Foundation
import SwiftUI

typealias SUPath = SwiftUI.Path

protocol SUPathAppendable {
    func append(to: inout SUPath)
}

// MARK: - PathEdge

struct PathEdge: Equatable {
    let control0: Vector2
    let control1: Vector2

    var isLine: Bool { control0 == .zero && control1 == .zero }

    func with(control0: Vector2) -> Self { .init(control0: control0, control1: control1) }
    func with(control1: Vector2) -> Self { .init(control0: control0, control1: control1) }

    init(control0: Vector2 = .zero, control1: Vector2 = .zero) {
        self.control0 = control0
        self.control1 = control1
    }
}

// MARK: CustomStringConvertible

extension PathEdge: CustomStringConvertible {
    var description: String { "PathEdge(c0: \(control0.shortDescription), c1: \(control1.shortDescription))" }
}

// MARK: Transformable

extension PathEdge: Transformable {
    func applying(_ t: CGAffineTransform) -> Self { .init(control0: control0.applying(t), control1: control1.applying(t)) }
}

// MARK: - PathNode

struct PathNode: Identifiable, Equatable {
    let id: UUID
    let position: Point2

    func with(position: Point2) -> Self { .init(id: id, position: position) }
    func with(offset: Vector2) -> Self { .init(id: id, position: position + offset) }
}

extension PathNode: TriviallyCloneable {}

// MARK: - Path

class Path: Identifiable, ReflectedStringConvertible, Equatable, Cloneable, EnableCachedLazy {
    struct NodeEdgePair: TriviallyCloneable {
        var node: PathNode, edge: PathEdge

        var id: UUID { node.id }

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

    var firstNode: PathNode { pairs.first!.node }

    var lastNode: PathNode { pairs.last!.node }

    var segments: [PathSegment] { pairs.values.compactMap { segment(from: $0.node.id) } }

    func segment(from id: UUID) -> PathSegment? {
        guard let i = nodeIndex(id: id) else { return nil }
        let isLast = i + 1 == pairs.count
        if isLast && !isClosed {
            return nil
        }
        guard let curr = pairs[i], let next = pairs[isLast ? 0 : i + 1] else { return nil }
        return PathSegment(edge: curr.edge, from: curr.node.position, to: next.node.position)
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

    func isFirstEndingNode(id: UUID) -> Bool { !isClosed && firstNode.id == id }

    func isLastEndingNode(id: UUID) -> Bool { !isClosed && lastNode.id == id }

    func isEndingNode(id: UUID) -> Bool { isFirstEndingNode(id: id) || isLastEndingNode(id: id) }

    func mergableNode(id: UUID) -> PathNode? {
        guard let node = node(id: id) else { return nil }
        if isFirstEndingNode(id: id) {
            return node.position == lastNode.position ? lastNode : nil
        } else if isLastEndingNode(id: id) {
            return node.position == firstNode.position ? firstNode : nil
        }
        return nil
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

    func hitPath(width: Scalar) -> SUPath {
        path.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round))
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
            pairs[id] = pair
        }
    }

    func update(nodeCreate: PathEvent.Update.NodeCreate) {
        let _r = tracer.range("Path.update nodeCreate"); defer { _r() }
        let prevNodeId = nodeCreate.prevNodeId, node = nodeCreate.node
        var i = 0
        if let prevNodeId {
            guard let prev = nodeIndex(id: prevNodeId) else { return }
            i = prev + 1
        }
        pairs.insert((node.id, .init(nodeCreate.node, .init(control0: .zero, control1: .zero))), at: i)
    }

    func update(nodeDelete: PathEvent.Update.NodeDelete) {
        let _r = tracer.range("Path.update nodeDelete"); defer { _r() }
        pairs.removeValue(forKey: nodeDelete.nodeId)
    }

    func update(nodeUpdate: PathEvent.Update.NodeUpdate) {
        let _r = tracer.range("Path.update nodeUpdate"); defer { _r() }
        pairs[nodeUpdate.node.id]?.node = nodeUpdate.node
    }

    func update(edgeUpdate: PathEvent.Update.EdgeUpdate) {
        let _r = tracer.range("Path.update edgeUpdate"); defer { _r() }
        pairs[edgeUpdate.fromNodeId]?.edge = edgeUpdate.edge
    }

    func update(merge: PathEvent.Compound.Merge, mergedPath: Path) {
        let endingNodeId = merge.endingNodeId, mergedEndingNodeId = merge.mergedEndingNodeId
        let _r = tracer.range("Path.update move"); defer { _r() }
        guard let endingNode = node(id: endingNodeId),
              let mergedEndingNode = mergedPath.node(id: mergedEndingNodeId),
              isEndingNode(id: endingNodeId),
              mergedPath.isEndingNode(id: mergedEndingNodeId),
              endingNodeId != mergedEndingNodeId else { return }
        let mergePosition = endingNode.position == mergedEndingNode.position
        if mergedPath == self {
            if mergePosition {
                pairs.removeValue(forKey: lastNode.id)
            }
            isClosed = true
            return
        }
//        let reversed = isLastEndingNode(id: endingNodeId) && mergedPath.isLastEndingNode(id: mergedEndingNodeId)
//            || isFirstEndingNode(id: endingNodeId) && mergedPath.isFirstEndingNode(id: mergedEndingNodeId)
//        let mergedPairs = reversed ? mergedPath.pairs.values.reversed() : mergedPath.pairs.values
//        let prepend = isFirstEndingNode(id: endingNodeId)
//        for pair in mergedPairs {
//            if prepend {
//                pairs.insert((pair.id, pair), at: 0)
//            } else {
//                pairs.append((pair.id, pair))
//            }
//        }
    }

    func update(nodeBreak: PathEvent.Compound.NodeBreak) -> Path? {
        let nodeId = nodeBreak.nodeId, newNodeId = nodeBreak.newNodeId, newPathId = nodeBreak.newPathId
        let _r = tracer.range("Path.update nodeBreak"); defer { _r() }
        guard let i = nodeIndex(id: nodeId),
              let node = node(id: nodeId),
              let edge = segment(from: nodeId)?.edge else { return nil }
        let newPair = NodeEdgePair(.init(id: newNodeId, position: node.position), edge)
        if isClosed {
            pairs.mutateKeys { $0 = Array($0[(i + 1)...] + $0[...i]) }
            pairs.insert((newNodeId, newPair), at: 0)
            isClosed = false
            return nil
        } else {
            var newPathPairs = pairs
            pairs.mutateKeys { $0 = Array($0[...i]) }
            newPathPairs.mutateKeys { $0 = Array($0[(i + 1)...]) }
            newPathPairs.insert((newNodeId, newPair), at: 0)
            return .init(id: newPathId, pairs: newPathPairs, isClosed: false)
        }
    }

    func update(edgeBreak: PathEvent.Compound.EdgeBreak) -> Path? {
        let nodeId = edgeBreak.fromNodeId, newPathId = edgeBreak.newPathId
        let _r = tracer.range("Path.update edgeBreak"); defer { _r() }
        guard let i = nodeIndex(id: nodeId) else { return nil }
        if isClosed {
            pairs.mutateKeys { $0 = Array($0[(i + 1)...] + $0[...i]) }
            isClosed = false
            return nil
        } else {
            var newPathPairs = pairs
            pairs.mutateKeys { $0 = Array($0[...i]) }
            newPathPairs.mutateKeys { $0 = Array($0[(i + 1)...]) }
            return .init(id: newPathId, pairs: newPathPairs, isClosed: false)
        }
    }
}
