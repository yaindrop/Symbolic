import Foundation
import SwiftProtobuf

// MARK: - UUID

extension UUID {
    var pb: Symbolic_Pb_UUID {
        modify(.init()) {
            let d = uuid
            $0.hi = .init(bigEndian: d.0, d.1, d.2, d.3, d.4, d.5, d.6, d.7)
            $0.lo = .init(bigEndian: d.8, d.9, d.10, d.11, d.12, d.13, d.14, d.15)
        }
    }
}

extension Symbolic_Pb_UUID {
    var value: UUID {
        let time_low = hi >> 32
        let time_mid = (hi >> 16) & 0xFFFF
        let time_hi_and_version = hi & 0xFFFF
        let clock_seq_hi_and_reserved = (lo >> 56)
        let clock_seq_low = (lo >> 48) & 0xFF
        let node = lo & 0xFFFF_FFFF_FFFF
        let uuidFormat = "%08X-%04X-%04X-%02X%02X-%012X"
        let uuidString = String(format: uuidFormat, time_low, time_mid, time_hi_and_version, clock_seq_hi_and_reserved, clock_seq_low, node)
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
    var pb: Symbolic_Pb_Vector2 {
        modify(.init()) {
            $0.x = .init(dx)
            $0.y = .init(dy)
        }
    }
}

extension Point2 {
    var pb: Symbolic_Pb_Vector2 {
        modify(.init()) {
            $0.x = .init(x)
            $0.y = .init(y)
        }
    }
}

extension Symbolic_Pb_Vector2 {
    var value: Vector2 {
        .init(.init(x), .init(y))
    }

    var point: Point2 {
        .init(.init(x), .init(y))
    }
}

// MARK: - PathNode

extension PathNode {
    var pb: Symbolic_Pb_PathNode {
        modify(.init()) {
            $0.position = position.pb
            $0.cubicIn = cubicIn.pb
            $0.cubicOut = cubicOut.pb
        }
    }
}

extension Symbolic_Pb_PathNode {
    var value: PathNode {
        .init(position: position.point, cubicIn: cubicIn.value, cubicOut: cubicOut.value)
    }
}

// MARK: - Path

extension Path {
    var pb: Symbolic_Pb_Path {
        modify(.init()) {
            $0.nodeIds = nodeIds.map { $0.pb }
            $0.nodes = nodes.map { $0.pb }
            $0.isClosed = isClosed
        }
    }
}

extension Symbolic_Pb_Path {
    var value: Path? {
        guard nodeIds.count == nodes.count else { return nil }
        var nodeMap = Path.NodeMap()
        for i in nodeIds.indices {
            nodeMap[nodeIds[i].value] = nodes[i].value
        }
        return .init(nodeMap: nodeMap, isClosed: isClosed)
    }
}
