import Foundation

enum PathAction {
    struct Load { let path: Path }

    struct Create { let path: Path }

    struct DeleteNode { let pathId: UUID, nodeId: UUID }
    struct BreakAtNode { let pathId: UUID, nodeId: UUID }
    struct BreakAtEdge { let pathId: UUID, fromNodeId: UUID }

    struct ChangeEdge { let pathId: UUID, fromNodeId: UUID, to: PathEdge.Case }

    struct SetNodePosition { let pathId: UUID, nodeId: UUID, position: Point2 }
    struct SetEdgeArc { let pathId: UUID, fromNodeId: UUID, arc: PathEdge.Arc }
    struct SetEdgeBezier { let pathId: UUID, fromNodeId: UUID, bezier: PathEdge.Bezier }
    struct SetEdgeLine { let pathId: UUID, fromNodeId: UUID }

    struct AddEndingNode { let pathId: UUID, endingNodeId: UUID, newNodeId: UUID, offset: Vector2 }
    struct SplitSegment { let pathId: UUID, fromNodeId: UUID, paramT: Scalar, newNodeId: UUID, offset: Vector2 }

    struct MovePath { let pathId: UUID, offset: Vector2 }
    struct MoveNode { let pathId: UUID, nodeId: UUID, offset: Vector2 }
    struct MoveEdge { let pathId: UUID, fromNodeId: UUID, offset: Vector2 }
    struct MoveEdgeBezier { let pathId: UUID, fromNodeId: UUID, offset0: Vector2, offset1: Vector2 }

    struct MovePaths { let pathIds: [UUID], offset: Vector2 }
    struct DeletePaths { let pathIds: [UUID] }

    case load(Load)

    case create(Create)

    case addEndingNode(AddEndingNode)
    case splitSegment(SplitSegment)

    case deleteNode(DeleteNode)
    case breakAtNode(BreakAtNode)
    case breakAtEdge(BreakAtEdge)

    case changeEdge(ChangeEdge)

    case setNodePosition(SetNodePosition)
    case setEdgeArc(SetEdgeArc)
    case setEdgeBezier(SetEdgeBezier)
    case setEdgeLine(SetEdgeLine)

    case movePath(MovePath)
    case moveNode(MoveNode)
    case moveEdge(MoveEdge)
    case moveEdgeBezier(MoveEdgeBezier)

    case movePaths(MovePaths)
    case deletePaths(DeletePaths)
}

enum DocumentAction {
    case pathAction(PathAction)
}
