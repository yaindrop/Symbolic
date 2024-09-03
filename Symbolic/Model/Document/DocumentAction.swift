import Foundation

// MARK: - PathAction

enum PathAction: Equatable {
    struct Create: Equatable { var symbolId: UUID, pathId: UUID, path: Path }
    struct Update: Equatable { var pathId: UUID, kind: Kind }

    struct Delete: Equatable { var pathIds: [UUID] }
    struct Move: Equatable { var pathIds: [UUID], offset: Vector2 }

    case create(Create)
    case update(Update)

    case delete(Delete)
    case move(Move)
}

// MARK: Update

extension PathAction.Update {
    struct AddEndingNode: Equatable { var endingNodeId: UUID, newNodeId: UUID, offset: Vector2 }
    struct SplitSegment: Equatable { var fromNodeId: UUID, paramT: Scalar, newNodeId: UUID, offset: Vector2 }
    struct DeleteNodes: Equatable { var nodeIds: [UUID] }

    struct UpdateNode: Equatable { var nodeId: UUID, node: PathNode }
    struct UpdateSegment: Equatable { var fromNodeId: UUID, segment: PathSegment }

    struct MoveNodes: Equatable { var nodeIds: [UUID], offset: Vector2 }
    struct MoveNodeControl: Equatable { var nodeId: UUID, controlType: PathNodeControlType, offset: Vector2 }

    struct Merge: Equatable { var endingNodeId: UUID, mergedPathId: UUID, mergedEndingNodeId: UUID }
    struct Split: Equatable { var nodeId: UUID, newPathId: UUID, newNodeId: UUID? }

    struct SetName: Equatable { var name: String? }
    struct SetNodeType: Equatable { var nodeIds: [UUID], nodeType: PathNodeType? }
    struct SetSegmentType: Equatable { var fromNodeIds: [UUID], segmentType: PathSegmentType? }

    enum Kind: Equatable {
        case addEndingNode(AddEndingNode)
        case splitSegment(SplitSegment)
        case deleteNodes(DeleteNodes)

        case updateNode(UpdateNode)
        case updateSegment(UpdateSegment)

        case moveNodes(MoveNodes)
        case moveNodeControl(MoveNodeControl)

        case merge(Merge)
        case split(Split)

        case setName(SetName)
        case setNodeType(SetNodeType)
        case setSegmentType(SetSegmentType)
    }
}

enum SymbolAction: Equatable {
    struct Create: Equatable { let symbolId: UUID, origin: Point2, size: CGSize }
    struct Resize: Equatable { let symbolId: UUID, align: PlaneInnerAlign, offset: Vector2 }
    struct SetGrid: Equatable { let symbolId: UUID, index: Int, grid: Grid? }

    struct Delete: Equatable { let symbolIds: [UUID] }
    struct Move: Equatable { let symbolIds: [UUID], offset: Vector2 }

    case create(Create)
    case resize(Resize)
    case setGrid(SetGrid)

    case delete(Delete)
    case move(Move)
}

// MARK: - ItemAction

enum ItemAction: Equatable {
    struct Group: Equatable { var groupId: UUID, members: [UUID], inSymbolId: UUID?, inGroupId: UUID? }
    struct Ungroup: Equatable { var groupIds: [UUID] }
    struct Reorder: Equatable { var itemId: UUID, toItemId: UUID, isAfter: Bool }

    case group(Group)
    case ungroup(Ungroup)
    case reorder(Reorder)
}

// MARK: - DocumentAction

enum DocumentAction: Equatable {
    case path(PathAction)
    case symbol(SymbolAction)
    case item(ItemAction)
}
