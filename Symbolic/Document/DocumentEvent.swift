import Foundation

// MARK: - PathEvent

enum PathEvent {
    struct Create { let path: Path }
    struct Delete { let pathId: UUID }
    struct Update { let pathId: UUID, kind: Kind }

    case create(Create)
    case update(Update)
    case delete(Delete)
}

// MARK: Update

extension PathEvent.Update {
    struct Move { let offset: Vector2 }

    struct NodeCreate { let prevNodeId: UUID?, node: PathNode }
    struct NodeUpdate { let node: PathNode }
    struct NodeDelete { let nodeId: UUID }
    struct NodeBreak { let nodeId: UUID, newNodeId: UUID, newPathId: UUID } // break path at node, creating a new ending node at the same position, and a new path when the current path is not closed

    struct EdgeUpdate { let fromNodeId: UUID, edge: PathEdge }
    struct EdgeBreak { let fromNodeId: UUID, newPathId: UUID } // break path at edge, creating a new path when the current path is not closed

    enum Kind {
        case move(Move)
        case nodeCreate(NodeCreate)
        case nodeDelete(NodeDelete)
        case nodeUpdate(NodeUpdate)
        case nodeBreak(NodeBreak)
        case edgeUpdate(EdgeUpdate)
        case edgeBreak(EdgeBreak)
    }
}

// MARK: - CompoundEvent

struct CompoundEvent {
    enum Kind {
        case pathEvent(PathEvent)
    }

    let events: [Kind]
}

// MARK: - DocumentEvent

struct DocumentEvent: Identifiable {
    enum Kind {
        case pathEvent(PathEvent)
        case compoundEvent(CompoundEvent)
    }

    let id: UUID = UUID()
    let time: Date = Date()
    let kind: Kind
    let action: DocumentAction
}

extension PathEvent {
    init(in pathId: UUID, _ kind: PathEvent.Update.Kind) {
        self = .update(.init(pathId: pathId, kind: kind))
    }
}
