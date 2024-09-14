import Foundation
import SwiftProtobuf

// MARK: - PathAction

extension PathAction.Create: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Create) {
        pb.symbolID = symbolId.pb
        pb.pathID = pathId.pb
        pb.path = path.pb
    }
}

extension Symbolic_Pb_PathAction.Create: ProtobufParsable {
    func decoded() throws -> PathAction.Create {
        try .init(symbolId: symbolID.decoded(), pathId: pathID.decoded(), path: path.decoded())
    }
}

extension PathAction.Update.AddEndingNode: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Update.AddEndingNode) {
        pb.endingNodeID = endingNodeId.pb
        pb.newNodeID = newNodeId.pb
        pb.offset = offset.pb
    }
}

extension Symbolic_Pb_PathAction.Update.AddEndingNode: ProtobufParsable {
    func decoded() -> PathAction.Update.AddEndingNode {
        .init(endingNodeId: endingNodeID.decoded(), newNodeId: newNodeID.decoded(), offset: offset.decoded())
    }
}

extension PathAction.Update.SplitSegment: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Update.SplitSegment) {
        pb.fromNodeID = fromNodeId.pb
        pb.paramT = paramT
        pb.newNodeID = newNodeId.pb
        pb.offset = offset.pb
    }
}

extension Symbolic_Pb_PathAction.Update.SplitSegment: ProtobufParsable {
    func decoded() -> PathAction.Update.SplitSegment {
        .init(fromNodeId: fromNodeID.decoded(), paramT: paramT, newNodeId: newNodeID.decoded(), offset: offset.decoded())
    }
}

extension PathAction.Update.DeleteNodes: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Update.DeleteNodes) {
        pb.nodeIds = nodeIds.map { $0.pb }
    }
}

extension Symbolic_Pb_PathAction.Update.DeleteNodes: ProtobufParsable {
    func decoded() -> PathAction.Update.DeleteNodes {
        .init(nodeIds: nodeIds.map { $0.decoded() })
    }
}

extension PathAction.Update.UpdateNode: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Update.UpdateNode) {
        pb.nodeID = nodeId.pb
        pb.node = node.pb
    }
}

extension Symbolic_Pb_PathAction.Update.UpdateNode: ProtobufParsable {
    func decoded() -> PathAction.Update.UpdateNode {
        .init(nodeId: nodeID.decoded(), node: node.decoded())
    }
}

extension PathAction.Update.UpdateSegment: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Update.UpdateSegment) {
        pb.fromNodeID = fromNodeId.pb
        pb.segment = segment.pb
    }
}

extension Symbolic_Pb_PathAction.Update.UpdateSegment: ProtobufParsable {
    func decoded() -> PathAction.Update.UpdateSegment {
        .init(fromNodeId: fromNodeID.decoded(), segment: segment.decoded())
    }
}

extension PathAction.Update.MoveNodes: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Update.MoveNodes) {
        pb.nodeIds = nodeIds.map { $0.pb }
        pb.offset = offset.pb
    }
}

extension Symbolic_Pb_PathAction.Update.MoveNodes: ProtobufParsable {
    func decoded() -> PathAction.Update.MoveNodes {
        .init(nodeIds: nodeIds.map { $0.decoded() }, offset: offset.decoded())
    }
}

extension PathAction.Update.MoveNodeControl: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Update.MoveNodeControl) {
        pb.nodeID = nodeId.pb
        pb.controlType = controlType.pb
        pb.offset = offset.pb
    }
}

extension Symbolic_Pb_PathAction.Update.MoveNodeControl: ProtobufParsable {
    func decoded() -> PathAction.Update.MoveNodeControl {
        .init(nodeId: nodeID.decoded(), controlType: controlType.decoded(), offset: offset.decoded())
    }
}

extension PathAction.Update.Merge: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Update.Merge) {
        pb.endingNodeID = endingNodeId.pb
        pb.mergedPathID = mergedPathId.pb
        pb.mergedEndingNodeID = mergedEndingNodeId.pb
    }
}

extension Symbolic_Pb_PathAction.Update.Merge: ProtobufParsable {
    func decoded() -> PathAction.Update.Merge {
        .init(endingNodeId: endingNodeID.decoded(), mergedPathId: mergedPathID.decoded(), mergedEndingNodeId: mergedEndingNodeID.decoded())
    }
}

