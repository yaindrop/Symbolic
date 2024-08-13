import Foundation
import SwiftProtobuf

// MARK: - UUID

extension UUID {
    var pb: PB_UUID {
        var pb = PB_UUID()
        let d = uuid
        pb.data = .init([d.0, d.1, d.2, d.3, d.4, d.5, d.6, d.7, d.8, d.9, d.10, d.11, d.12, d.13, d.14, d.15])
        return pb
    }
}

extension PB_UUID {
    var value: UUID {
        let d = data
        // TODO: handle error data
        let uuidFormat = "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X"
        let uuidString = String(format: uuidFormat, d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8], d[9], d[10], d[11], d[12], d[13], d[14], d[15])
        return .init(uuidString: uuidString)!
    }
}

// MARK: - Date

extension Date {
    var pb: Google_Protobuf_Timestamp {
        .init(date: self)
    }
}

extension Google_Protobuf_Timestamp {
    var value: Date {
        date
    }
}

// MARK: - Vector2

extension Vector2 {
    var pb: PB_Vector2 {
        var pb = PB_Vector2()
        pb.x = .init(dx)
        pb.y = .init(dy)
        return pb
    }
}

extension Point2 {
    var pb: PB_Vector2 {
        var pb = PB_Vector2()
        pb.x = .init(x)
        pb.y = .init(y)
        return pb
    }
}

extension PB_Vector2 {
    var value: Vector2 {
        .init(.init(x), .init(y))
    }

    var point: Point2 {
        .init(.init(x), .init(y))
    }
}

// MARK: - PathNode

extension PathNode {
    var pb: PB_PathNode {
        var pb = PB_PathNode()
        pb.position = position.pb
        pb.cubicIn = cubicIn.pb
        pb.cubicOut = cubicOut.pb
        return pb
    }
}

extension PB_PathNode {
    var value: PathNode {
        .init(position: position.point, cubicIn: cubicIn.value, cubicOut: cubicOut.value)
    }
}

// MARK: - Path

extension Path {
    var pb: PB_Path {
        var pb = PB_Path()
        pb.nodeIds = nodeIds.map { $0.pb }
        pb.nodes = nodes.map { $0.pb }
        pb.isClosed = isClosed
        return pb
    }
}

extension PB_Path {
    var value: Path? {
        guard nodeIds.count == nodes.count else { return nil }
        var nodeMap = Path.NodeMap()
        for i in nodeIds.indices {
            nodeMap[nodeIds[i].value] = nodes[i].value
        }
        return .init(nodeMap: nodeMap, isClosed: isClosed)
    }
}
