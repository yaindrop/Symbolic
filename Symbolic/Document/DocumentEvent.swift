import Foundation

// MARK: - PathEvent

struct PathCreate {
    let path: Path
}

struct PathDelete {
    let pathId: UUID
}

// MARK: - PathUpdate

struct PathNodeCreate {
    let prevNodeId: UUID?
    let node: PathNode
}

struct PathNodeUpdate {
    let node: PathNode
}

struct PathEdgeUpdate {
    let fromNodeId: UUID
    let edge: PathEdge
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
    let time: Date
    let kind: DocumentEventKind
}
