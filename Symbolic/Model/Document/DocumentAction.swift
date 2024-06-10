import Foundation

// MARK: - ItemAction

enum ItemAction: Equatable, Encodable {
    struct Group: Equatable, Encodable { let group: ItemGroup, inGroupId: UUID? }
    struct Ungroup: Equatable, Encodable { let groupIds: [UUID] }
    struct Reorder: Equatable, Encodable { let members: [UUID], inGroupId: UUID? }

    case group(Group)
    case ungroup(Ungroup)
    case reorder(Reorder)
}

// MARK: - PathAction

enum PathAction: Equatable, Encodable {
    struct Load: Equatable, Encodable { let paths: [Path] }

    struct Create: Equatable, Encodable { let path: Path }
    struct Delete: Equatable, Encodable { let pathIds: [UUID] }
    struct Move: Equatable, Encodable { let pathIds: [UUID], offset: Vector2 }
    struct Update: Equatable, Encodable { let pathId: UUID, kind: Kind }

    // multi update
    struct Merge: Equatable, Encodable { let pathId: UUID, endingNodeId: UUID, mergedPathId: UUID, mergedEndingNodeId: UUID }
    struct BreakAtNode: Equatable, Encodable { let pathId: UUID, nodeId: UUID, newNodeId: UUID, newPathId: UUID }
    struct BreakAtEdge: Equatable, Encodable { let pathId: UUID, fromNodeId: UUID, newPathId: UUID }

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
    struct DeleteNode: Equatable, Encodable { let nodeId: UUID }

    struct SetNodePosition: Equatable, Encodable { let nodeId: UUID, position: Point2 }
    struct SetEdge: Equatable, Encodable { let fromNodeId: UUID, edge: PathEdge }

    struct AddEndingNode: Equatable, Encodable { let endingNodeId: UUID, newNodeId: UUID, offset: Vector2 }
    struct SplitSegment: Equatable, Encodable { let fromNodeId: UUID, paramT: Scalar, newNodeId: UUID, offset: Vector2 }

    struct MoveNode: Equatable, Encodable { let nodeId: UUID, offset: Vector2 }
    struct MoveEdge: Equatable, Encodable { let fromNodeId: UUID, offset: Vector2 }
    struct MoveEdgeControl: Equatable, Encodable { let fromNodeId: UUID, offset0: Vector2, offset1: Vector2 }

    enum Kind: Equatable, Encodable {
        case deleteNode(DeleteNode)

        case setNodePosition(SetNodePosition)
        case setEdge(SetEdge)

        // handle actions
        case addEndingNode(AddEndingNode)
        case splitSegment(SplitSegment)

        case moveNode(MoveNode)
        case moveEdge(MoveEdge)
        case moveEdgeControl(MoveEdgeControl)
    }
}

// MARK: - PathPropertyAction

enum PathPropertyAction: Equatable, Encodable {
    struct Update: Equatable, Encodable { let pathId: UUID, kind: Kind }

    case update(Update)
}

extension PathPropertyAction.Update {
    struct SetName: Equatable, Encodable { let name: String? }
    struct SetNodeType: Equatable, Encodable { let nodeIds: [UUID], nodeType: PathNodeType? }
    struct SetEdgeType: Equatable, Encodable { let fromNodeIds: [UUID], edgeType: PathEdgeType? }

    enum Kind: Equatable, Encodable {
        case setName(SetName)
        case setNodeType(SetNodeType)
        case setEdgeType(SetEdgeType)
    }
}

// MARK: - DocumentAction

enum DocumentAction: Equatable, Encodable {
    case item(ItemAction)
    case path(PathAction)
    case pathProperty(PathPropertyAction)
}
