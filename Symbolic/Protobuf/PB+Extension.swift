import Foundation
import SwiftProtobuf

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

// MARK: - ItemEvent

extension ItemEvent.SetMembers: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_ItemEvent.SetMembers) {
        groupId.map { pb.groupID = $0.pb }
        pb.members = members.map { $0.pb }
    }
}

extension Symbolic_Pb_ItemEvent.SetMembers: ProtobufParsable {
    func decoded() -> ItemEvent.SetMembers {
        .init(groupId: hasGroupID ? groupID.decoded() : nil, members: members.map { $0.decoded() })
    }
}

extension ItemEvent: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_ItemEvent) {
        switch self {
        case let .setMembers(kind): pb.kind = .setMembers(kind.pb)
        }
    }
}

extension Symbolic_Pb_ItemEvent: ProtobufParsable {
    func decoded() throws -> ItemEvent {
        switch kind {
        case let .setMembers(kind): .setMembers(kind.decoded())
        default: throw ProtobufParseError.invalidEmptyOneOf
        }
    }
}

// MARK: - PathEvent

extension PathEvent.Create: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.Create) {
        pb.pathID = pathId.pb
        pb.path = path.pb
    }
}

extension Symbolic_Pb_PathEvent.Create: ProtobufParsable {
    func decoded() throws -> PathEvent.Create {
        try .init(pathId: pathID.decoded(), path: path.decoded())
    }
}

extension PathEvent.Delete: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.Delete) {
        pb.pathID = pathId.pb
    }
}

extension Symbolic_Pb_PathEvent.Delete: ProtobufParsable {
    func decoded() -> PathEvent.Delete {
        .init(pathId: pathID.decoded())
    }
}

extension PathEvent.Update.Move: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.Update.Move) {
        pb.offset = offset.pb
    }
}

extension Symbolic_Pb_PathEvent.Update.Move: ProtobufParsable {
    func decoded() -> PathEvent.Update.Move {
        .init(offset: offset.decoded())
    }
}

extension PathEvent.Update.NodeCreate: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.Update.NodeCreate) {
        prevNodeId.map { pb.prevNodeID = $0.pb }
        pb.nodeID = nodeId.pb
        pb.node = node.pb
    }
}

extension Symbolic_Pb_PathEvent.Update.NodeCreate: ProtobufParsable {
    func decoded() -> PathEvent.Update.NodeCreate {
        .init(prevNodeId: hasPrevNodeID ? prevNodeID.decoded() : nil, nodeId: nodeID.decoded(), node: node.decoded())
    }
}

extension PathEvent.Update.NodeDelete: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.Update.NodeDelete) {
        pb.nodeID = nodeId.pb
    }
}

extension Symbolic_Pb_PathEvent.Update.NodeDelete: ProtobufParsable {
    func decoded() -> PathEvent.Update.NodeDelete {
        .init(nodeId: nodeID.decoded())
    }
}

extension PathEvent.Update.NodeUpdate: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.Update.NodeUpdate) {
        pb.nodeID = nodeId.pb
        pb.node = node.pb
    }
}

extension Symbolic_Pb_PathEvent.Update.NodeUpdate: ProtobufParsable {
    func decoded() -> PathEvent.Update.NodeUpdate {
        .init(nodeId: nodeID.decoded(), node: node.decoded())
    }
}

extension PathEvent.Update.Kind: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.Update.Kind) {
        pb.kind = {
            switch self {
            case let .move(kind): .move(kind.pb)
            case let .nodeCreate(kind): .nodeCreate(kind.pb)
            case let .nodeDelete(kind): .nodeDelete(kind.pb)
            case let .nodeUpdate(kind): .nodeUpdate(kind.pb)
            }
        }()
    }
}

