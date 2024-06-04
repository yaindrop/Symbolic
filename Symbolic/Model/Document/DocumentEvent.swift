import Foundation

// MARK: - ItemEvent

enum ItemEvent: Equatable, Encodable {
    struct SetMembers: Equatable, Encodable { let members: [UUID], inGroupId: UUID? }

    case setMembers(SetMembers)
}

// MARK: - PathEvent

enum PathEvent: Equatable, Encodable {
    struct Create: Equatable, Encodable { let path: Path }
    struct Delete: Equatable, Encodable { let pathId: UUID }

    case create(Create)
    case update(Update)
    case delete(Delete)
    case compound(Compound)
}

// MARK: Update

extension PathEvent {
    struct Update: Equatable, Encodable {
        let pathId: UUID, kind: Kind

        struct Move: Equatable, Encodable { let offset: Vector2 }

        struct NodeCreate: Equatable, Encodable { let prevNodeId: UUID?, node: PathNode }
        struct NodeUpdate: Equatable, Encodable { let node: PathNode }
        struct NodeDelete: Equatable, Encodable { let nodeId: UUID }

        struct EdgeUpdate: Equatable, Encodable { let fromNodeId: UUID, edge: PathEdge }

        enum Kind: Equatable, Encodable {
            case move(Move)
            case nodeCreate(NodeCreate)
            case nodeDelete(NodeDelete)
            case nodeUpdate(NodeUpdate)
            case edgeUpdate(EdgeUpdate)
        }
    }
}

// MARK: Compound

extension PathEvent {
    enum Compound: Equatable, Encodable {
        struct Merge: Equatable, Encodable { let pathId: UUID, endingNodeId: UUID, mergedPathId: UUID, mergedEndingNodeId: UUID }

        struct NodeBreak: Equatable, Encodable { let pathId: UUID, nodeId: UUID, newNodeId: UUID, newPathId: UUID } // break path at node, creating a new ending node at the same position, and a new path when the current path is not closed
        struct EdgeBreak: Equatable, Encodable { let pathId: UUID, fromNodeId: UUID, newPathId: UUID } // break path at edge, creating a new path when the current path is not closed

        case merge(Merge)
        case nodeBreak(NodeBreak)
        case edgeBreak(EdgeBreak)
    }
}

// MARK: - PathPropertyEvent

struct PathPropertyEvent: Equatable, Encodable {
    enum Kind: Equatable, Encodable {
        struct SetName: Equatable, Encodable { let name: String? }
        struct SetNodeType: Equatable, Encodable { let nodeId: UUID, nodeType: PathNodeType? }
        struct SetEdgeType: Equatable, Encodable { let fromNodeId: UUID, edgeType: PathEdgeType? }

        case setName(SetName)
        case setNodeType(SetNodeType)
        case setEdgeType(SetEdgeType)
    }

    let pathId: UUID
    let kind: Kind
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
    init(in pathId: UUID, _ kind: PathEvent.Update.Kind) {
        self = .update(.init(pathId: pathId, kind: kind))
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
