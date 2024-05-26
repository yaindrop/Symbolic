import Foundation

// MARK: - CompoundEvent

struct CompoundEvent {
    enum Kind {
        case pathEvent(PathEvent)
        case groupEvent(GroupEvent)
        case itemEvent(ItemEvent)
    }

    let events: [Kind]
}

// MARK: - PathEvent

enum PathEvent {
    struct Create { let path: Path }
    struct Delete { let pathId: UUID }
    struct Update { let pathId: UUID, kind: Kind }
    enum Compound {
        struct Merge { let pathId: UUID, endingNodeId: UUID, mergedPathId: UUID, mergedEndingNodeId: UUID }

        struct NodeBreak { let pathId: UUID, nodeId: UUID, newNodeId: UUID, newPathId: UUID } // break path at node, creating a new ending node at the same position, and a new path when the current path is not closed
        struct EdgeBreak { let pathId: UUID, fromNodeId: UUID, newPathId: UUID } // break path at edge, creating a new path when the current path is not closed

        case merge(Merge)
        case nodeBreak(NodeBreak)
        case edgeBreak(EdgeBreak)
    }

    case create(Create)
    case update(Update)
    case delete(Delete)
    case compound(Compound)
}

// MARK: Update

extension PathEvent.Update {
    struct Move { let offset: Vector2 }

    struct NodeCreate { let prevNodeId: UUID?, node: PathNode }
    struct NodeUpdate { let node: PathNode }
    struct NodeDelete { let nodeId: UUID }

    struct EdgeUpdate { let fromNodeId: UUID, edge: PathEdge }

    enum Kind {
        case move(Move)
        case nodeCreate(NodeCreate)
        case nodeDelete(NodeDelete)
        case nodeUpdate(NodeUpdate)
        case edgeUpdate(EdgeUpdate)
    }
}

// MARK: - GroupEvent

struct GroupEvent {
    let group: CanvasGroup
}

// MARK: - ItemEvent

struct ItemEvent {
    let item: CanvasItem
}

// MARK: - DocumentEvent

struct DocumentEvent: Identifiable {
    enum Kind {
        case compoundEvent(CompoundEvent)
        case pathEvent(PathEvent)
        case groupEvent(GroupEvent)
        case itemEvent(ItemEvent)
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
