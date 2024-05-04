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
    struct EdgeUpdate { let fromNodeId: UUID, edge: PathEdge }
    struct NodeCreate { let prevNodeId: UUID?, node: PathNode }
    struct NodeUpdate { let node: PathNode }
    struct NodeDelete { let nodeId: UUID }
    struct BreakUntil { let nodeId: UUID } // delete nodes (inclusively) till id
    struct BreakAfter { let nodeId: UUID } // delete nodes (exclusively) after id

    enum Kind {
        case edgeUpdate(EdgeUpdate)
        case nodeCreate(NodeCreate)
        case nodeDelete(NodeDelete)
        case nodeUpdate(NodeUpdate)
        case breakUntil(BreakUntil)
        case breakAfter(BreakAfter)
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
    init(in pathId: UUID, breakAfter nodeId: UUID) {
        self = .update(.init(pathId: pathId,
                             kind: .breakAfter(.init(nodeId: nodeId))))
    }

    init(in pathId: UUID, breakUntil nodeId: UUID) {
        self = .update(.init(pathId: pathId,
                             kind: .breakUntil(.init(nodeId: nodeId))))
    }

    init(in pathId: UUID, updateEdgeFrom fromNodeId: UUID, _ edge: PathEdge) {
        self = .update(.init(pathId: pathId,
                             kind: .edgeUpdate(.init(fromNodeId: fromNodeId, edge: edge))))
    }

    init(in pathId: UUID, createNodeAfter prevNodeId: UUID?, _ node: PathNode) {
        self = .update(.init(pathId: pathId,
                             kind: .nodeCreate(.init(prevNodeId: prevNodeId, node: node))))
    }

    init(in pathId: UUID, updateNode node: PathNode) {
        self = .update(.init(pathId: pathId,
                             kind: .nodeUpdate(.init(node: node))))
    }

    init(in pathId: UUID, deleteNode nodeId: UUID) {
        self = .update(.init(pathId: pathId,
                             kind: .nodeDelete(.init(nodeId: nodeId))))
    }
}
