import Foundation

// MARK: - ItemAction

enum ItemAction: Equatable, Codable {
    struct Group: Equatable, Codable { let group: ItemGroup, inGroupId: UUID? }
    struct Ungroup: Equatable, Codable { let groupIds: [UUID] }
    struct Reorder: Equatable, Codable { let members: [UUID], inGroupId: UUID? }

    case group(Group)
    case ungroup(Ungroup)
    case reorder(Reorder)
}

// MARK: - PathAction

enum PathAction: Equatable, Codable {
    struct Load: Equatable, Codable { let paths: [Path] }

    struct Create: Equatable, Codable { let path: Path }
    struct Delete: Equatable, Codable { let pathIds: [UUID] }
    struct Move: Equatable, Codable { let pathIds: [UUID], offset: Vector2 }
    struct Update: Equatable, Codable { let pathId: UUID, kind: Kind }

    // multi update
    struct Merge: Equatable, Codable { let pathId: UUID, endingNodeId: UUID, mergedPathId: UUID, mergedEndingNodeId: UUID }
    struct BreakAtNode: Equatable, Codable { let pathId: UUID, nodeId: UUID, newNodeId: UUID, newPathId: UUID }
    struct BreakAtEdge: Equatable, Codable { let pathId: UUID, fromNodeId: UUID, newPathId: UUID }

    case load(Load)

    case create(Create)
    case delete(Delete)
    case move(Move)
    case update(Update)

    case merge(Merge)
    case breakAtNode(BreakAtNode)
    case breakAtEdge(BreakAtEdge)
}

// MARK: Update

extension PathAction.Update {
    struct DeleteNode: Equatable, Codable { let nodeId: UUID }

    struct SetNodePosition: Equatable, Codable { let nodeId: UUID, position: Point2 }
    struct SetEdge: Equatable, Codable { let fromNodeId: UUID, edge: PathEdge }

    struct AddEndingNode: Equatable, Codable { let endingNodeId: UUID, newNodeId: UUID, offset: Vector2 }
    struct SplitSegment: Equatable, Codable { let fromNodeId: UUID, paramT: Scalar, newNodeId: UUID, offset: Vector2 }

    struct MoveNodes: Equatable, Codable { let nodeIds: [UUID], offset: Vector2 }
    struct MoveEdgeControl: Equatable, Codable { let fromNodeId: UUID, offset0: Vector2, offset1: Vector2 }

    enum Kind: Equatable, Codable {
        case deleteNode(DeleteNode)

        case setNodePosition(SetNodePosition)
        case setEdge(SetEdge)

        // handle actions
        case addEndingNode(AddEndingNode)
        case splitSegment(SplitSegment)

        case moveNodes(MoveNodes)
        case moveEdgeControl(MoveEdgeControl)
    }
}

// MARK: - PathPropertyAction

enum PathPropertyAction: Equatable, Codable {
    struct Update: Equatable, Codable { let pathId: UUID, kind: Kind }

    case update(Update)
}

extension PathPropertyAction.Update {
    struct SetName: Equatable, Codable { let name: String? }
    struct SetNodeType: Equatable, Codable { let nodeIds: [UUID], nodeType: PathNodeType? }
    struct SetEdgeType: Equatable, Codable { let fromNodeIds: [UUID], edgeType: PathEdgeType? }

    enum Kind: Equatable, Codable {
        case setName(SetName)
        case setNodeType(SetNodeType)
        case setEdgeType(SetEdgeType)
    }
}

// MARK: - DocumentAction

enum DocumentAction: Equatable, Codable {
    case item(ItemAction)
    case path(PathAction)
    case pathProperty(PathPropertyAction)
}
