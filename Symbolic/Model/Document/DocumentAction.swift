import Foundation

// MARK: - ItemAction

enum ItemAction: Equatable, Codable {
    struct Group: Equatable, Codable { var group: ItemGroup, inGroupId: UUID? }
    struct Ungroup: Equatable, Codable { var groupIds: [UUID] }
    struct Reorder: Equatable, Codable { var members: [UUID], inGroupId: UUID? }

    case group(Group)
    case ungroup(Ungroup)
    case reorder(Reorder)
}

// MARK: - PathAction

enum PathAction: Equatable, Codable {
    struct Load: Equatable, Codable { var paths: [Path] }

    struct Create: Equatable, Codable { var path: Path }
    struct Delete: Equatable, Codable { var pathIds: [UUID] }
    struct Move: Equatable, Codable { var pathIds: [UUID], offset: Vector2 }
    struct Update: Equatable, Codable { var pathId: UUID, kind: Kind }

    // multi update
    struct Merge: Equatable, Codable { var pathId: UUID, endingNodeId: UUID, mergedPathId: UUID, mergedEndingNodeId: UUID }
    struct BreakAtNode: Equatable, Codable { var pathId: UUID, nodeId: UUID, newPathId: UUID, newNodeId: UUID, offset: Vector2 }
    struct BreakAtSegment: Equatable, Codable { var pathId: UUID, fromNodeId: UUID, newPathId: UUID }

    case load(Load)

    case create(Create)
    case delete(Delete)
    case move(Move)
    case update(Update)

    case merge(Merge)
    case breakAtNode(BreakAtNode)
    case breakAtSegment(BreakAtSegment)
}

// MARK: Update

extension PathAction.Update {
    struct DeleteNodes: Equatable, Codable { var nodeIds: [UUID] }

    struct UpdateNode: Equatable, Codable { var nodeId: UUID, node: PathNode }

    struct AddEndingNode: Equatable, Codable { var endingNodeId: UUID, newNodeId: UUID, offset: Vector2 }
    struct SplitSegment: Equatable, Codable { var fromNodeId: UUID, paramT: Scalar, newNodeId: UUID, offset: Vector2 }

    struct MoveNodes: Equatable, Codable { var nodeIds: [UUID], offset: Vector2 }
    struct MoveNodeControl: Equatable, Codable { var nodeId: UUID, offset: Vector2, controlType: PathBezierControlType }

    enum Kind: Equatable, Codable {
        case deleteNodes(DeleteNodes)

        case updateNode(UpdateNode)

        // handle actions
        case addEndingNode(AddEndingNode)
        case splitSegment(SplitSegment)

        case moveNodes(MoveNodes)
        case moveNodeControl(MoveNodeControl)
    }
}

// MARK: - PathPropertyAction

enum PathPropertyAction: Equatable, Codable {
    struct Update: Equatable, Codable { var pathId: UUID, kind: Kind }

    case update(Update)
}

extension PathPropertyAction.Update {
    struct SetName: Equatable, Codable { var name: String? }
    struct SetNodeType: Equatable, Codable { var nodeIds: [UUID], nodeType: PathNodeType? }
    struct SetSegmentType: Equatable, Codable { var fromNodeIds: [UUID], segmentType: PathSegmentType? }

    enum Kind: Equatable, Codable {
        case setName(SetName)
        case setNodeType(SetNodeType)
        case setSegmentType(SetSegmentType)
    }
}

// MARK: - DocumentAction

enum DocumentAction: Equatable, Codable {
    case item(ItemAction)
    case path(PathAction)
    case pathProperty(PathPropertyAction)
}
