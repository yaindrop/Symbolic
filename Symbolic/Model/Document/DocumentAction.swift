import Foundation

extension PathAction.Single {
    struct DeleteNode: Equatable { let nodeId: UUID }

    struct SetNodePosition: Equatable { let nodeId: UUID, position: Point2 }
    struct SetEdge: Equatable { let fromNodeId: UUID, edge: PathEdge }

    struct AddEndingNode: Equatable { let endingNodeId: UUID, newNodeId: UUID, offset: Vector2 }
    struct SplitSegment: Equatable { let fromNodeId: UUID, paramT: Scalar, newNodeId: UUID, offset: Vector2 }

    struct Move: Equatable { let offset: Vector2 }
    struct MoveNode: Equatable { let nodeId: UUID, offset: Vector2 }
    struct MoveEdge: Equatable { let fromNodeId: UUID, offset: Vector2 }
    struct MoveEdgeControl: Equatable { let fromNodeId: UUID, offset0: Vector2, offset1: Vector2 }

    enum Kind: Equatable {
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

enum PathAction: Equatable {
    struct Load: Equatable { let path: Path }

    struct Create: Equatable { let path: Path }

    struct Move: Equatable { let pathIds: [UUID], offset: Vector2 }
    struct Delete: Equatable { let pathIds: [UUID] }

    struct Single: Equatable { let pathId: UUID, kind: Kind }

    struct Merge: Equatable { let pathId: UUID, endingNodeId: UUID, mergedPathId: UUID, mergedEndingNodeId: UUID }
    struct BreakAtNode: Equatable { let pathId: UUID, nodeId: UUID, newNodeId: UUID, newPathId: UUID }
    struct BreakAtEdge: Equatable { let pathId: UUID, fromNodeId: UUID, newPathId: UUID }

    case load(Load)
    case create(Create)

    case move(Move)
    case delete(Delete)

    case single(Single)

    case merge(Merge)
    case breakAtNode(BreakAtNode)
    case breakAtEdge(BreakAtEdge)
}

enum ItemAction: Equatable {
    struct Group: Equatable { let group: ItemGroup, inGroupId: UUID? }
    struct Ungroup: Equatable { let groupIds: [UUID] }
    struct Reorder: Equatable { let members: [UUID], inGroupId: UUID? }

    case group(Group)
    case ungroup(Ungroup)
    case reorder(Reorder)
}

enum DocumentAction: Equatable {
    case pathAction(PathAction)
    case itemAction(ItemAction)
}
