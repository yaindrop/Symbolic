import Foundation
import SwiftProtobuf

// MARK: - PathEvent

extension PathEvent.Create: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.Create) {
        pb.path = path.pb
    }
}

extension Symbolic_Pb_PathEvent.Create: ProtobufParsable {
    func decoded() throws -> PathEvent.Create {
        try .init(path: path.decoded())
    }
}

extension PathEvent.CreateNode: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.CreateNode) {
        prevNodeId.map { pb.prevNodeID = $0.pb }
        pb.nodeID = nodeId.pb
        pb.node = node.pb
    }
}

extension Symbolic_Pb_PathEvent.CreateNode: ProtobufParsable {
    func decoded() -> PathEvent.CreateNode {
        .init(prevNodeId: hasPrevNodeID ? prevNodeID.decoded() : nil, nodeId: nodeID.decoded(), node: node.decoded())
    }
}

extension PathEvent.UpdateNode: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.UpdateNode) {
        pb.nodeID = nodeId.pb
        pb.node = node.pb
    }
}

extension Symbolic_Pb_PathEvent.UpdateNode: ProtobufParsable {
    func decoded() -> PathEvent.UpdateNode {
        .init(nodeId: nodeID.decoded(), node: node.decoded())
    }
}

extension PathEvent.DeleteNode: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.DeleteNode) {
        pb.nodeIds = nodeIds.map { $0.pb }
    }
}

extension Symbolic_Pb_PathEvent.DeleteNode: ProtobufParsable {
    func decoded() -> PathEvent.DeleteNode {
        .init(nodeIds: nodeIds.map { $0.decoded() })
    }
}

extension PathEvent.Merge: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.Merge) {
        pb.endingNodeID = endingNodeId.pb
        pb.mergedPathID = mergedPathId.pb
        pb.mergedEndingNodeID = mergedEndingNodeId.pb
    }
}

extension Symbolic_Pb_PathEvent.Merge: ProtobufParsable {
    func decoded() -> PathEvent.Merge {
        .init(endingNodeId: endingNodeID.decoded(), mergedPathId: mergedPathID.decoded(), mergedEndingNodeId: mergedEndingNodeID.decoded())
    }
}

extension PathEvent.Split: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.Split) {
        pb.nodeID = nodeId.pb
        newPathId.map { pb.newPathID = $0.pb }
        newNodeId.map { pb.newNodeID = $0.pb }
    }
}

extension Symbolic_Pb_PathEvent.Split: ProtobufParsable {
    func decoded() -> PathEvent.Split {
        .init(nodeId: nodeID.decoded(), newPathId: hasNewPathID ? newPathID.decoded() : nil, newNodeId: hasNewNodeID ? newNodeID.decoded() : nil)
    }
}

extension PathEvent.Delete: ProtobufSerializable {
    func encode(pb _: inout Symbolic_Pb_PathEvent.Delete) {}
}

extension Symbolic_Pb_PathEvent.Delete: ProtobufParsable {
    func decoded() -> PathEvent.Delete { .init() }
}

extension PathEvent.Move: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.Move) {
        pb.offset = offset.pb
    }
}

extension Symbolic_Pb_PathEvent.Move: ProtobufParsable {
    func decoded() -> PathEvent.Move {
        .init(offset: offset.decoded())
    }
}

extension PathEvent.SetName: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.SetName) {
        name.map { pb.name = $0 }
    }
}

extension Symbolic_Pb_PathEvent.SetName: ProtobufParsable {
    func decoded() -> PathEvent.SetName {
        .init(name: hasName ? name : nil)
    }
}

extension PathEvent.SetNodeType: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.SetNodeType) {
        pb.nodeIds = nodeIds.map { $0.pb }
        nodeType.map { pb.nodeType = $0.pb }
    }
}

extension Symbolic_Pb_PathEvent.SetNodeType: ProtobufParsable {
    func decoded() -> PathEvent.SetNodeType {
        .init(nodeIds: nodeIds.map { $0.decoded() }, nodeType: nodeType.decoded())
    }
}

extension PathEvent.SetSegmentType: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.SetSegmentType) {
        pb.fromNodeIds = fromNodeIds.map { $0.pb }
        segmentType.map { pb.segmentType = $0.pb }
    }
}

