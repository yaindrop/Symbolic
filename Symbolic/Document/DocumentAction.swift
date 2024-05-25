import Foundation

fileprivate protocol PathActionSingleKind: SelfTransformable {}

extension PathAction.Single {
    struct AddEndingNode: PathActionSingleKind { let endingNodeId: UUID, newNodeId: UUID, offset: Vector2 }
    struct SplitSegment: PathActionSingleKind { let fromNodeId: UUID, paramT: Scalar, newNodeId: UUID, offset: Vector2 }

    struct DeleteNode: PathActionSingleKind { let nodeId: UUID }
    struct BreakAtNode: PathActionSingleKind { let nodeId: UUID, newNodeId: UUID, newPathId: UUID }
    struct BreakAtEdge: PathActionSingleKind { let fromNodeId: UUID, newPathId: UUID }

    struct SetNodePosition: PathActionSingleKind { let nodeId: UUID, position: Point2 }
    struct SetEdge: PathActionSingleKind { let fromNodeId: UUID, edge: PathEdge }

    struct Move: PathActionSingleKind { let offset: Vector2 }
    struct MoveNode: PathActionSingleKind { let nodeId: UUID, offset: Vector2 }
    struct MoveEdge: PathActionSingleKind { let fromNodeId: UUID, offset: Vector2 }
    struct MoveEdgeControl: PathActionSingleKind { let fromNodeId: UUID, offset0: Vector2, offset1: Vector2 }

    enum Kind {
        case deleteNode(DeleteNode)
        case breakAtNode(BreakAtNode)
        case breakAtEdge(BreakAtEdge)

        // handle actions
        case addEndingNode(AddEndingNode)
        case splitSegment(SplitSegment)

        case move(Move)
        case moveNode(MoveNode)
        case moveEdge(MoveEdge)
        case moveEdgeControl(MoveEdgeControl)

        case setNodePosition(SetNodePosition)
        case setEdge(SetEdge)
    }
}

enum PathAction {
    struct Load { let path: Path }

    struct Create { let path: Path }

    struct Move { let pathIds: [UUID], offset: Vector2 }
    struct Delete { let pathIds: [UUID] }

    struct Merge { let pathId: UUID, endingNodeId: UUID, mergedPathId: UUID, mergedEndingNodeId: UUID }

    struct Single { let pathId: UUID, kind: Kind }

    case load(Load)
    case create(Create)

    case move(Move)
    case delete(Delete)

    case merge(Merge)

    case single(Single)
}

enum DocumentAction {
    case pathAction(PathAction)
}