extension Symbolic_Pb_PathEvent.Update.Kind: ProtobufParsable {
    func decoded() throws -> PathEvent.Update.Kind {
        switch kind {
        case let .move(kind): .move(kind.decoded())
        case let .nodeCreate(kind): .nodeCreate(kind.decoded())
        case let .nodeDelete(kind): .nodeDelete(kind.decoded())
        case let .nodeUpdate(kind): .nodeUpdate(kind.decoded())
        default: throw ProtobufParseError.invalidEmptyOneOf
        }
    }
}

extension PathEvent.Update: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.Update) {
        pb.pathID = pathId.pb
        pb.kinds = kinds.map { $0.pb }
    }
}

extension Symbolic_Pb_PathEvent.Update: ProtobufParsable {
    func decoded() throws -> PathEvent.Update {
        try .init(pathId: pathID.decoded(), kinds: kinds.map { try $0.decoded() })
    }
}

extension PathEvent.Merge: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.Merge) {
        pb.pathID = pathId.pb
        pb.endingNodeID = endingNodeId.pb
        pb.mergedPathID = mergedPathId.pb
        pb.mergedEndingNodeID = mergedEndingNodeId.pb
    }
}

extension Symbolic_Pb_PathEvent.Merge: ProtobufParsable {
    func decoded() -> PathEvent.Merge {
        .init(pathId: pathID.decoded(), endingNodeId: endingNodeID.decoded(), mergedPathId: mergedPathID.decoded(), mergedEndingNodeId: mergedEndingNodeID.decoded())
    }
}

extension PathEvent.Split: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.Split) {
        pb.pathID = pathId.pb
        pb.nodeID = nodeId.pb
        newPathId.map { pb.newPathID = $0.pb }
        newNodeId.map { pb.newNodeID = $0.pb }
    }
}

extension Symbolic_Pb_PathEvent.Split: ProtobufParsable {
    func decoded() -> PathEvent.Split {
        .init(pathId: pathID.decoded(), nodeId: nodeID.decoded(), newPathId: hasNewPathID ? newPathID.decoded() : nil, newNodeId: hasNewNodeID ? newNodeID.decoded() : nil)
    }
}

extension PathEvent: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent) {
        pb.kind = {
            switch self {
            case let .create(kind): .create(kind.pb)
            case let .delete(kind): .delete(kind.pb)
            case let .update(kind): .update(kind.pb)
            case let .merge(kind): .merge(kind.pb)
            case let .split(kind): .split(kind.pb)
            }
        }()
    }
}

extension Symbolic_Pb_PathEvent: ProtobufParsable {
    func decoded() throws -> PathEvent {
        switch kind {
        case let .create(kind): try .create(kind.decoded())
        case let .delete(kind): .delete(kind.decoded())
        case let .update(kind): try .update(kind.decoded())
        case let .merge(kind): .merge(kind.decoded())
        case let .split(kind): .split(kind.decoded())
        default: throw ProtobufParseError.invalidEmptyOneOf
        }
    }
}

// MARK: - PathPropertyEvent

extension PathPropertyEvent.Update.SetName: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathPropertyEvent.Update.SetName) {
        name.map { pb.name = $0 }
    }
}

extension Symbolic_Pb_PathPropertyEvent.Update.SetName: ProtobufParsable {
    func decoded() -> PathPropertyEvent.Update.SetName {
        .init(name: hasName ? name : nil)
    }
}

extension PathPropertyEvent.Update.SetNodeType: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathPropertyEvent.Update.SetNodeType) {
        pb.nodeIds = nodeIds.map { $0.pb }
        nodeType.map { pb.nodeType = $0.pb }
    }
}

extension Symbolic_Pb_PathPropertyEvent.Update.SetNodeType: ProtobufParsable {
    func decoded() -> PathPropertyEvent.Update.SetNodeType {
        .init(nodeIds: nodeIds.map { $0.decoded() }, nodeType: nodeType.decoded())
    }
}

extension PathPropertyEvent.Update.SetSegmentType: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathPropertyEvent.Update.SetSegmentType) {
        pb.fromNodeIds = fromNodeIds.map { $0.pb }
        segmentType.map { pb.segmentType = $0.pb }
    }
}

