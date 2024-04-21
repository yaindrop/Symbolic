import Foundation

// MARK: PathEvent

struct PathCreate {
    let path: Path
}

struct PathDelete {
    let pathId: UUID
}

// MARK: PathUpdate

struct PathVertexCreate {
    let prevVertexId: UUID?
    let vertex: PathVertex
}

struct PathVertexUpdate {
    let vertex: PathVertex
}

struct PathActionUpdate {
    let fromVertexId: UUID
    let action: PathAction
}

struct PathVertexDelete {
    let vertexId: UUID
}

enum PathUpdateKind {
    case vertexCreate(PathVertexCreate)
    case vertexUpdate(PathVertexUpdate)
    case actionUpdate(PathActionUpdate)
    case vertexDelete(PathVertexDelete)
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
    let time: Date
    let kind: DocumentEventKind
}
