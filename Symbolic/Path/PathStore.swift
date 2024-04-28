import Combine
import Foundation
import SwiftUI

// MARK: - PathStore

class PathStore: ObservableObject {
    @Published private(set) var pathIds: [UUID] = []
    @Published private(set) var pathIdToPath: [UUID: Path] = [:]

    @Published private(set) var nodeIds: [UUID] = []
    @Published private(set) var nodeIdToNode: [UUID: PathNode] = [:]

    @Published var pendingEvent: DocumentEvent?
    @Published private(set) var pendingPaths: [Path]? = nil

    var paths: [Path] { pathIds.compactMap { pid in pathIdToPath[pid] } }
    var nodes: [PathNode] { pathIds.compactMap { nid in nodeIdToNode[nid] } }

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

    init() {
        $pendingEvent.sink { _ in self.loadPendingEvent() }.store(in: &subscriptions)
    }

    // MARK: private

    private var loadingPendingEvent = false
    private var subscriptions = Set<AnyCancellable>()

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

    private func loadPendingEvent() {
        guard let pendingEvent else {
            pendingPaths = nil
            return
        }
        loadingPendingEvent = true
        defer { self.loadingPendingEvent = false }
        pendingPaths = paths
        loadEvent(pendingEvent)
    }

    private func getEventPath(id: UUID) -> Path? {
        if loadingPendingEvent {
            return pendingPaths?.first { $0.id == id }
        }
        return pathIdToPath[id]
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
        case let .compoundEvent(events):
            events.forEach {
                switch $0 {
                case let .pathEvent(pathEvent):
                    loadEvent(pathEvent)
                }
            }
        }
    }

    func loadEvent(_ event: PathEvent) {
        switch event {
        case let .create(create):
            loadPathEvent(create)
        case let .delete(delete):
            loadPathEvent(delete)
        case let .update(update):
            loadPathEvent(update)
        }
    }

    func loadPathEvent(_ event: PathCreate) {
        add(path: event.path)
    }

    func loadPathEvent(_ event: PathDelete) {
        remove(pathId: event.pathId)
    }

    func loadPathEvent(_ event: PathUpdate) {
        switch event.kind {
        case let .edgeUpdate(v):
            loadPathUpdate(pathId: event.pathId, edgeUpdate: v)
        case let .nodeCreate(v):
            loadPathUpdate(pathId: event.pathId, nodeCreate: v)
        case let .nodeDelete(v):
            loadPathUpdate(pathId: event.pathId, nodeDelete: v)
        case let .nodeUpdate(v):
            loadPathUpdate(pathId: event.pathId, nodeUpdate: v)
        }
    }

    func loadPathUpdate(pathId: UUID, edgeUpdate: PathEdgeUpdate) {
        guard let path = getEventPath(id: pathId) else { return }
        update(path: path.with(edgeUpdate: edgeUpdate))
    }

    func loadPathUpdate(pathId: UUID, nodeCreate: PathNodeCreate) {
        guard let path = getEventPath(id: pathId) else { return }
        update(path: path.with(nodeCreate: nodeCreate))
    }

    func loadPathUpdate(pathId: UUID, nodeDelete: PathNodeDelete) {
        guard let path = getEventPath(id: pathId) else { return }
        update(path: path.with(nodeDelete: nodeDelete))
    }

    func loadPathUpdate(pathId: UUID, nodeUpdate: PathNodeUpdate) {
        guard let path = getEventPath(id: pathId) else { return }
        update(path: path.with(nodeUpdate: nodeUpdate))
    }
}

extension PathStore {
    func hitTest(worldPosition: Point2) -> Path? {
        paths.first { p in p.hitPath.contains(worldPosition) }
    }
}