extension PathAction.Update.Split: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Update.Split) {
        pb.nodeID = nodeId.pb
        pb.newPathID = newPathId.pb
        if let newNodeId = newNodeId {
            pb.newNodeID = newNodeId.pb
        }
    }
}

extension Symbolic_Pb_PathAction.Update.Split: ProtobufParsable {
    func decoded() -> PathAction.Update.Split {
        .init(nodeId: nodeID.decoded(), newPathId: newPathID.decoded(), newNodeId: newNodeID.decoded())
    }
}

extension PathAction.Update.SetNodeType: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Update.SetNodeType) {
        pb.nodeIds = nodeIds.map { $0.pb }
        if let nodeType = nodeType {
            pb.nodeType = nodeType.pb
        }
    }
}

extension Symbolic_Pb_PathAction.Update.SetNodeType: ProtobufParsable {
    func decoded() -> PathAction.Update.SetNodeType {
        .init(nodeIds: nodeIds.map { $0.decoded() }, nodeType: nodeType.decoded())
    }
}

extension PathAction.Update.SetSegmentType: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Update.SetSegmentType) {
        pb.fromNodeIds = fromNodeIds.map { $0.pb }
        if let segmentType = segmentType {
            pb.segmentType = segmentType.pb
        }
    }
}

extension Symbolic_Pb_PathAction.Update.SetSegmentType: ProtobufParsable {
    func decoded() -> PathAction.Update.SetSegmentType {
        .init(fromNodeIds: fromNodeIds.map { $0.decoded() }, segmentType: segmentType.decoded())
    }
}

extension PathAction.Update: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Update) {
        pb.pathID = pathId.pb
        pb.kind = {
            switch kind {
            case let .addEndingNode(kind): .addEndingNode(kind.pb)
            case let .splitSegment(kind): .splitSegment(kind.pb)
            case let .deleteNodes(kind): .deleteNodes(kind.pb)
            case let .updateNode(kind): .updateNode(kind.pb)
            case let .updateSegment(kind): .updateSegment(kind.pb)
            case let .moveNodes(kind): .moveNodes(kind.pb)
            case let .moveNodeControl(kind): .moveNodeControl(kind.pb)
            case let .merge(kind): .merge(kind.pb)
            case let .split(kind): .split(kind.pb)
            case let .setNodeType(kind): .setNodeType(kind.pb)
            case let .setSegmentType(kind): .setSegmentType(kind.pb)
            }
        }()
    }
}

extension Symbolic_Pb_PathAction.Update: ProtobufParsable {
    func decoded() throws -> PathAction.Update {
        let kind: PathAction.Update.Kind = try {
            switch self.kind {
            case let .addEndingNode(kind): .addEndingNode(kind.decoded())
            case let .splitSegment(kind): .splitSegment(kind.decoded())
            case let .deleteNodes(kind): .deleteNodes(kind.decoded())
            case let .updateNode(kind): .updateNode(kind.decoded())
            case let .updateSegment(kind): .updateSegment(kind.decoded())
            case let .moveNodes(kind): .moveNodes(kind.decoded())
            case let .moveNodeControl(kind): .moveNodeControl(kind.decoded())
            case let .merge(kind): .merge(kind.decoded())
            case let .split(kind): .split(kind.decoded())
            case let .setNodeType(kind): .setNodeType(kind.decoded())
            case let .setSegmentType(kind): .setSegmentType(kind.decoded())
            case .none: throw ProtobufParseError.invalidEmptyOneOf
            }
        }()
        return .init(pathId: pathID.decoded(), kind: kind)
    }
}

extension PathAction.Delete: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Delete) {
        pb.pathIds = pathIds.map { $0.pb }
    }
}

extension Symbolic_Pb_PathAction.Delete: ProtobufParsable {
    func decoded() -> PathAction.Delete {
        .init(pathIds: pathIds.map { $0.decoded() })
    }
}

extension PathAction.Move: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Move) {
        pb.pathIds = pathIds.map { $0.pb }
        pb.offset = offset.pb
    }
}

extension Symbolic_Pb_PathAction.Move: ProtobufParsable {
    func decoded() -> PathAction.Move {
        .init(pathIds: pathIds.map { $0.decoded() }, offset: offset.decoded())
    }
}

extension PathAction: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction) {
        pb.kind = {
            switch self {
            case let .create(kind): .create(kind.pb)
            case let .update(kind): .update(kind.pb)
            case let .delete(kind): .delete(kind.pb)
            case let .move(kind): .move(kind.pb)
            }
        }()
    }
}

