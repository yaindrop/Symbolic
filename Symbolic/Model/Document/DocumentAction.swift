import Foundation

extension PathAction.Single {
    struct DeleteNode: Equatable, Encodable { let nodeId: UUID }

    struct SetNodePosition: Equatable, Encodable { let nodeId: UUID, position: Point2 }
    struct SetEdge: Equatable, Encodable { let fromNodeId: UUID, edge: PathEdge }

    struct AddEndingNode: Equatable, Encodable { let endingNodeId: UUID, newNodeId: UUID, offset: Vector2 }
    struct SplitSegment: Equatable, Encodable { let fromNodeId: UUID, paramT: Scalar, newNodeId: UUID, offset: Vector2 }

    struct Move: Equatable, Encodable { let offset: Vector2 }
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

        case move(Move)
        case moveNode(MoveNode)
        case moveEdge(MoveEdge)
        case moveEdgeControl(MoveEdgeControl)
    }
}

enum PathAction: Equatable, Encodable {
    struct Load: Equatable, Encodable { let path: Path }

    struct Create: Equatable, Encodable { let path: Path }

    struct Move: Equatable, Encodable { let pathIds: [UUID], offset: Vector2 }
    struct Delete: Equatable, Encodable { let pathIds: [UUID] }

    struct Single: Equatable, Encodable { let pathId: UUID, kind: Kind }

    struct Merge: Equatable, Encodable { let pathId: UUID, endingNodeId: UUID, mergedPathId: UUID, mergedEndingNodeId: UUID }
    struct BreakAtNode: Equatable, Encodable { let pathId: UUID, nodeId: UUID, newNodeId: UUID, newPathId: UUID }
    struct BreakAtEdge: Equatable, Encodable { let pathId: UUID, fromNodeId: UUID, newPathId: UUID }

    case load(Load)
    case create(Create)

    case move(Move)
    case delete(Delete)

    case single(Single)

    case merge(Merge)
    case breakAtNode(BreakAtNode)
    case breakAtEdge(BreakAtEdge)
}

enum ItemAction: Equatable, Encodable {
    struct Group: Equatable, Encodable { let group: ItemGroup, inGroupId: UUID? }
    struct Ungroup: Equatable, Encodable { let groupIds: [UUID] }
    struct Reorder: Equatable, Encodable { let members: [UUID], inGroupId: UUID? }

    case group(Group)
    case ungroup(Ungroup)
    case reorder(Reorder)
}

enum DocumentAction: Equatable, Encodable {
    case pathAction(PathAction)
    case itemAction(ItemAction)
}
