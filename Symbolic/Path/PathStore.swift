import Combine
import Foundation
import SwiftUI

// MARK: - PathStore

class PathStore: ObservableObject {
    @Published private(set) var pathIds: [UUID] = []
    @Published private(set) var pathIdToPath: [UUID: Path] = [:]

    @Published private(set) var nodeIds: [UUID] = []
    @Published private(set) var nodeIdToNode: [UUID: PathNode] = [:]

    private var loadingPendingEvent = false
    @Published var pendingEvent: DocumentEvent?
    @Published private(set) var pendingPaths: [Path]? = nil
    private var subscriptions = Set<AnyCancellable>()

    var paths: [Path] { pathIds.compactMap { pid in pathIdToPath[pid] } }
    var nodes: [PathNode] { pathIds.compactMap { nid in nodeIdToNode[nid] } }

    init() {
        $pendingEvent.sink { e in
            self.loadingPendingEvent = true
            defer { self.loadingPendingEvent = false }
            if let e {
                self.pendingPaths = self.paths
                self.loadEvent(e)
            }
        }.store(in: &subscriptions)
    }

    func add(path: Path) {
        if loadingPendingEvent {
            pendingPaths?.append(path)
            return
        }
        guard pathIdToPath[path.id] == nil else { return }
        pathIds.append(path.id)
        pathIdToPath[path.id] = path
        refreshNodes()
    }

    func remove(pathId: UUID) {
        if loadingPendingEvent {
            pendingPaths?.removeAll { $0.id == pathId }
            return
        }
        guard pathIdToPath[pathId] != nil else { return }
        pathIds.removeAll { $0 == pathId }
        pathIdToPath.removeValue(forKey: pathId)
        refreshNodes()
    }

    func update(path: Path) {
        if loadingPendingEvent {
            guard let i = (pendingPaths?.firstIndex { $0.id == path.id }) else { return }
            pendingPaths?[i] = path
            return
        }
        guard pathIdToPath[path.id] != nil else { return }
        pathIdToPath[path.id] = path
        refreshNodes()
    }

    func clear() {
        pathIds.removeAll()
        pathIdToPath.removeAll()
        refreshNodes()
    }

    private func refreshNodes() {
        nodeIds.removeAll()
        nodeIdToNode.removeAll()
        for (_, path) in pathIdToPath {
            for n in path.nodes {
                nodeIds.append(n.id)
                nodeIdToNode[n.id] = n
            }
        }
    }
}

// MARK: - PathStore load events

extension PathStore {
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
        add(path: event.path)
    }

    func loadEvent(_ event: PathDelete) {
        remove(pathId: event.pathId)
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
        update(path: path.edgeUpdated(edgeUpdate: edgeUpdate))
    }

    func loadPathUpdate(pathId: UUID, nodeCreate: PathNodeCreate) {
        guard let path = pathIdToPath[pathId] else { return }
        update(path: path.nodeCreated(nodeCreate: nodeCreate))
    }

    func loadPathUpdate(pathId: UUID, nodeDelete: PathNodeDelete) {
        guard let path = pathIdToPath[pathId] else { return }
        update(path: path.nodeDeleted(nodeDelete: nodeDelete))
    }

    func loadPathUpdate(pathId: UUID, nodeUpdate: PathNodeUpdate) {
        guard let path = pathIdToPath[pathId] else { return }
        update(path: path.nodeUpdated(nodeUpdate: nodeUpdate))
    }
}

extension PathStore {
    func hitTest(worldPosition: Point2) -> Path? {
        return paths.first { p in p.hitPath.contains(worldPosition) }
    }
}
