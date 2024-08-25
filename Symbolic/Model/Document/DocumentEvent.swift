import Foundation

// MARK: - PathEvent

enum PathEvent: Equatable, Codable {
    struct Create: Equatable, Codable { let symbolId: UUID, pathId: UUID, path: Path }
    struct Delete: Equatable, Codable { let pathId: UUID }
    struct Update: Equatable, Codable { let pathId: UUID, kinds: [Kind] }

    // merge two paths at given ending nodes
    struct Merge: Equatable, Codable { let pathId: UUID, endingNodeId: UUID, mergedPathId: UUID, mergedEndingNodeId: UUID }
    // split path at node, optionally creating a new ending node at the same position, and a new path when the current path is not closed
    struct Split: Equatable, Codable { let pathId: UUID, nodeId: UUID, newPathId: UUID?, newNodeId: UUID? }

    case create(Create)
    case delete(Delete)
    case update(Update)

    case merge(Merge)
    case split(Split)
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

// MARK: - ItemEvent

enum ItemEvent: Equatable, Codable {
    struct SetRoot: Equatable, Codable { let symbolId: UUID, members: [UUID] }
    struct SetGroup: Equatable, Codable { let groupId: UUID, members: [UUID] }

    case setRoot(SetRoot)
    case setGroup(SetGroup)
}

// MARK: - SymbolEvent

enum SymbolEvent: Equatable, Codable {
    struct Create: Equatable, Codable { let symbolId: UUID, origin: Point2, size: CGSize }
    struct Delete: Equatable, Codable { let symbolId: UUID }
    struct Resize: Equatable, Codable { let symbolId: UUID, origin: Point2, size: CGSize }

    case create(Create)
    case delete(Delete)
    case resize(Resize)
}

// MARK: - DocumentEvent

struct DocumentEvent: Identifiable, Equatable, Codable {
    enum Single: Equatable, Codable {
        case path(PathEvent)
        case pathProperty(PathPropertyEvent)
        case item(ItemEvent)
        case symbol(SymbolEvent)
    }

    struct Compound: Equatable, Codable {
        let events: [Single]
    }

    enum Kind: Equatable, Codable {
        case single(Single)
        case compound(Compound)
    }

    let id: UUID
    let time: Date
    let kind: Kind
    let action: DocumentAction?

    init(kind: Kind, action: DocumentAction?) {
        id = .init()
        time = .init()
        self.kind = kind
        self.action = action
    }

    init(id: UUID, time: Date, kind: Kind) {
        self.id = id
        self.time = time
        self.kind = kind
        action = nil
    }
}

extension PathEvent {
    var affectedSymbolId: UUID? {
        switch self {
        case let .create(event):
            event.symbolId
        default: nil
        }
    }

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
        case let .split(event):
            [event.pathId, event.newPathId].compact()
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
