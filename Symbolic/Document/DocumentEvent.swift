import Foundation

// MARK: - PathEvent

struct PathCreate {
    let path: Path
}

struct PathDelete {
    let pathId: UUID
}

// MARK: - PathUpdate

struct PathEdgeUpdate {
    let fromNodeId: UUID
    let edge: PathEdge
}

struct PathNodeCreate {
    let prevNodeId: UUID?
    let node: PathNode
}

struct PathNodeUpdate {
    let node: PathNode
}

struct PathNodeDelete {
    let nodeId: UUID
}

enum PathUpdateKind {
    case edgeUpdate(PathEdgeUpdate)
    case nodeCreate(PathNodeCreate)
    case nodeDelete(PathNodeDelete)
    case nodeUpdate(PathNodeUpdate)
}

struct PathUpdate {
    let pathId: UUID
    let kind: PathUpdateKind
}

enum PathEvent {
    case create(PathCreate)
    case update(PathUpdate)
    case delete(PathDelete)
}

enum DocumentEventKind {
    case pathEvent(PathEvent)
}

struct DocumentEvent {
    let id: UUID = UUID()
    let time: Date = Date()
    let kind: DocumentEventKind
}

extension DocumentEvent {
    init(inPath pathId: UUID, updateEdgeFrom fromNodeId: UUID, _ edge: PathEdge) {
        let edgeUpdate = PathEdgeUpdate(fromNodeId: fromNodeId, edge: edge)
        let pathUpdate = PathUpdate(pathId: pathId, kind: .edgeUpdate(edgeUpdate))
        self.init(kind: .pathEvent(.update(pathUpdate)))
    }

    init(inPath pathId: UUID, createNodeAfter prevNodeId: UUID?, _ node: PathNode) {
        let nodeCreate = PathNodeCreate(prevNodeId: prevNodeId, node: node)
        let pathUpdate = PathUpdate(pathId: pathId, kind: .nodeCreate(nodeCreate))
        self.init(kind: .pathEvent(.update(pathUpdate)))
    }

    init(inPath pathId: UUID, updateNode node: PathNode) {
        let nodeUpdate = PathNodeUpdate(node: node)
        let pathUpdate = PathUpdate(pathId: pathId, kind: .nodeUpdate(nodeUpdate))
        self.init(kind: .pathEvent(.update(pathUpdate)))
    }

    init(inPath pathId: UUID, deleteNode nodeId: UUID) {
        let nodeDelete = PathNodeDelete(nodeId: nodeId)
        let pathUpdate = PathUpdate(pathId: pathId, kind: .nodeDelete(nodeDelete))
        self.init(kind: .pathEvent(.update(pathUpdate)))
    }
}