extension Symbolic_Pb_PathPropertyEvent.Update.SetSegmentType: ProtobufParsable {
    func decoded() -> PathPropertyEvent.Update.SetSegmentType {
        .init(fromNodeIds: fromNodeIds.map { $0.decoded() }, segmentType: segmentType.decoded())
    }
}

extension PathPropertyEvent.Update.Kind: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathPropertyEvent.Update.Kind) {
        pb.kind = {
            switch self {
            case let .setName(kind): .setName(kind.pb)
            case let .setNodeType(kind): .setNodeType(kind.pb)
            case let .setSegmentType(kind): .setSegmentType(kind.pb)
            }
        }()
    }
}

extension Symbolic_Pb_PathPropertyEvent.Update.Kind: ProtobufParsable {
    func decoded() throws -> PathPropertyEvent.Update.Kind {
        switch kind {
        case let .setName(kind): .setName(kind.decoded())
        case let .setNodeType(kind): .setNodeType(kind.decoded())
        case let .setSegmentType(kind): .setSegmentType(kind.decoded())
        default: throw ProtobufParseError.invalidEmptyOneOf
        }
    }
}

extension PathPropertyEvent.Update: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathPropertyEvent.Update) {
        pb.pathID = pathId.pb
        pb.kinds = kinds.map { $0.pb }
    }
}

extension Symbolic_Pb_PathPropertyEvent.Update: ProtobufParsable {
    func decoded() throws -> PathPropertyEvent.Update {
        try .init(pathId: pathID.decoded(), kinds: kinds.map { try $0.decoded() })
    }
}

extension PathPropertyEvent: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathPropertyEvent) {
        pb.kind = {
            switch self {
            case let .update(kind): .update(kind.pb)
            }
        }()
    }
}

extension Symbolic_Pb_PathPropertyEvent: ProtobufParsable {
    func decoded() throws -> PathPropertyEvent {
        switch kind {
        case let .update(kind): try .update(kind.decoded())
        default: throw ProtobufParseError.invalidEmptyOneOf
        }
    }
}

// MARK: - DocumentEvent

extension DocumentEvent.Single: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_DocumentEvent.Single) {
        pb.kind = {
            switch self {
            case let .item(kind): .itemEvent(kind.pb)
            case let .path(kind): .pathEvent(kind.pb)
            case let .pathProperty(kind): .pathPropertyEvent(kind.pb)
            }
        }()
    }
}

extension Symbolic_Pb_DocumentEvent.Single: ProtobufParsable {
    func decoded() throws -> DocumentEvent.Single {
        switch kind {
        case let .itemEvent(kind): try .item(kind.decoded())
        case let .pathEvent(kind): try .path(kind.decoded())
        case let .pathPropertyEvent(kind): try .pathProperty(kind.decoded())
        default: throw ProtobufParseError.invalidEmptyOneOf
        }
    }
}

extension DocumentEvent.Compound: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_DocumentEvent.Compound) {
        pb.events = events.map { $0.pb }
    }
}

extension Symbolic_Pb_DocumentEvent.Compound: ProtobufParsable {
    func decoded() throws -> DocumentEvent.Compound {
        try .init(events: events.map { try $0.decoded() })
    }
}

extension DocumentEvent: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_DocumentEvent) {
        pb.id = id.pb
        pb.time = time.pb
        pb.kind = {
            switch kind {
            case let .single(kind): .single(kind.pb)
            case let .compound(kind): .compound(kind.pb)
            }
        }()
    }
}

extension Symbolic_Pb_DocumentEvent: ProtobufParsable {
    func decoded() throws -> DocumentEvent {
        let kind: DocumentEvent.Kind = try {
            switch self.kind {
            case let .single(kind): try .single(kind.decoded())
            case let .compound(kind): try .compound(kind.decoded())
            default: throw ProtobufParseError.invalidEmptyOneOf
            }
        }()
        return .init(id: id.decoded(), time: time.decoded(), kind: kind)
    }
}
