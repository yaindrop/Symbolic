import Foundation

fileprivate protocol PathActionSingleKind: SelfTransformable {}

extension PathAction.Single {
    struct DeleteNode: PathActionSingleKind { let nodeId: UUID }

    struct SetNodePosition: PathActionSingleKind { let nodeId: UUID, position: Point2 }
    struct SetEdge: PathActionSingleKind { let fromNodeId: UUID, edge: PathEdge }

    struct AddEndingNode: PathActionSingleKind { let endingNodeId: UUID, newNodeId: UUID, offset: Vector2 }
    struct SplitSegment: PathActionSingleKind { let fromNodeId: UUID, paramT: Scalar, newNodeId: UUID, offset: Vector2 }

    struct Move: PathActionSingleKind { let offset: Vector2 }
    struct MoveNode: PathActionSingleKind { let nodeId: UUID, offset: Vector2 }
    struct MoveEdge: PathActionSingleKind { let fromNodeId: UUID, offset: Vector2 }
    struct MoveEdgeControl: PathActionSingleKind { let fromNodeId: UUID, offset0: Vector2, offset1: Vector2 }

    enum Kind {
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

enum PathAction {
    struct Load { let path: Path }

    struct Create { let path: Path }

    struct Move { let pathIds: [UUID], offset: Vector2 }
    struct Delete { let pathIds: [UUID] }

    struct Single { let pathId: UUID, kind: Kind }

    struct Merge { let pathId: UUID, endingNodeId: UUID, mergedPathId: UUID, mergedEndingNodeId: UUID }
    struct BreakAtNode { let pathId: UUID, nodeId: UUID, newNodeId: UUID, newPathId: UUID }
    struct BreakAtEdge { let pathId: UUID, fromNodeId: UUID, newPathId: UUID }

    case load(Load)
    case create(Create)

    case move(Move)
    case delete(Delete)

    case single(Single)

    case merge(Merge)
    case breakAtNode(BreakAtNode)
    case breakAtEdge(BreakAtEdge)
}

enum ItemAction {
    struct Group { let group: CanvasItemGroup, inGroupId: UUID? }
    struct Ungroup { let groupIds: [UUID] }
    struct Reorder { let members: [UUID], inGroupId: UUID? }

    case group(Group)
    case ungroup(Ungroup)
    case reorder(Reorder)
}

enum DocumentAction {
    case pathAction(PathAction)
    case itemAction(ItemAction)
}
