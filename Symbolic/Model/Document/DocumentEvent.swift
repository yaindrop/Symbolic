import Foundation

// MARK: - ItemEvent

enum ItemEvent: Equatable, Encodable {
    struct SetMembers: Equatable, Encodable { let members: [UUID], inGroupId: UUID? }

    case setMembers(SetMembers)
}

// MARK: - PathEvent

enum PathEvent: Equatable, Encodable {
    struct Create: Equatable, Encodable { let paths: [Path] }
    struct Delete: Equatable, Encodable { let pathIds: [UUID] }
    struct Move: Equatable, Encodable { let pathIds: [UUID], offset: Vector2 }

    struct Update: Equatable, Encodable { let pathId: UUID, kinds: [Kind] }

    // multi update
    struct Merge: Equatable, Encodable { let pathId: UUID, endingNodeId: UUID, mergedPathId: UUID, mergedEndingNodeId: UUID }
    struct NodeBreak: Equatable, Encodable { let pathId: UUID, nodeId: UUID, newNodeId: UUID, newPathId: UUID } // break path at node, creating a new ending node at the same position, and a new path when the current path is not closed
    struct EdgeBreak: Equatable, Encodable { let pathId: UUID, fromNodeId: UUID, newPathId: UUID } // break path at edge, creating a new path when the current path is not closed

    case create(Create)
    case delete(Delete)
    case move(Move)
    case update(Update)

    // multi update
    case merge(Merge)
    case nodeBreak(NodeBreak)
    case edgeBreak(EdgeBreak)
}

// MARK: Update

extension PathEvent.Update {
    struct NodeCreate: Equatable, Encodable { let prevNodeId: UUID?, node: PathNode }
    struct NodeUpdate: Equatable, Encodable { let node: PathNode }
    struct NodeDelete: Equatable, Encodable { let nodeId: UUID }
    struct EdgeUpdate: Equatable, Encodable { let fromNodeId: UUID, edge: PathEdge }

    enum Kind: Equatable, Encodable {
        case nodeCreate(NodeCreate)
        case nodeDelete(NodeDelete)
        case nodeUpdate(NodeUpdate)
        case edgeUpdate(EdgeUpdate)
    }
}

// MARK: - PathPropertyEvent

enum PathPropertyEvent: Equatable, Encodable {
    struct Update: Equatable, Encodable { let pathId: UUID, kinds: [Kind] }

    case update(Update)
}

extension PathPropertyEvent.Update {
    struct SetName: Equatable, Encodable { let name: String? }
    struct SetNodeType: Equatable, Encodable { let nodeIds: [UUID], nodeType: PathNodeType? }
    struct SetEdgeType: Equatable, Encodable { let fromNodeIds: [UUID], edgeType: PathEdgeType? }

    enum Kind: Equatable, Encodable {
        case setName(SetName)
        case setNodeType(SetNodeType)
        case setEdgeType(SetEdgeType)
    }
}

// MARK: - SingleEvent

enum SingleEvent: Equatable, Encodable {
    case item(ItemEvent)
    case path(PathEvent)
    case pathProperty(PathPropertyEvent)
}

// MARK: - CompoundEvent

struct CompoundEvent: Equatable, Encodable {
    let events: [SingleEvent]
}

// MARK: - DocumentEvent

struct DocumentEvent: Identifiable, Equatable, Encodable {
    enum Kind: Equatable, Encodable {
        case single(SingleEvent)
        case compound(CompoundEvent)
    }

    let id: UUID = .init()
    let time: Date = .init()
    let kind: Kind
    let action: DocumentAction
}

extension PathEvent {
    var affectedPathIds: [UUID] {
        switch self {
        case let .create(event):
            event.paths.map { $0.id }
        case let .delete(event):
            event.pathIds
        case let .move(event):
            event.pathIds
        case let .update(event):
            [event.pathId]
        case let .merge(event):
            [event.pathId, event.mergedPathId]
        case let .nodeBreak(event):
            [event.pathId, event.newPathId]
        case let .edgeBreak(event):
            [event.pathId, event.newPathId]
        }
    }

    init(in pathId: UUID, _ kind: PathEvent.Update.Kind) {
        self = .update(.init(pathId: pathId, kinds: [kind]))
    }

    init(in pathId: UUID, _ kinds: [PathEvent.Update.Kind]) {
        self = .update(.init(pathId: pathId, kinds: kinds))
    }
}

extension DocumentEvent: CustomStringConvertible {
    var description: String {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8) ?? String(reflecting: self)
        } catch {
            return String(reflecting: self)
        }
    }
}
