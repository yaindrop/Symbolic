import Foundation

enum DocumentAction {
    enum PathAction {
        case nodePosition(pathId: UUID, fromNodeId: UUID, position: Point2)
        case bezier(pathId: UUID, fromNodeId: UUID, bezier: PathEdge.Bezier)
        case arc(pathId: UUID, fromNodeId: UUID, arc: PathEdge.Arc)
        case aroundNode(pathId: UUID, nodeId: UUID, delta: Vector2)
        case aroundEdge(pathId: UUID, fromNodeId: UUID, delta: Vector2)
    }

    case pathAction(PathAction)
}
