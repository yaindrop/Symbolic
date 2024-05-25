import Foundation

fileprivate protocol PathActionSingleKind: SelfTransformable {}

extension PathAction.Single {
    struct AddEndingNode: PathActionSingleKind { let endingNodeId: UUID, newNodeId: UUID, offset: Vector2 }
    struct SplitSegment: PathActionSingleKind { let fromNodeId: UUID, paramT: Scalar, newNodeId: UUID, offset: Vector2 }

    struct DeleteNode: PathActionSingleKind { let nodeId: UUID }
    struct BreakAtNode: PathActionSingleKind { let nodeId: UUID }
    struct BreakAtEdge: PathActionSingleKind { let fromNodeId: UUID }

    struct SetNodePosition: PathActionSingleKind { let nodeId: UUID, position: Point2 }
    struct SetEdge: PathActionSingleKind { let fromNodeId: UUID, edge: PathEdge }

    struct MovePath: PathActionSingleKind { let offset: Vector2 }
    struct MoveNode: PathActionSingleKind { let nodeId: UUID, offset: Vector2 }
    struct MoveEdge: PathActionSingleKind { let fromNodeId: UUID, offset: Vector2 }
    struct MoveEdgeBezier: PathActionSingleKind { let fromNodeId: UUID, offset0: Vector2, offset1: Vector2 }

    enum Kind {
        case addEndingNode(AddEndingNode)
        case splitSegment(SplitSegment)

        case deleteNode(DeleteNode)
        case breakAtNode(BreakAtNode)
        case breakAtEdge(BreakAtEdge)

        case setNodePosition(SetNodePosition)
        case setEdge(SetEdge)

        case movePath(MovePath)
        case moveNode(MoveNode)
        case moveEdge(MoveEdge)
        case moveEdgeBezier(MoveEdgeBezier)
    }
}

enum PathAction {
    struct Load { let path: Path }

    struct Create { let path: Path }

    struct Single { let pathId: UUID, kind: Kind }

    struct MovePaths { let pathIds: [UUID], offset: Vector2 }
    struct DeletePaths { let pathIds: [UUID] }

    case load(Load)

    case create(Create)

    case single(Single)

    case movePaths(MovePaths)
    case deletePaths(DeletePaths)
}

enum DocumentAction {
    case pathAction(PathAction)
}