extension Symbolic_Pb_PathEvent.SetSegmentType: ProtobufParsable {
    func decoded() -> PathEvent.SetSegmentType {
        .init(fromNodeIds: fromNodeIds.map { $0.decoded() }, segmentType: segmentType.decoded())
    }
}

extension PathEvent.Kind: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent.Kind) {
        pb.kind = {
            switch self {
            case let .create(kind): .create(kind.pb)
            case let .createNode(kind): .createNode(kind.pb)
            case let .updateNode(kind): .updateNode(kind.pb)
            case let .deleteNode(kind): .deleteNode(kind.pb)
            case let .merge(kind): .merge(kind.pb)
            case let .split(kind): .split(kind.pb)

            case let .delete(kind): .delete(kind.pb)
            case let .move(kind): .move(kind.pb)

            case let .setName(kind): .setName(kind.pb)
            case let .setNodeType(kind): .setNodeType(kind.pb)
            case let .setSegmentType(kind): .setSegmentType(kind.pb)
            }
        }()
    }
}

extension Symbolic_Pb_PathEvent.Kind: ProtobufParsable {
    func decoded() throws -> PathEvent.Kind {
        switch kind {
        case let .create(kind): try .create(kind.decoded())
        case let .createNode(kind): .createNode(kind.decoded())
        case let .updateNode(kind): .updateNode(kind.decoded())
        case let .deleteNode(kind): .deleteNode(kind.decoded())
        case let .merge(kind): .merge(kind.decoded())
        case let .split(kind): .split(kind.decoded())

        case let .delete(kind): .delete(kind.decoded())
        case let .move(kind): .move(kind.decoded())

        case let .setName(kind): .setName(kind.decoded())
        case let .setNodeType(kind): .setNodeType(kind.decoded())
        case let .setSegmentType(kind): .setSegmentType(kind.decoded())
        default: throw ProtobufParseError.invalidEmptyOneOf
        }
    }
}

extension PathEvent: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathEvent) {
        pb.pathIds = pathIds.map { $0.pb }
        pb.kinds = kinds.map { $0.pb }
    }
}

extension Symbolic_Pb_PathEvent: ProtobufParsable {
    func decoded() throws -> PathEvent {
        try .init(pathIds: pathIds.map { $0.decoded() }, kinds: kinds.map { try $0.decoded() })
    }
}

// MARK: - SymbolEvent

extension SymbolEvent.Create: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_SymbolEvent.Create) {
        pb.origin = origin.pb
        pb.size = size.pb
        pb.grids = grids.map { $0.pb }
    }
}

extension Symbolic_Pb_SymbolEvent.Create: ProtobufParsable {
    func decoded() throws -> SymbolEvent.Create {
        try .init(origin: origin.decoded(), size: size.decoded(), grids: grids.map { try $0.decoded() })
    }
}

extension SymbolEvent.SetBounds: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_SymbolEvent.SetBounds) {
        pb.origin = origin.pb
        pb.size = size.pb
    }
}

extension Symbolic_Pb_SymbolEvent.SetBounds: ProtobufParsable {
    func decoded() -> SymbolEvent.SetBounds {
        .init(origin: origin.decoded(), size: size.decoded())
    }
}

extension SymbolEvent.SetGrid: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_SymbolEvent.SetGrid) {
        pb.index = .init(index)
        grid.map { pb.grid = $0.pb }
    }
}

extension Symbolic_Pb_SymbolEvent.SetGrid: ProtobufParsable {
    func decoded() throws -> SymbolEvent.SetGrid {
        try .init(index: .init(index), grid: hasGrid ? grid.decoded() : nil)
    }
}

extension SymbolEvent.SetMembers: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_SymbolEvent.SetMembers) {
        pb.members = members.map { $0.pb }
    }
}

extension Symbolic_Pb_SymbolEvent.SetMembers: ProtobufParsable {
    func decoded() -> SymbolEvent.SetMembers {
        .init(members: members.map { $0.decoded() })
    }
}

extension SymbolEvent.Delete: ProtobufSerializable {
    func encode(pb _: inout Symbolic_Pb_SymbolEvent.Delete) {}
}

extension Symbolic_Pb_SymbolEvent.Delete: ProtobufParsable {
    func decoded() -> SymbolEvent.Delete { .init() }
}

