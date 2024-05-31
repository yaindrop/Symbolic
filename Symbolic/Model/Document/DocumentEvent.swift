import Foundation

// MARK: - CompoundEvent

struct CompoundEvent: Equatable {
    enum Kind: Equatable {
        case pathEvent(PathEvent)
        case itemEvent(ItemEvent)
    }

    let events: [Kind]
}

// MARK: - PathEvent

enum PathEvent: Equatable {
    struct Create: Equatable { let path: Path }
    struct Delete: Equatable { let pathId: UUID }
    struct Update: Equatable { let pathId: UUID, kind: Kind }
    enum Compound: Equatable {
        struct Merge: Equatable { let pathId: UUID, endingNodeId: UUID, mergedPathId: UUID, mergedEndingNodeId: UUID }

        struct NodeBreak: Equatable { let pathId: UUID, nodeId: UUID, newNodeId: UUID, newPathId: UUID } // break path at node, creating a new ending node at the same position, and a new path when the current path is not closed
        struct EdgeBreak: Equatable { let pathId: UUID, fromNodeId: UUID, newPathId: UUID } // break path at edge, creating a new path when the current path is not closed

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
    struct Move: Equatable { let offset: Vector2 }

    struct NodeCreate: Equatable { let prevNodeId: UUID?, node: PathNode }
    struct NodeUpdate: Equatable { let node: PathNode }
    struct NodeDelete: Equatable { let nodeId: UUID }

    struct EdgeUpdate: Equatable { let fromNodeId: UUID, edge: PathEdge }

    enum Kind: Equatable {
        case move(Move)
        case nodeCreate(NodeCreate)
        case nodeDelete(NodeDelete)
        case nodeUpdate(NodeUpdate)
        case edgeUpdate(EdgeUpdate)
    }
}

// MARK: - ItemEvent

enum ItemEvent: Equatable {
    struct SetMembers: Equatable { let members: [UUID], inGroupId: UUID? }

    case setMembers(SetMembers)
}

// MARK: - DocumentEvent

struct DocumentEvent: Identifiable, Equatable {
    enum Kind: Equatable {
        case compoundEvent(CompoundEvent)
        case pathEvent(PathEvent)
        case itemEvent(ItemEvent)
    }

    let id: UUID = .init()
    let time: Date = .init()
    let kind: Kind
    let action: DocumentAction
}

extension PathEvent {
    init(in pathId: UUID, _ kind: PathEvent.Update.Kind) {
        self = .update(.init(pathId: pathId, kind: kind))
    }
}
