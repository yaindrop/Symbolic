import SwiftUI

typealias SUPath = SwiftUI.Path

protocol SUPathAppendable {
    func append(to: inout SUPath)
}

// MARK: - PathEdge

struct PathEdge: Equatable, Codable {
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
    var description: String {
        "Edge(c0: \(control0.shortDescription), c1: \(control1.shortDescription))"
    }
}

// MARK: Transformable

extension PathEdge: Transformable {
    func applying(_ t: CGAffineTransform) -> Self { .init(control0: control0.applying(t), control1: control1.applying(t)) }
}

// MARK: - PathNode

struct PathNode: Identifiable, Equatable, Codable {
    let id: UUID
    let position: Point2

    func with(position: Point2) -> Self { .init(id: id, position: position) }
    func with(offset: Vector2) -> Self { .init(id: id, position: position + offset) }
}

extension PathNode: TriviallyCloneable {}

// MARK: CustomStringConvertible

extension PathNode: CustomStringConvertible {
    var description: String {
        "Node(id: \(id), position: \(position))"
    }
}

// MARK: - Path

class Path: Identifiable, Cloneable, Codable {
    struct NodeEdgePair: Equatable, TriviallyCloneable, Codable {
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

    required init(id: UUID, pairs: PairMap, isClosed: Bool) {
        self.id = id
        self.pairs = pairs
        self.isClosed = isClosed
    }

    // MARK: Cloneable

    required init(_ path: Path) {
        id = path.id
        pairs = path.pairs
        isClosed = path.isClosed
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case id, pairs, isClosed
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(pairs.values, forKey: .pairs)
        try container.encode(isClosed, forKey: .isClosed)
    }

    required init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        pairs = try .init(values.decode([NodeEdgePair].self, forKey: .pairs)) { $0.id }
        isClosed = try values.decode(Bool.self, forKey: .isClosed)
    }
}

extension Path: ReflectedStringConvertible {}

extension Path {
    var count: Int { pairs.count }

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
}

// MARK: node getters

extension Path {
    func nodeIndex(id: UUID) -> Int? { pairs.keys.firstIndex(of: id) }

    var nodes: [PathNode] { pairs.values.map { $0.node } }

    var firstNode: PathNode { pairs.first!.node }

    var lastNode: PathNode { pairs.last!.node }

    func node(at i: Int) -> PathNode? { pair(at: i)?.node }

    func node(id: UUID) -> PathNode? { pair(id: id)?.node }

    func node(before: UUID) -> PathNode? { pair(before: before)?.node }

    func node(after: UUID) -> PathNode? { pair(after: after)?.node }

    // predicates

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
}

// MARK: segment and pair getters

extension Path {
    var segments: [PathSegment] { pairs.values.compactMap { segment(from: $0.node.id) } }

    func segment(from id: UUID) -> PathSegment? {
        guard let i = nodeIndex(id: id) else { return nil }
        let isLast = i + 1 == pairs.count
        if isLast, !isClosed {
            return nil
        }
        guard let curr = pairs[i], let next = pairs[isLast ? 0 : i + 1] else { return nil }
        return PathSegment(edge: curr.edge, from: curr.node.position, to: next.node.position)
    }

    func pair(at i: Int) -> NodeEdgePair? {
        guard pairs.indices.contains(i) else { return nil }
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
}

// MARK: subpath

extension Path {
    func indices(from i: Int, to j: Int? = nil) -> [Int] {
        guard pairs.indices.contains(i) else { return [] }
        var result: [Int] = []
        var curr = i
        repeat {
            var next: Int? = curr + 1
            if next == pairs.count {
                next = isClosed ? 0 : nil
            }
            result.append(curr)
            if curr == j { break }
            guard let next else { break }
            curr = next
        } while curr != i
        return result
    }

    func subpath(from i: Int, to j: Int) -> Self? {
        guard let pairs = indices(from: i, to: j).completeMap({ pairs[$0] }) else { return nil }
        guard pairs.count > 1 else { return nil }
        return .init(id: UUID(), pairs: .init(pairs) { $0.id }, isClosed: pairs.count == self.pairs.count)
    }

    func continuousNodeIndexPairs(nodeIds: Set<UUID>) -> [Pair<Int, Int>] {
        guard !nodeIds.isEmpty else { return [] }
        let initial = isClosed ? pairs.values.firstIndex { !nodeIds.contains($0.id) } : 0
        guard let initial else { return [.init(first: 0, second: count - 1)] }
        var result: [Pair<Int, Int>] = []
        var startIndex: Int?

        let indices = indices(from: initial)
        for (i, next) in zip(indices, indices.shifted(by: 1)) {
            guard let pair = pairs[i] else { return [] }
            if nodeIds.contains(pair.id) {
                let start = startIndex ?? i
                if startIndex == nil {
                    startIndex = i
                }
                let nextPair = next.map { pairs[$0] }
                if nextPair == nil || !nodeIds.contains(nextPair!.id) {
                    result.append(.init(first: start, second: i))
                    startIndex = nil
                }
            }
        }
        return result
    }
}

// MARK: EquatableBy

extension Path: EquatableBy {
    var equatableBy: some Equatable { ObjectIdentifier(self) }
}

// MARK: SUPathAppendable

extension Path: SUPathAppendable {
    func append(to path: inout SUPath) {
        let _r = tracer.range("Path append to"); defer { _r() }
        path.addPath(self.path)
    }
}

// MARK: CustomStringConvertible

extension Path.NodeEdgePair: CustomStringConvertible {
    var description: String {
        "(\(node), \(edge))"
    }
}

extension Path: CustomStringConvertible {
    var description: String {
        "Path(id: \(id), pairs: \(pairs.values), isClosed: \(isClosed))"
    }
}

// MARK: - handle events

extension Path {
    func with(pairs: PairMap, isClosed: Bool? = nil) -> Self {
        .init(id: id, pairs: pairs, isClosed: isClosed ?? self.isClosed)
    }

    func update(moveOffset: Vector2) {
        let _r = tracer.range("Path.update move"); defer { _r() }
        for id in pairs.keys {
            guard var pair = pairs[id] else { return }
            pair.node = pair.node.with(offset: moveOffset)
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

    func update(merge: PathEvent.Merge, mergedPath: Path) {
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

    func update(nodeBreak: PathEvent.NodeBreak) -> Path? {
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

    func update(edgeBreak: PathEvent.EdgeBreak) -> Path? {
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

    func update(setNodeType: PathPropertyEvent.Update.SetNodeType) {
        for nodeId in setNodeType.nodeIds {
            guard let prev = pair(before: nodeId), let curr = pair(id: nodeId) else { continue }
            switch setNodeType.nodeType {
            case .locked:
                pairs[nodeId]?.edge = curr.edge.with(control0: prev.edge.control1.with(length: -curr.edge.control0.length))
            case .mirrored:
                pairs[nodeId]?.edge = curr.edge.with(control0: -prev.edge.control1)
            default: break
            }
        }
    }

    func update(setEdgeType: PathPropertyEvent.Update.SetEdgeType) {
        for fromNodeId in setEdgeType.fromNodeIds {
            switch setEdgeType.edgeType {
            case .line:
                pairs[fromNodeId]?.edge = .init(control0: .zero, control1: .zero)
            default: break
            }
        }
    }
}