extension SymbolEvent.Move: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_SymbolEvent.Move) {
        pb.offset = offset.pb
    }
}

extension Symbolic_Pb_SymbolEvent.Move: ProtobufParsable {
    func decoded() -> SymbolEvent.Move {
        .init(offset: offset.decoded())
    }
}

extension SymbolEvent.Kind: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_SymbolEvent.Kind) {
        pb.kind = {
            switch self {
            case let .create(kind): .create(kind.pb)
            case let .setBounds(kind): .setBounds(kind.pb)
            case let .setGrid(kind): .setGrid(kind.pb)
            case let .setMembers(kind): .setMembers(kind.pb)

            case let .delete(kind): .delete(kind.pb)
            case let .move(kind): .move(kind.pb)
            }
        }()
    }
}

extension Symbolic_Pb_SymbolEvent.Kind: ProtobufParsable {
    func decoded() throws -> SymbolEvent.Kind {
        switch kind {
        case let .create(kind): try .create(kind.decoded())
        case let .setBounds(kind): .setBounds(kind.decoded())
        case let .setGrid(kind): try .setGrid(kind.decoded())
        case let .setMembers(kind): .setMembers(kind.decoded())

        case let .delete(kind): .delete(kind.decoded())
        case let .move(kind): .move(kind.decoded())
        default: throw ProtobufParseError.invalidEmptyOneOf
        }
    }
}

extension SymbolEvent: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_SymbolEvent) {
        pb.symbolIds = symbolIds.map { $0.pb }
        pb.kinds = kinds.map { $0.pb }
    }
}

extension Symbolic_Pb_SymbolEvent: ProtobufParsable {
    func decoded() throws -> SymbolEvent {
        try .init(symbolIds: symbolIds.map { $0.decoded() }, kinds: kinds.map { try $0.decoded() })
    }
}

// MARK: - ItemEvent

extension ItemEvent.SetGroup: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_ItemEvent.SetGroup) {
        pb.groupID = groupId.pb
        pb.members = members.map { $0.pb }
    }
}

extension Symbolic_Pb_ItemEvent.SetGroup: ProtobufParsable {
    func decoded() -> ItemEvent.SetGroup {
        .init(groupId: groupID.decoded(), members: members.map { $0.decoded() })
    }
}

extension ItemEvent: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_ItemEvent) {
        switch self {
        case let .setGroup(kind): pb.kind = .setGroup(kind.pb)
        }
    }
}

extension Symbolic_Pb_ItemEvent: ProtobufParsable {
    func decoded() throws -> ItemEvent {
        switch kind {
        case let .setGroup(kind): .setGroup(kind.decoded())
        default: throw ProtobufParseError.invalidEmptyOneOf
        }
    }
}

// MARK: - DocumentEvent

extension DocumentEvent.Single: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_DocumentEvent.Single) {
        pb.kind = {
            switch self {
            case let .path(kind): .pathEvent(kind.pb)
            case let .symbol(kind): .symbolEvent(kind.pb)
            case let .item(kind): .itemEvent(kind.pb)
            }
        }()
    }
}

extension Symbolic_Pb_DocumentEvent.Single: ProtobufParsable {
    func decoded() throws -> DocumentEvent.Single {
        switch kind {
        case let .pathEvent(kind): try .path(kind.decoded())
        case let .symbolEvent(kind): try .symbol(kind.decoded())
        case let .itemEvent(kind): try .item(kind.decoded())
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
        action.map { (try? $0.pb.serializedData()).map { pb.actionData = $0 }}
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
        let action = try? Symbolic_Pb_DocumentAction(serializedBytes: actionData).decoded()
        let kind: DocumentEvent.Kind = try {
            switch self.kind {
            case let .single(kind): try .single(kind.decoded())
            case let .compound(kind): try .compound(kind.decoded())
            default: throw ProtobufParseError.invalidEmptyOneOf
            }
        }()
        return .init(id: id.decoded(), time: time.decoded(), action: action, kind: kind)
    }
}

extension Document: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_Document) {
        pb.id = id.pb
        pb.events = events.map { $0.pb }
    }
}

extension Symbolic_Pb_Document: ProtobufParsable {
    func decoded() throws -> Document {
        try .init(id: id.decoded(), events: events.map { try $0.decoded() })
    }
}
