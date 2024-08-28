
import Foundation

extension Path {
    func with(nodeMap: NodeMap, isClosed: Bool? = nil) -> Self {
        .init(nodeMap: nodeMap, isClosed: isClosed ?? self.isClosed)
    }

    mutating func update(_ event: PathEvent.CreateNode) {
        let _r = tracer.range("Path update create node"); defer { _r() }
        let prevNodeId = event.prevNodeId, nodeId = event.nodeId, node = event.node
        var i = 0
        if let prevNodeId {
            guard let prev = nodeIndex(id: prevNodeId) else { return }
            i = prev + 1
        }
        nodeMap.insert((nodeId, node), at: i)
    }

    mutating func update(_ event: PathEvent.UpdateNode) {
        let _r = tracer.range("Path update update node"); defer { _r() }
        nodeMap[event.nodeId] = event.node
    }

    mutating func update(_ event: PathEvent.DeleteNode) {
        let _r = tracer.range("Path update delete node"); defer { _r() }
        for nodeId in event.nodeIds {
            nodeMap.removeValue(forKey: nodeId)
        }
    }

    mutating func update(_ event: PathEvent.Merge, mergedPath: Path) {
        let _r = tracer.range("Path update merge"); defer { _r() }
        let endingNodeId = event.endingNodeId,
            mergedEndingNodeId = event.mergedEndingNodeId
        guard let endingNode = node(id: endingNodeId),
              let mergedEndingNode = mergedPath.node(id: mergedEndingNodeId),
              isEndingNode(id: endingNodeId),
              mergedPath.isEndingNode(id: mergedEndingNodeId),
              endingNodeId != mergedEndingNodeId else { return }
        let mergePosition = endingNode.position == mergedEndingNode.position
        if mergedPath == self {
            if mergePosition {
                nodeMap.removeValue(forKey: nodeIds.last!)
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

    mutating func update(_ event: PathEvent.Split) -> Path? {
        let _r = tracer.range("Path update split"); defer { _r() }
        let nodeId = event.nodeId,
            newNodeId = event.newNodeId
        guard let i = nodeIndex(id: nodeId),
              let node = node(id: nodeId) else { return nil }
        let newNode = PathNode(position: node.position, cubicOut: node.cubicOut)
        if isClosed {
            nodeMap.mutateKeys { $0 = Array($0[(i + 1)...] + $0[...i]) }
            if let newNodeId {
                nodeMap.insert((newNodeId, newNode), at: 0)
            }
            isClosed = false
            return nil
        } else {
            var newNodeMap = nodeMap
            nodeMap.mutateKeys { $0 = Array($0[...i]) }
            newNodeMap.mutateKeys { $0 = Array($0[(i + 1)...]) }
            if let newNodeId {
                newNodeMap.insert((newNodeId, newNode), at: 0)
            }
            return .init(nodeMap: newNodeMap, isClosed: false)
        }
    }

    mutating func update(_ event: PathEvent.Move) {
        let _r = tracer.range("Path update move"); defer { _r() }
        for id in nodeIds {
            nodeMap[id]?.position += event.offset
        }
    }

    mutating func update(_ event: PathEvent.SetNodeType) {
        let _r = tracer.range("Path update set node type"); defer { _r() }
        for nodeId in event.nodeIds {
            guard let node = node(id: nodeId) else { continue }
            switch event.nodeType {
            case .locked:
                nodeMap[nodeId]?.cubicOut = node.cubicIn.with(length: -node.cubicOut.length)
            case .mirrored:
                nodeMap[nodeId]?.cubicOut = -node.cubicIn
            default: break
            }
        }
    }

    mutating func update(_ event: PathEvent.SetSegmentType) {
        let _r = tracer.range("Path update set segment type"); defer { _r() }
        for fromNodeId in event.fromNodeIds {
            switch event.segmentType {
            case .quadratic:
                guard let toNodeId = nodeId(after: fromNodeId),
                      let segment = segment(fromId: fromNodeId)?.toQuradratic else { return }
                nodeMap[fromNodeId]?.cubicOut = segment.fromCubicOut
                nodeMap[toNodeId]?.cubicIn = segment.toCubicIn
            default: break
            }
        }
    }
}
