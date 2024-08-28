import SwiftProtobuf
import SwiftUI

protocol ProtobufSerializable {
    associatedtype T: SwiftProtobuf.Message
    func encode(pb: inout T) -> Void
    var pb: T { get }
}

extension ProtobufSerializable {
    var pb: T {
        var pb = T()
        encode(pb: &pb)
        return pb
    }
}

protocol ProtobufParsable {
    associatedtype T
    func decoded() throws -> T
}

enum ProtobufParseError: Error {
    case unknown
    case invalidData
    case invalidEmptyOneOf
}

// MARK: - basic types

extension Date: ProtobufSerializable {
    func encode(pb: inout Google_Protobuf_Timestamp) {
        pb = .init(date: self)
    }
}

extension Google_Protobuf_Timestamp: ProtobufParsable {
    func decoded() -> Date {
        date
    }
}

extension UUID: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_UUID) {
        let d = uuid
        pb.hi = .init(bigEndian: d.0, d.1, d.2, d.3, d.4, d.5, d.6, d.7)
        pb.lo = .init(bigEndian: d.8, d.9, d.10, d.11, d.12, d.13, d.14, d.15)
    }
}

extension Symbolic_Pb_UUID: ProtobufParsable {
    func decoded() -> UUID {
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

extension Vector2: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_Vector2) {
        pb.x = .init(dx)
        pb.y = .init(dy)
    }
}

extension Symbolic_Pb_Vector2: ProtobufParsable {
    func decoded() -> Vector2 {
        .init(.init(x), .init(y))
    }
}

extension Point2: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_Point2) {
        pb.x = .init(x)
        pb.y = .init(y)
    }
}

extension Symbolic_Pb_Point2: ProtobufParsable {
    func decoded() -> Point2 {
        .init(.init(x), .init(y))
    }
}

extension CGSize: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_Size2) {
        pb.width = .init(width)
        pb.height = .init(height)
    }
}

extension Symbolic_Pb_Size2: ProtobufParsable {
    func decoded() -> CGSize {
        .init(.init(width), .init(height))
    }
}

extension Angle: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_Angle) {
        pb.radians = radians
    }
}

extension Symbolic_Pb_Angle: ProtobufParsable {
    func decoded() -> Angle {
        .init(radians: radians)
    }
}

extension CGColor: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_Color) {
        guard let components else { return }
        pb.red = components[0]
        pb.green = components[1]
        pb.blue = components[2]
        pb.alpha = components[3]
    }
}

extension Symbolic_Pb_Color: ProtobufParsable {
    func decoded() -> CGColor {
        .init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

// MARK: - path types

extension PathNode: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathNode) {
        pb.position = position.pb
        pb.cubicIn = cubicIn.pb
        pb.cubicOut = cubicOut.pb
    }
}

extension Symbolic_Pb_PathNode: ProtobufParsable {
    func decoded() -> PathNode {
        .init(position: position.decoded(), cubicIn: cubicIn.decoded(), cubicOut: cubicOut.decoded())
    }
}

extension PathNodeControlType {
    var pb: Symbolic_Pb_PathNodeControlType {
        switch self {
        case .cubicIn: .cubicIn
        case .cubicOut: .cubicOut
        case .quadraticOut: .quadraticOut
        }
    }
}

extension Symbolic_Pb_PathNodeControlType: ProtobufParsable {
    func decoded() -> PathNodeControlType {
        switch self {
        case .cubicIn: .cubicIn
        case .cubicOut: .cubicOut
        case .quadraticOut: .quadraticOut
        default: .cubicIn
        }
    }
}

extension Path: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_Path) {
        pb.nodeIds = nodeIds.map { $0.pb }
        pb.nodes = nodes.map { $0.pb }
        pb.isClosed = isClosed
    }
}

extension Symbolic_Pb_Path: ProtobufParsable {
    func decoded() throws -> Path {
        guard nodeIds.count == nodes.count, nodeIds.count > 1 else { throw ProtobufParseError.invalidData }
        var nodeMap = Path.NodeMap()
        for i in nodeIds.indices {
            nodeMap[nodeIds[i].decoded()] = nodes[i].decoded()
        }
        return .init(nodeMap: nodeMap, isClosed: isClosed)
    }
}

extension PathNodeType {
    var pb: Symbolic_Pb_PathNodeType {
        switch self {
        case .corner: .corner
        case .locked: .locked
        case .mirrored: .mirrored
        }
    }
}

extension Symbolic_Pb_PathNodeType: ProtobufParsable {
    func decoded() -> PathNodeType {
        switch self {
        case .corner: .corner
        case .locked: .locked
        case .mirrored: .mirrored
        default: .corner
        }
    }
}

extension PathSegmentType {
    var pb: Symbolic_Pb_PathSegmentType {
        switch self {
        case .cubic: .cubic
        case .quadratic: .quadratic
        }
    }
}

extension Symbolic_Pb_PathSegmentType: ProtobufParsable {
    func decoded() -> PathSegmentType {
        switch self {
        case .cubic: .cubic
        case .quadratic: .quadratic
        default: .cubic
        }
    }
}

// MARK: - grid

extension Grid.Cartesian: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_Grid.Cartesian) {
        pb.interval = interval
    }
}

extension Symbolic_Pb_Grid.Cartesian: ProtobufParsable {
    func decoded() -> Grid.Cartesian {
        .init(interval: interval)
    }
}

extension Grid.Isometric: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_Grid.Isometric) {
        pb.interval = interval
        pb.angle0 = angle0.pb
        pb.angle1 = angle1.pb
    }
}

extension Symbolic_Pb_Grid.Isometric: ProtobufParsable {
    func decoded() -> Grid.Isometric {
        .init(interval: interval, angle0: angle0.decoded(), angle1: angle1.decoded())
    }
}

extension Grid.Radial: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_Grid.Radial) {
        pb.interval = interval
        pb.angularDivisions = .init(angularDivisions)
    }
}

extension Symbolic_Pb_Grid.Radial: ProtobufParsable {
    func decoded() -> Grid.Radial {
        .init(interval: interval, angularDivisions: .init(angularDivisions))
    }
}

extension Grid: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_Grid) {
        pb.tintColor = tintColor.cgColor.pb
        pb.kind = {
            switch kind {
            case let .cartesian(kind): .cartesian(kind.pb)
            case let .isometric(kind): .isometric(kind.pb)
            case let .radial(kind): .radial(kind.pb)
            }
        }()
    }
}

extension Symbolic_Pb_Grid: ProtobufParsable {
    func decoded() throws -> Grid {
        let kind: Grid.Kind = try {
            switch self.kind {
            case let .cartesian(kind): .cartesian(kind.decoded())
            case let .isometric(kind): .isometric(kind.decoded())
            case let .radial(kind): .radial(kind.decoded())
            default: throw ProtobufParseError.invalidEmptyOneOf
            }
        }()
        return .init(tintColor: .init(cgColor: tintColor.decoded()), kind: kind)
    }
}
