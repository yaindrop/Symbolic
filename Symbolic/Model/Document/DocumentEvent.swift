import Foundation

// MARK: - ItemEvent

enum ItemEvent: Equatable, Codable {
    struct SetMembers: Equatable, Codable { let members: [UUID], inGroupId: UUID? }

    case setMembers(SetMembers)
}

// MARK: - PathEvent

enum PathEvent: Equatable, Codable {
    struct Create: Equatable, Codable { let pathId: UUID, path: Path }
    struct Delete: Equatable, Codable { let pathId: UUID }
    struct Update: Equatable, Codable { let pathId: UUID, kinds: [Kind] }

    // multi update
    struct Merge: Equatable, Codable { let pathId: UUID, endingNodeId: UUID, mergedPathId: UUID, mergedEndingNodeId: UUID }
    struct NodeBreak: Equatable, Codable { let pathId: UUID, nodeId: UUID, newPathId: UUID, newNodeId: UUID } // break path at node, creating a new ending node at the same position, and a new path when the current path is not closed
    struct SegmentBreak: Equatable, Codable { let pathId: UUID, fromNodeId: UUID, newPathId: UUID } // break path at segment, creating a new path when the current path is not closed

    case create(Create)
    case delete(Delete)
    case update(Update)

    case merge(Merge)
    case nodeBreak(NodeBreak)
    case segmentBreak(SegmentBreak)
}

// MARK: Update

extension PathEvent.Update {
    struct Move: Equatable, Codable { let offset: Vector2 }

    struct NodeCreate: Equatable, Codable { let prevNodeId: UUID?, nodeId: UUID, node: PathNode }
    struct NodeDelete: Equatable, Codable { let nodeId: UUID }
    struct NodeUpdate: Equatable, Codable { let nodeId: UUID, node: PathNode }

    enum Kind: Equatable, Codable {
        case move(Move)

        case nodeCreate(NodeCreate)
        case nodeDelete(NodeDelete)
        case nodeUpdate(NodeUpdate)
    }
}

// MARK: - PathPropertyEvent

enum PathPropertyEvent: Equatable, Codable {
    struct Update: Equatable, Codable { let pathId: UUID, kinds: [Kind] }

    case update(Update)
}

extension PathPropertyEvent.Update {
    struct SetName: Equatable, Codable { let name: String? }
    struct SetNodeType: Equatable, Codable { let nodeIds: [UUID], nodeType: PathNodeType? }
    struct SetSegmentType: Equatable, Codable { let fromNodeIds: [UUID], segmentType: PathSegmentType? }

    enum Kind: Equatable, Codable {
        case setName(SetName)
        case setNodeType(SetNodeType)
        case setSegmentType(SetSegmentType)
    }
}

// MARK: - SingleEvent

enum SingleEvent: Equatable, Codable {
    case item(ItemEvent)
    case path(PathEvent)
    case pathProperty(PathPropertyEvent)
}

// MARK: - CompoundEvent

struct CompoundEvent: Equatable, Codable {
    let events: [SingleEvent]
}

// MARK: - DocumentEvent

struct DocumentEvent: Identifiable, Equatable, Codable {
    enum Kind: Equatable, Codable {
        case single(SingleEvent)
        case compound(CompoundEvent)
    }

    let id: UUID
    let time: Date
    let kind: Kind
    let action: DocumentAction

    init(kind: Kind, action: DocumentAction) {
        id = .init()
        time = .init()
        self.kind = kind
        self.action = action
    }
}

extension PathEvent {
    var affectedPathIds: [UUID] {
        switch self {
        case let .create(event):
            [event.pathId]
        case let .delete(event):
            [event.pathId]
        case let .update(event):
            [event.pathId]
        case let .merge(event):
            [event.pathId, event.mergedPathId]
        case let .nodeBreak(event):
            [event.pathId, event.newPathId]
        case let .segmentBreak(event):
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