extension Symbolic_Pb_PathAction: ProtobufParsable {
    func decoded() throws -> PathAction {
        switch kind {
        case let .create(kind): try .create(kind.decoded())
        case let .update(kind): try .update(kind.decoded())
        case let .delete(kind): .delete(kind.decoded())
        case let .move(kind): .move(kind.decoded())
        case .none: throw ProtobufParseError.invalidEmptyOneOf
        }
    }
}

// MARK: - SymbolAction

extension SymbolAction.Create: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_SymbolAction.Create) {
        pb.symbolID = symbolId.pb
        pb.origin = origin.pb
        pb.size = size.pb
    }
}

extension Symbolic_Pb_SymbolAction.Create: ProtobufParsable {
    func decoded() -> SymbolAction.Create {
        .init(symbolId: symbolID.decoded(), origin: origin.decoded(), size: size.decoded())
    }
}

extension SymbolAction.Resize: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_SymbolAction.Resize) {
        pb.symbolID = symbolId.pb
        pb.align = align.pb
        pb.offset = offset.pb
    }
}

extension Symbolic_Pb_SymbolAction.Resize: ProtobufParsable {
    func decoded() -> SymbolAction.Resize {
        .init(symbolId: symbolID.decoded(), align: align.decoded(), offset: offset.decoded())
    }
}

extension SymbolAction.SetGrid: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_SymbolAction.SetGrid) {
        pb.symbolID = symbolId.pb
        pb.index = .init(index)
        grid.map { pb.grid = $0.pb }
    }
}

extension Symbolic_Pb_SymbolAction.SetGrid: ProtobufParsable {
    func decoded() throws -> SymbolAction.SetGrid {
        try .init(symbolId: symbolID.decoded(), index: .init(index), grid: hasGrid ? grid.decoded() : nil)
    }
}

extension SymbolAction.Delete: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_SymbolAction.Delete) {
        pb.symbolIds = symbolIds.map { $0.pb }
    }
}

extension Symbolic_Pb_SymbolAction.Delete: ProtobufParsable {
    func decoded() -> SymbolAction.Delete {
        .init(symbolIds: symbolIds.map { $0.decoded() })
    }
}

extension SymbolAction.Move: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_SymbolAction.Move) {
        pb.symbolIds = symbolIds.map { $0.pb }
        pb.offset = offset.pb
    }
}

extension Symbolic_Pb_SymbolAction.Move: ProtobufParsable {
    func decoded() -> SymbolAction.Move {
        .init(symbolIds: symbolIds.map { $0.decoded() }, offset: offset.decoded())
    }
}

extension SymbolAction: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_SymbolAction) {
        pb.kind = {
            switch self {
            case let .create(kind): .create(kind.pb)
            case let .resize(kind): .resize(kind.pb)
            case let .setGrid(kind): .setGrid(kind.pb)
            case let .delete(kind): .delete(kind.pb)
            case let .move(kind): .move(kind.pb)
            }
        }()
    }
}

extension Symbolic_Pb_SymbolAction: ProtobufParsable {
    func decoded() throws -> SymbolAction {
        switch kind {
        case let .create(kind): .create(kind.decoded())
        case let .resize(kind): .resize(kind.decoded())
        case let .setGrid(kind): try .setGrid(kind.decoded())
        case let .delete(kind): .delete(kind.decoded())
        case let .move(kind): .move(kind.decoded())
        case .none: throw ProtobufParseError.invalidEmptyOneOf
        }
    }
}

// MARK: - ItemAction

extension ItemAction.Group: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_ItemAction.Group) {
        pb.groupID = groupId.pb
        pb.members = members.map { $0.pb }
        if let inSymbolId = inSymbolId {
            pb.inSymbolID = inSymbolId.pb
        }
        if let inGroupId = inGroupId {
            pb.inGroupID = inGroupId.pb
        }
    }
}

extension Symbolic_Pb_ItemAction.Group: ProtobufParsable {
    func decoded() -> ItemAction.Group {
        .init(groupId: groupID.decoded(), members: members.map { $0.decoded() }, inSymbolId: inSymbolID.decoded(), inGroupId: inGroupID.decoded())
    }
}

extension ItemAction.Ungroup: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_ItemAction.Ungroup) {
        pb.groupIds = groupIds.map { $0.pb }
    }
}

extension Symbolic_Pb_ItemAction.Ungroup: ProtobufParsable {
    func decoded() -> ItemAction.Ungroup {
        .init(groupIds: groupIds.map { $0.decoded() })
    }
}

