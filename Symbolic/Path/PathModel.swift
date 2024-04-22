import Foundation
import SwiftUI

class PathModel: ObservableObject {
    @Published var pathIds: [UUID] = []
    @Published var vertexIds: [UUID] = []

    var pathIdToPath: [UUID: Path] = [:]
    var vertexIdToVertex: [UUID: PathVertex] = [:]

    var paths: [Path] { pathIds.compactMap { pid in pathIdToPath[pid] } }
    var vertices: [PathVertex] { pathIds.compactMap { vid in vertexIdToVertex[vid] } }
}

extension PathModel {
    func addPath(_ path: Path) {
        pathIds.append(path.id)
        pathIdToPath[path.id] = path
        for v in path.vertices {
            vertexIds.append(v.id)
            vertexIdToVertex[v.id] = v
        }
    }

    func removePath(_ pathId: UUID) {
        guard let path = pathIdToPath[pathId] else { return }
        // TODO: remove vertices
        pathIds.removeAll { $0 == pathId }
        pathIdToPath.removeValue(forKey: pathId)
    }

    func updatePath(_ path: Path) {
        guard pathIdToPath[path.id] != nil else { return }
        pathIdToPath[path.id] = path
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
        case let .actionUpdate(actionUpdate):
            loadPathUpdate(pathId: event.pathId, actionUpdate: actionUpdate)
        case let .vertexCreate(vertexCreate):
            loadPathUpdate(pathId: event.pathId, vertexCreate: vertexCreate)
        case let .vertexDelete(vertexDelete):
            loadPathUpdate(pathId: event.pathId, vertexDelete: vertexDelete)
        case let .vertexUpdate(vertexUpdate):
            loadPathUpdate(pathId: event.pathId, vertexUpdate: vertexUpdate)
        }
    }

    func loadPathUpdate(pathId: UUID, actionUpdate: PathActionUpdate) {
        guard let path = pathIdToPath[pathId] else { return }
        updatePath(path.actionUpdated(actionUpdate: actionUpdate))
    }

    func loadPathUpdate(pathId: UUID, vertexCreate: PathVertexCreate) {
        guard let path = pathIdToPath[pathId] else { return }
        updatePath(path.vertexCreated(vertexCreate: vertexCreate))
    }

    func loadPathUpdate(pathId: UUID, vertexDelete: PathVertexDelete) {
        guard let path = pathIdToPath[pathId] else { return }
        updatePath(path.vertexDeleted(vertexDelete: vertexDelete))
    }

    func loadPathUpdate(pathId: UUID, vertexUpdate: PathVertexUpdate) {
        guard let path = pathIdToPath[pathId] else { return }
        updatePath(path.vertexUpdated(vertexUpdate: vertexUpdate))
    }
}

extension PathModel {
    func hitTest(worldPosition: Point2) -> Path? {
        return paths.first { p in p.hitPath.contains(worldPosition) }
    }
}

class ActivePathModel: ObservableObject {
    @Published var activePathId: UUID?

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
            p.vertexViews()
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
