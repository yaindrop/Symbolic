import Combine
import Foundation
import SwiftUI

fileprivate let subtracer = tracer.tagged("PathService")

typealias PathMap = [UUID: Path]

// MARK: - PathModel

class PathStore: Store {
    @Trackable var pathMap = PathMap()

    var subscriptions = Set<AnyCancellable>()

    var paths: [Path] { Array(pathMap.values) }

    fileprivate func update(pathMap: PathMap) {
        update { $0(\._pathMap, pathMap) }
    }
}

// MARK: - PendingPathModel

class PendingPathStore: Store {
    @Trackable var pendingEvent: DocumentEvent?
    @Trackable var pathMap = PathMap()

    var hasPendingEvent: Bool { pendingEvent != nil }

    var paths: [Path] { Array(pathMap.values) }

    fileprivate var loadingPendingEvent = false

    fileprivate func update(pendingEvent: DocumentEvent?) {
        update { $0(\._pendingEvent, pendingEvent) }
    }

    fileprivate func update(pathMap: PathMap) {
        update { $0(\._pathMap, pathMap) }
    }
}

// MARK: - PathService

struct PathService {
    let store: PathStore
    let pendingStore: PendingPathStore

    var pendingPaths: [Path] { pendingStore.hasPendingEvent ? pendingStore.paths : store.paths }

    func hitTest(worldPosition: Point2) -> Path? {
        store.paths.first { p in p.hitPath.contains(worldPosition) }
    }

    func loadDocument(_ document: Document) {
        let _r = subtracer.range("load document \(pendingStore.hasPendingEvent)", type: .intent); defer { _r() }
        withStoreUpdating {
            clear()
            for event in document.events {
                loadEvent(event)
            }
        }
    }

    func loadPendingEvent(_ event: DocumentEvent?) {
        let _r = subtracer.range("load pending event"); defer { _r() }
        guard let event else {
            pendingStore.update(pendingEvent: event)
            return
        }

        pendingStore.loadingPendingEvent = true
        defer { pendingStore.loadingPendingEvent = false }

        withStoreUpdating {
            pendingStore.update(pendingEvent: event)
            pendingStore.update(pathMap: store.pathMap.cloned)
            loadEvent(event)
        }
    }
}

// MARK: - modify path map

extension PathService {
    private var targetPathMap: PathMap {
        get { pendingStore.loadingPendingEvent ? pendingStore.pathMap : store.pathMap }
        nonmutating set {
            if pendingStore.loadingPendingEvent { pendingStore.update(pathMap: newValue) } else { store.update(pathMap: newValue) }
        }
    }

    private func add(path: Path) {
        let _r = subtracer.range("add"); defer { _r() }
        guard path.count > 1 else { return }
        guard targetPathMap[path.id] == nil else { return }
        targetPathMap[path.id] = path.cloned
    }

    private func remove(pathId: UUID) {
        let _r = subtracer.range("remove"); defer { _r() }
        guard targetPathMap[pathId] != nil else { return }
        targetPathMap.removeValue(forKey: pathId)
    }

    private func update(path: Path) {
        let _r = subtracer.range("update"); defer { _r() }
        guard path.count > 1 else {
            remove(pathId: path.id)
            return
        }
        guard targetPathMap[path.id] != nil else { return }
        targetPathMap[path.id] = path.cloned
    }

    private func clear() {
        let _r = subtracer.range("clear"); defer { _r() }
        targetPathMap.removeAll()
    }
}

// MARK: - event loaders

extension PathService {
    private func loadEvent(_ event: DocumentEvent) {
        let _r = subtracer.range("load document event \(event.id)", type: .intent); defer { _r() }
        switch event.kind {
        case let .pathEvent(event):
            loadEvent(event)
        case let .compoundEvent(event):
            loadEvent(event)
        }
    }

    private func loadEvent(_ event: PathEvent) {
        let _r = subtracer.range("load event"); defer { _r() }
        switch event {
        case let .create(event):
            loadEvent(event)
        case let .delete(event):
            loadEvent(event)
        case let .update(event):
            loadEvent(event)
        }
    }

    private func loadEvent(_ event: CompoundEvent) {
        event.events.forEach {
            switch $0 {
            case let .pathEvent(pathEvent):
                loadEvent(pathEvent)
            }
        }
    }

    private func loadEvent(_ event: PathEvent.Create) {
        add(path: event.path)
    }

    private func loadEvent(_ event: PathEvent.Delete) {
        remove(pathId: event.pathId)
    }

    // MARK: path update event loaders

    private func loadEvent(_ event: PathEvent.Update) {
        let pathId = event.pathId
        switch event.kind {
        case let .move(event):
            loadEvent(pathId: pathId, event)
        case let .merge(event):
            loadEvent(pathId: pathId, event)
        case let .nodeCreate(event):
            loadEvent(pathId: pathId, event)
        case let .nodeDelete(event):
            loadEvent(pathId: pathId, event)
        case let .nodeUpdate(event):
            loadEvent(pathId: pathId, event)
        case let .nodeBreak(event):
            loadEvent(pathId: pathId, event)
        case let .edgeUpdate(event):
            loadEvent(pathId: pathId, event)
        case let .edgeBreak(event):
            loadEvent(pathId: pathId, event)
        }
    }

    private func loadEvent(pathId: UUID, _ event: PathEvent.Update.Move) {
        guard let path = targetPathMap[pathId] else { return }
        path.update(move: event)
        update(path: path)
    }

    private func loadEvent(pathId: UUID, _ event: PathEvent.Update.Merge) {
        let mergedPathId = event.mergedPathId
        guard let path = targetPathMap[pathId],
              let mergedPath = targetPathMap[mergedPathId] else { return }
        if mergedPath != path {
            remove(pathId: mergedPathId)
        }
        path.update(merge: event, mergedPath: mergedPath)
        update(path: path)
    }

    private func loadEvent(pathId: UUID, _ event: PathEvent.Update.NodeCreate) {
        guard let path = targetPathMap[pathId] else { return }
        path.update(nodeCreate: event)
        update(path: path)
    }

    private func loadEvent(pathId: UUID, _ event: PathEvent.Update.NodeDelete) {
        guard let path = targetPathMap[pathId] else { return }
        path.update(nodeDelete: event)
        update(path: path)
    }

    private func loadEvent(pathId: UUID, _ event: PathEvent.Update.NodeUpdate) {
        guard let path = targetPathMap[pathId] else { return }
        path.update(nodeUpdate: event)
        update(path: path)
    }

    private func loadEvent(pathId: UUID, _ event: PathEvent.Update.NodeBreak) {
        guard let path = targetPathMap[pathId] else { return }
        let newPath = path.update(nodeBreak: event)
        update(path: path)
        if let newPath {
            add(path: newPath)
        }
    }

    private func loadEvent(pathId: UUID, _ event: PathEvent.Update.EdgeUpdate) {
        guard let path = targetPathMap[pathId] else { return }
        path.update(edgeUpdate: event)
        update(path: path)
    }

    private func loadEvent(pathId: UUID, _ event: PathEvent.Update.EdgeBreak) {
        guard let path = targetPathMap[pathId] else { return }
        let newPath = path.update(edgeBreak: event)
        update(path: path)
        if let newPath {
            add(path: newPath)
        }
    }
}