extension ItemAction.Reorder: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_ItemAction.Reorder) {
        pb.itemID = itemId.pb
        pb.toItemID = itemId.pb
        pb.isAfter = isAfter
    }
}

extension Symbolic_Pb_ItemAction.Reorder: ProtobufParsable {
    func decoded() -> ItemAction.Reorder {
        .init(itemId: itemID.decoded(), toItemId: toItemID.decoded(), isAfter: isAfter)
    }
}

extension ItemAction.SetName: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_ItemAction.SetName) {
        pb.itemID = itemId.pb
        name.map { pb.name = $0 }
    }
}

extension Symbolic_Pb_ItemAction.SetName: ProtobufParsable {
    func decoded() -> ItemAction.SetName {
        .init(itemId: itemID.decoded(), name: hasName ? name : nil)
    }
}

extension ItemAction.SetLocked: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_ItemAction.SetLocked) {
        pb.itemIds = itemIds.map { $0.pb }
        pb.locked = locked
    }
}

extension Symbolic_Pb_ItemAction.SetLocked: ProtobufParsable {
    func decoded() -> ItemAction.SetLocked {
        .init(itemIds: itemIds.map { $0.decoded() }, locked: locked)
    }
}

extension ItemAction: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_ItemAction) {
        pb.kind = {
            switch self {
            case let .group(kind): .group(kind.pb)
            case let .ungroup(kind): .ungroup(kind.pb)
            case let .reorder(kind): .reorder(kind.pb)
            case let .setName(kind): .setName(kind.pb)
            case let .setLocked(kind): .setLocked(kind.pb)
            }
        }()
    }
}

extension Symbolic_Pb_ItemAction: ProtobufParsable {
    func decoded() throws -> ItemAction {
        switch kind {
        case let .group(kind): .group(kind.decoded())
        case let .ungroup(kind): .ungroup(kind.decoded())
        case let .reorder(kind): .reorder(kind.decoded())
        case let .setName(kind): .setName(kind.decoded())
        case let .setLocked(kind): .setLocked(kind.decoded())
        case .none: throw ProtobufParseError.invalidEmptyOneOf
        }
    }
}

// MARK: - WorldAction

extension WorldAction.SetGrid: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_WorldAction.SetGrid) {
        grid.map { pb.grid = $0.pb }
    }
}

extension Symbolic_Pb_WorldAction.SetGrid: ProtobufParsable {
    func decoded() throws -> WorldAction.SetGrid {
        try .init(grid: grid.decoded())
    }
}

extension WorldAction.SetSymbolIds: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_WorldAction.SetSymbolIds) {
        pb.symbolIds = symbolIds.map { $0.pb }
    }
}

extension Symbolic_Pb_WorldAction.SetSymbolIds: ProtobufParsable {
    func decoded() -> WorldAction.SetSymbolIds {
        .init(symbolIds: symbolIds.map { $0.decoded() })
    }
}

extension WorldAction: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_WorldAction) {
        pb.kind = {
            switch self {
            case let .setGrid(kind): .setGrid(kind.pb)
            case let .setSymbolIds(kind): .setSymbolIds(kind.pb)
            }
        }()
    }
}

extension Symbolic_Pb_WorldAction: ProtobufParsable {
    func decoded() throws -> WorldAction {
        switch kind {
        case let .setGrid(kind): try .setGrid(kind.decoded())
        case let .setSymbolIds(kind): .setSymbolIds(kind.decoded())
        case .none: throw ProtobufParseError.invalidEmptyOneOf
        }
    }
}

// MARK: - DocumentAction

extension DocumentAction: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_DocumentAction) {
        pb.kind = {
            switch self {
            case let .path(kind): .pathAction(kind.pb)
            case let .symbol(kind): .symbolAction(kind.pb)
            case let .item(kind): .itemAction(kind.pb)
            case let .world(kind): .worldAction(kind.pb)
            }
        }()
    }
}

extension Symbolic_Pb_DocumentAction: ProtobufParsable {
    func decoded() throws -> DocumentAction {
        switch kind {
        case let .pathAction(kind): try .path(kind.decoded())
        case let .symbolAction(kind): try .symbol(kind.decoded())
        case let .itemAction(kind): try .item(kind.decoded())
        case let .worldAction(kind): try .world(kind.decoded())
        case .none: throw ProtobufParseError.invalidEmptyOneOf
        }
    }
}
