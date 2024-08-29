import Foundation

// MARK: - PathEvent

struct PathEvent: Equatable, Codable {
    let pathIds: [UUID], kinds: [Kind]

    struct Create: Equatable, Codable { let path: Path }
    struct CreateNode: Equatable, Codable { let prevNodeId: UUID?, nodeId: UUID, node: PathNode }
    struct UpdateNode: Equatable, Codable { let nodeId: UUID, node: PathNode }
    struct DeleteNode: Equatable, Codable { let nodeIds: [UUID] }
    // merge two paths at given ending nodes
    struct Merge: Equatable, Codable { let endingNodeId: UUID, mergedPathId: UUID, mergedEndingNodeId: UUID }
    // split path at node, optionally creating a new ending node at the same position, and a new path when the current path is not closed
    struct Split: Equatable, Codable { let nodeId: UUID, newPathId: UUID?, newNodeId: UUID? }

    struct Delete: Equatable, Codable {}
    struct Move: Equatable, Codable { let offset: Vector2 }

    struct SetName: Equatable, Codable { let name: String? }
    struct SetNodeType: Equatable, Codable { let nodeIds: [UUID], nodeType: PathNodeType? }
    struct SetSegmentType: Equatable, Codable { let fromNodeIds: [UUID], segmentType: PathSegmentType? }

    enum Kind: Equatable, Codable {
        case create(Create)
        case createNode(CreateNode)
        case updateNode(UpdateNode)
        case deleteNode(DeleteNode)
        case merge(Merge)
        case split(Split)

        case delete(Delete)
        case move(Move)

        case setName(SetName)
        case setNodeType(SetNodeType)
        case setSegmentType(SetSegmentType)
    }
}

extension PathEvent {
    init(pathId: UUID, _ kind: PathEvent.Kind) {
        self = .init(pathIds: [pathId], kinds: [kind])
    }

    init(pathId: UUID, _ kinds: [PathEvent.Kind]) {
        self = .init(pathIds: [pathId], kinds: kinds)
    }

    init(pathIds: [UUID], _ kind: PathEvent.Kind) {
        self = .init(pathIds: pathIds, kinds: [kind])
    }
}

// MARK: - SymbolEvent

struct SymbolEvent: Equatable, Codable {
    let symbolIds: [UUID], kinds: [Kind]

    struct Create: Equatable, Codable { let origin: Point2, size: CGSize, grids: [Grid] }
    struct SetBounds: Equatable, Codable { let origin: Point2, size: CGSize }
    struct SetGrid: Equatable, Codable { let index: Int, grid: Grid? }
    struct SetMembers: Equatable, Codable { let members: [UUID] }

    struct Delete: Equatable, Codable {}
    struct Move: Equatable, Codable { let offset: Vector2 }

    enum Kind: Equatable, Codable {
        case create(Create)
        case setBounds(SetBounds)
        case setGrid(SetGrid)
        case setMembers(SetMembers)

        case delete(Delete)
        case move(Move)
    }
}

extension SymbolEvent {
    init(symbolId: UUID, _ kind: SymbolEvent.Kind) {
        self = .init(symbolIds: [symbolId], kinds: [kind])
    }

    init(symbolIds: [UUID], _ kind: SymbolEvent.Kind) {
        self = .init(symbolIds: symbolIds, kinds: [kind])
    }
}

// MARK: - ItemEvent

enum ItemEvent: Equatable, Codable {
    struct SetGroup: Equatable, Codable { let groupId: UUID, members: [UUID] }

    case setGroup(SetGroup)
}

// MARK: - DocumentEvent

struct DocumentEvent: Identifiable, Equatable, Codable {
    let id: UUID
    let time: Date
    let kind: Kind
    let action: DocumentAction?

    enum Single: Equatable, Codable {
        case path(PathEvent)
        case symbol(SymbolEvent)
        case item(ItemEvent)
    }

    struct Compound: Equatable, Codable {
        let events: [Single]
    }

    enum Kind: Equatable, Codable {
        case single(Single)
        case compound(Compound)
    }

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
