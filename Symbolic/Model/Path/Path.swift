import SwiftUI

typealias SUPath = SwiftUI.Path

protocol SUPathAppendable {
    func append(to: inout SUPath)
}

// MARK: - Path

struct Path: Codable, Equatable {
    typealias NodeMap = OrderedMap<UUID, PathNode>

    var nodeMap: NodeMap
    var isClosed: Bool

    init(nodeMap: NodeMap, isClosed: Bool) {
        self.nodeMap = nodeMap
        self.isClosed = isClosed
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case nodeIds, nodes, isClosed
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodeIds, forKey: .nodeIds)
        try container.encode(nodes, forKey: .nodes)
        try container.encode(isClosed, forKey: .isClosed)
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        nodeMap = .init()
        isClosed = try values.decode(Bool.self, forKey: .isClosed)

        let nodeIds = try values.decode([UUID].self, forKey: .nodeIds)
        let nodes = try values.decode([PathNode].self, forKey: .nodes)
        assert(nodeIds.count == nodes.count)
        for i in nodeIds.indices {
            nodeMap[nodeIds[i]] = nodes[i]
        }
    }
}

extension Path: ReflectedStringConvertible {}

extension Path {
    var count: Int { nodeMap.count }

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

// MARK: node

extension Path {
    var nodeIds: [UUID] { nodeMap.keys }

    var nodes: [PathNode] { nodeMap.values }

    var firstNode: PathNode { nodeMap.first! }

    var lastNode: PathNode { nodeMap.last! }

    func node(at i: Int) -> PathNode? { nodeMap[i] }

    func node(id: UUID) -> PathNode? { nodeMap[id] }

    func nodeIndex(id: UUID) -> Int? { nodeMap.index(of: id) }

    func nodeId(at i: Int) -> UUID? { nodeIds.indices.contains(i) ? nodeIds[i] : nil }

    func nodeId(before: UUID) -> UUID? {
        guard let i = nodeIndex(id: before) else { return nil }
        return i > 0
            ? nodeIds[i - 1]
            : isClosed ? nodeIds.last : nil
    }

    func nodeId(after: UUID) -> UUID? {
        guard let i = nodeIndex(id: after) else { return nil }
        return i < nodeMap.count - 1
            ? nodeIds[i + 1]
            : isClosed ? nodeIds.first : nil
    }

    func nodeId(closestTo point: Point2) -> UUID? {
        var result: (id: UUID, distance: Scalar)?
        for nodeId in nodeIds {
            guard let node = node(id: nodeId) else { continue }
            let distance = node.position.distance(to: point)
            if distance < result?.distance ?? .infinity {
                result = (nodeId, distance)
            }
        }
        return result?.id
    }

    var segments: [PathSegment] { nodeIds.compactMap { segment(fromId: $0) } }

    func segment(fromId: UUID) -> PathSegment? {
        guard let toId = nodeId(after: fromId),
              let from = node(id: fromId),
              let to = node(id: toId) else { return nil }
        return PathSegment(from: from, to: to)
    }

    func segmentId(closestTo point: Point2) -> UUID? {
        var result: (id: UUID, distance: Scalar)?
        for nodeId in nodeIds {
            guard let segment = segment(fromId: nodeId) else { continue }
            let polyline = segment.tessellated()
            let (_, distance) = polyline.approxPathParamT(closestTo: point)
            if distance < result?.distance ?? .infinity {
                result = (nodeId, distance)
            }
        }
        return result?.id
    }

    // predicates

    func isFirstEndingNode(id: UUID) -> Bool { !isClosed && nodeIds.first == id }

    func isLastEndingNode(id: UUID) -> Bool { !isClosed && nodeIds.last == id }

    func isEndingNode(id: UUID) -> Bool { isFirstEndingNode(id: id) || isLastEndingNode(id: id) }

    func mergableNodeId(id: UUID) -> UUID? {
        guard let node = node(id: id) else { return nil }
        if isFirstEndingNode(id: id) {
            return node.position == lastNode.position ? nodeIds.last : nil
        } else if isLastEndingNode(id: id) {
            return node.position == firstNode.position ? nodeIds.first : nil
        }
        return nil
    }
}

// MARK: subpath

extension Path {
    func indices(from i: Int, to j: Int? = nil) -> [Int] {
        guard nodeMap.indices.contains(i) else { return [] }
        var result: [Int] = []
        var curr = i
        repeat {
            var next: Int? = curr + 1
            if next == nodeMap.count {
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
        guard let nodeIds = indices(from: i, to: j).completeMap({ nodeIds[$0] }) else { return nil }
        guard nodeIds.count > 1 else { return nil }
        let nodeMap = NodeMap(keys: nodeIds) { self.nodeMap[$0]! }
        return .init(nodeMap: nodeMap, isClosed: isClosed && nodeMap.count == self.nodeMap.count)
    }

    func continuousNodeIndexPairs(nodeIds: Set<UUID>) -> [Pair<Int, Int>] {
        guard !nodeIds.isEmpty else { return [] }
        let initial = isClosed ? self.nodeIds.firstIndex { !nodeIds.contains($0) } : 0
        guard let initial else { return [.init(first: 0, second: count - 1)] }
        var result: [Pair<Int, Int>] = []
        var startIndex: Int?

        let indices = indices(from: initial)
        for (i, next) in zip(indices, indices.shifted(by: 1)) {
            let nodeId = self.nodeIds[i]
            if nodeIds.contains(nodeId) {
                let start = startIndex ?? i
                if startIndex == nil {
                    startIndex = i
                }
                let nextNodeId = next.map { self.nodeIds[$0] }
                if nextNodeId == nil || !nodeIds.contains(nextNodeId!) {
                    result.append(.init(first: start, second: i))
                    startIndex = nil
                }
            }
        }
        return result
    }
}

// MARK: EquatableBy

extension Path: Transformable {
    func applying(_ t: CGAffineTransform) -> Self {
        let nodes = nodes.map { $0.applying(t) }
        return .init(nodeMap: .init(values: nodes) { _ in UUID() }, isClosed: isClosed)
    }
}

// MARK: SUPathAppendable

extension Path: SUPathAppendable {
    func append(to path: inout SUPath) {
        let _r = tracer.range("Path append to"); defer { _r() }
        path.addPath(self.path)
    }
}

// MARK: CustomStringConvertible

extension Path: CustomStringConvertible {
    var description: String {
        "Path(nodes: \(nodes), isClosed: \(isClosed))"
    }
}
