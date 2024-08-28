import Foundation

// MARK: - PathAction

enum PathAction: Equatable, Codable {
    struct Load: Equatable, Codable { var symbolId: UUID, pathIds: [UUID], paths: [Path] }

    struct Create: Equatable, Codable { var symbolId: UUID, pathId: UUID, path: Path }
    struct Update: Equatable, Codable { var pathId: UUID, kind: Kind }

    struct Delete: Equatable, Codable { var pathIds: [UUID] }
    struct Move: Equatable, Codable { var pathIds: [UUID], offset: Vector2 }

    case load(Load)

    case create(Create)
    case update(Update)

    case delete(Delete)
    case move(Move)
}

// MARK: Update

extension PathAction.Update {
    struct AddEndingNode: Equatable, Codable { var endingNodeId: UUID, newNodeId: UUID, offset: Vector2 }
    struct SplitSegment: Equatable, Codable { var fromNodeId: UUID, paramT: Scalar, newNodeId: UUID, offset: Vector2 }
    struct DeleteNodes: Equatable, Codable { var nodeIds: [UUID] }

    struct UpdateNode: Equatable, Codable { var nodeId: UUID, node: PathNode }
    struct UpdateSegment: Equatable, Codable { var fromNodeId: UUID, segment: PathSegment }

    struct MoveNodes: Equatable, Codable { var nodeIds: [UUID], offset: Vector2 }
    struct MoveNodeControl: Equatable, Codable { var nodeId: UUID, controlType: PathNodeControlType, offset: Vector2 }

    struct Merge: Equatable, Codable { var endingNodeId: UUID, mergedPathId: UUID, mergedEndingNodeId: UUID }
    struct Split: Equatable, Codable { var nodeId: UUID, newPathId: UUID, newNodeId: UUID? }

    struct SetName: Equatable, Codable { var name: String? }
    struct SetNodeType: Equatable, Codable { var nodeIds: [UUID], nodeType: PathNodeType? }
    struct SetSegmentType: Equatable, Codable { var fromNodeIds: [UUID], segmentType: PathSegmentType? }

    enum Kind: Equatable, Codable {
        case addEndingNode(AddEndingNode)
        case splitSegment(SplitSegment)
        case deleteNodes(DeleteNodes)

        case updateNode(UpdateNode)
        case updateSegment(UpdateSegment)

        case moveNodes(MoveNodes)
        case moveNodeControl(MoveNodeControl)

        case merge(Merge)
        case split(Split)

        case setName(SetName)
        case setNodeType(SetNodeType)
        case setSegmentType(SetSegmentType)
    }
}

enum SymbolAction: Equatable, Codable {
    struct Create: Equatable, Codable { let symbolId: UUID, origin: Point2, size: CGSize }
    struct Resize: Equatable, Codable { let symbolId: UUID, origin: Point2, size: CGSize }

    struct Delete: Equatable, Codable { let symbolIds: [UUID] }
    struct Move: Equatable, Codable { let symbolIds: [UUID], offset: Vector2 }

    case create(Create)
    case resize(Resize)

    case delete(Delete)
    case move(Move)
}

// MARK: - ItemAction

enum ItemAction: Equatable, Codable {
    struct Group: Equatable, Codable { var groupId: UUID, members: [UUID], inSymbolId: UUID?, inGroupId: UUID? }
    struct Ungroup: Equatable, Codable { var groupIds: [UUID] }
    struct Reorder: Equatable, Codable { var itemId: UUID, toItemId: UUID, isAfter: Bool }

    case group(Group)
    case ungroup(Ungroup)
    case reorder(Reorder)
}

// MARK: - DocumentAction

enum DocumentAction: Equatable, Codable {
    case path(PathAction)
    case symbol(SymbolAction)
    case item(ItemAction)
}
