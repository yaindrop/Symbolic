import Foundation
import SwiftUI

class PathModel: ObservableObject {
    @Published var pathIds: [UUID] = []
    @Published var nodeIds: [UUID] = []

    @Published var pathIdToPath: [UUID: Path] = [:]
    @Published var nodeIdToNode: [UUID: PathNode] = [:]

    var paths: [Path] { pathIds.compactMap { pid in pathIdToPath[pid] } }
    var nodes: [PathNode] { pathIds.compactMap { nid in nodeIdToNode[nid] } }
}

extension PathModel {
    func addPath(_ path: Path) {
        pathIds.append(path.id)
        pathIdToPath[path.id] = path
        for n in path.nodes {
            nodeIds.append(n.id)
            nodeIdToNode[n.id] = n
        }
    }

    func removePath(_ pathId: UUID) {
        guard let path = pathIdToPath[pathId] else { return }
        // TODO: remove nodes
        pathIds.removeAll { $0 == pathId }
        pathIdToPath.removeValue(forKey: pathId)
    }

    func updatePath(_ path: Path) {
        guard pathIdToPath[path.id] != nil else { return }
        pathIdToPath[path.id] = path
    }

    func clear() {
        pathIds.removeAll()
        nodeIds.removeAll()
        pathIdToPath.removeAll()
        nodeIdToNode.removeAll()
    }
}

extension PathModel {
    func loadDocument(_ document: Document) {
        for event in document.events {
            loadEvent(event)
        }
    }

    func loadEvent(_ event: DocumentEvent) {
        switch event.kind {
        case let .pathEvent(pathEvent):
            loadEvent(pathEvent)
        }
    }

    func loadEvent(_ event: PathEvent) {
        switch event {
        case let .create(create):
            loadEvent(create)
        case let .delete(delete):
            loadEvent(delete)
        case let .update(update):
            loadEvent(update)
        }
    }

    func loadEvent(_ event: PathCreate) {
        addPath(event.path)
    }

    func loadEvent(_ event: PathDelete) {
        removePath(event.pathId)
    }

    func loadEvent(_ event: PathUpdate) {
        switch event.kind {
        case let .edgeUpdate(edgeUpdate):
            loadPathUpdate(pathId: event.pathId, edgeUpdate: edgeUpdate)
        case let .nodeCreate(nodeCreate):
            loadPathUpdate(pathId: event.pathId, nodeCreate: nodeCreate)
        case let .nodeDelete(nodeDelete):
            loadPathUpdate(pathId: event.pathId, nodeDelete: nodeDelete)
        case let .nodeUpdate(nodeUpdate):
            loadPathUpdate(pathId: event.pathId, nodeUpdate: nodeUpdate)
        }
    }

    func loadPathUpdate(pathId: UUID, edgeUpdate: PathEdgeUpdate) {
        guard let path = pathIdToPath[pathId] else { return }
        updatePath(path.edgeUpdated(edgeUpdate: edgeUpdate))
    }

    func loadPathUpdate(pathId: UUID, nodeCreate: PathNodeCreate) {
        guard let path = pathIdToPath[pathId] else { return }
        updatePath(path.nodeCreated(nodeCreate: nodeCreate))
    }

    func loadPathUpdate(pathId: UUID, nodeDelete: PathNodeDelete) {
        guard let path = pathIdToPath[pathId] else { return }
        updatePath(path.nodeDeleted(nodeDelete: nodeDelete))
    }

    func loadPathUpdate(pathId: UUID, nodeUpdate: PathNodeUpdate) {
        guard let path = pathIdToPath[pathId] else { return }
        updatePath(path.nodeUpdated(nodeUpdate: nodeUpdate))
    }
}

extension PathModel {
    func hitTest(worldPosition: Point2) -> Path? {
        return paths.first { p in p.hitPath.contains(worldPosition) }
    }
}

class ActivePathModel: ObservableObject {
    @Published var activePathId: UUID?

    var activePath: Path? {
        pathModel.paths.first { $0.id == activePathId }
    }

    var inactivePaths: some View {
        ForEach(pathModel.paths.filter { $0.id != activePathId }) { p in
            SwiftUI.Path { path in p.draw(path: &path) }
                .stroke(Color(UIColor.label), lineWidth: 1)
        }
    }

    var activePaths: some View {
        ForEach(pathModel.paths.filter { $0.id == activePathId }) { p in
            SwiftUI.Path { path in p.draw(path: &path) }
                .stroke(Color(UIColor.label), lineWidth: 1)
            p.nodeViews()
            p.controlViews()
        }
    }

    init(pathModel: PathModel) {
        self.pathModel = pathModel
    }

    private var pathModel: PathModel
}

class PathUpdater: ObservableObject {
}
