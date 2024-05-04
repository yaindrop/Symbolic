import Foundation

enum PathAction {
    struct Load { let path: Path }

    struct SplitSegment { let pathId: UUID, fromNodeId: UUID, paramT: Scalar, newNode: PathNode }
    struct DeleteNode { let pathId: UUID, nodeId: UUID }
    struct DeleteEdge { let pathId: UUID, fromNodeId: UUID }

    struct SetNodePosition { let pathId: UUID, nodeId: UUID, position: Point2 }
    struct SetEdgeLine { let pathId: UUID, fromNodeId: UUID }
    struct SetEdgeBezier { let pathId: UUID, fromNodeId: UUID, bezier: PathEdge.Bezier }
    struct SetEdgeArc { let pathId: UUID, fromNodeId: UUID, arc: PathEdge.Arc }

    struct MoveNode { let pathId: UUID, nodeId: UUID, offset: Vector2 }
    struct MoveEdge { let pathId: UUID, fromNodeId: UUID, offset: Vector2 }

    case load(Load)

    case splitSegment(SplitSegment)
    case deleteNode(DeleteNode)
    case deleteEdge(DeleteEdge)

    case setNodePosition(SetNodePosition)
    case setEdgeLine(SetEdgeLine)
    case setEdgeBezier(SetEdgeBezier)
    case setEdgeArc(SetEdgeArc)

    case moveNode(MoveNode)
    case moveEdge(MoveEdge)
}

enum DocumentAction {
    case pathAction(PathAction)
}
