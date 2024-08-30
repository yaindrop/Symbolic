import Foundation

// MARK: - PathEvent

struct PathEvent: Equatable {
    let pathIds: [UUID], kinds: [Kind]

    struct Create: Equatable { let path: Path }
    struct CreateNode: Equatable { let prevNodeId: UUID?, nodeId: UUID, node: PathNode }
    struct UpdateNode: Equatable { let nodeId: UUID, node: PathNode }
    struct DeleteNode: Equatable { let nodeIds: [UUID] }
    // merge two paths at given ending nodes
    struct Merge: Equatable { let endingNodeId: UUID, mergedPathId: UUID, mergedEndingNodeId: UUID }
    // split path at node, optionally creating a new ending node at the same position, and a new path when the current path is not closed
    struct Split: Equatable { let nodeId: UUID, newPathId: UUID?, newNodeId: UUID? }

    struct Delete: Equatable {}
    struct Move: Equatable { let offset: Vector2 }

    struct SetName: Equatable { let name: String? }
    struct SetNodeType: Equatable { let nodeIds: [UUID], nodeType: PathNodeType? }
    struct SetSegmentType: Equatable { let fromNodeIds: [UUID], segmentType: PathSegmentType? }

    enum Kind: Equatable {
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

struct SymbolEvent: Equatable {
    let symbolIds: [UUID], kinds: [Kind]

    struct Create: Equatable { let origin: Point2, size: CGSize, grids: [Grid] }
    struct SetBounds: Equatable { let origin: Point2, size: CGSize }
    struct SetGrid: Equatable { let index: Int, grid: Grid? }
    struct SetMembers: Equatable { let members: [UUID] }

    struct Delete: Equatable {}
    struct Move: Equatable { let offset: Vector2 }

    enum Kind: Equatable {
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

enum ItemEvent: Equatable {
    struct SetGroup: Equatable { let groupId: UUID, members: [UUID] }

    case setGroup(SetGroup)
}

// MARK: - DocumentEvent

struct DocumentEvent: Identifiable, Equatable {
    let id: UUID
    let time: Date
    let action: DocumentAction?
    let kind: Kind

    enum Single: Equatable {
        case path(PathEvent)
        case symbol(SymbolEvent)
        case item(ItemEvent)
    }

    struct Compound: Equatable {
        let events: [Single]
    }

    enum Kind: Equatable {
        case single(Single)
        case compound(Compound)
    }

    init(id: UUID, time: Date, action: DocumentAction?, kind: Kind) {
        self.id = id
        self.time = time
        self.action = action
        self.kind = kind
    }

    init(kind: Kind, action: DocumentAction?) {
        id = .init()
        time = .init()
        self.kind = kind
        self.action = action
    }
}

extension DocumentEvent: CustomStringConvertible {
    var description: String {
        (try? pb.jsonString()) ?? String(reflecting: self)
    }
}
