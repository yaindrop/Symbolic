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

    enum Kind {
        case edgeUpdate(EdgeUpdate)
        case nodeCreate(NodeCreate)
        case nodeDelete(NodeDelete)
        case nodeUpdate(NodeUpdate)
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
    init(in pathId: UUID, updateEdgeFrom fromNodeId: UUID, _ edge: PathEdge) {
        let edgeUpdate = PathEvent.Update.EdgeUpdate(fromNodeId: fromNodeId, edge: edge)
        let update = PathEvent.Update(pathId: pathId, kind: .edgeUpdate(edgeUpdate))
        self = .update(update)
    }

    init(in pathId: UUID, createNodeAfter prevNodeId: UUID?, _ node: PathNode) {
        let nodeCreate = PathEvent.Update.NodeCreate(prevNodeId: prevNodeId, node: node)
        let update = PathEvent.Update(pathId: pathId, kind: .nodeCreate(nodeCreate))
        self = .update(update)
    }

    init(in pathId: UUID, updateNode node: PathNode) {
        let nodeUpdate = PathEvent.Update.NodeUpdate(node: node)
        let update = PathEvent.Update(pathId: pathId, kind: .nodeUpdate(nodeUpdate))
        self = .update(update)
    }

    init(in pathId: UUID, deleteNode nodeId: UUID) {
        let nodeDelete = PathEvent.Update.NodeDelete(nodeId: nodeId)
        let update = PathEvent.Update(pathId: pathId, kind: .nodeDelete(nodeDelete))
        self = .update(update)
    }
}
