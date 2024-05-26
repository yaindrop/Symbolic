import Foundation

fileprivate let subtracer = tracer.tagged("PathService")

typealias PathMap = [UUID: Path]

fileprivate protocol PathStoreProtocol {
    var map: PathMap { get }

    var paths: [Path] { get }

    func path(id: UUID) -> Path?
}

// MARK: - PathStore

class PathStore: Store, PathStoreProtocol {
    @Trackable var map = PathMap()

    var paths: [Path] { Array(map.values) }

    func path(id: UUID) -> Path? { map.value(key: id) }

    fileprivate func update(map: PathMap) {
        update { $0(\._map, map) }
    }
}

// MARK: - PendingPathStore

class PendingPathStore: Store, PathStoreProtocol {
    @Trackable var map = PathMap()
    @Trackable fileprivate var active: Bool = false

    var paths: [Path] { Array(map.values) }

    func path(id: UUID) -> Path? { map.value(key: id) }

    fileprivate func update(map: PathMap) {
        update { $0(\._map, map) }
    }

    fileprivate func update(active: Bool) {
        update { $0(\._active, active) }
    }
}

// MARK: - PathService

struct PathService: PathStoreProtocol {
    let store: PathStore
    let pendingStore: PendingPathStore

    var map: PathMap { pendingStore.active ? pendingStore.map : store.map }

    var paths: [Path] { pendingStore.active ? pendingStore.paths : store.paths }

    func path(id: UUID) -> Path? { pendingStore.active ? pendingStore.path(id: id) : store.path(id: id) }

    func hitTest(worldPosition: Point2) -> Path? {
        store.paths.first { p in p.hitPath.contains(worldPosition) }
    }

    func loadDocument(_ document: Document) {
        let _r = subtracer.range("load document \(pendingStore.active)", type: .intent); defer { _r() }
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
            pendingStore.update(active: false)
            return
        }

        withStoreUpdating {
            pendingStore.update(active: true)
            pendingStore.update(map: store.map.cloned)
            loadEvent(event)
        }
    }

    private func update(map: PathMap) {
        if pendingStore.active {
            pendingStore.update(map: map)
        } else {
            store.update(map: map)
        }
    }
}

// MARK: - modify path map

extension PathService {
    private func add(path: Path) {
        let _r = subtracer.range("add"); defer { _r() }
        guard path.count > 1 else { return }
        guard self.path(id: path.id) == nil else { return }
        update(map: map.with { $0[path.id] = path.cloned })
    }

    private func remove(pathId: UUID) {
        let _r = subtracer.range("remove"); defer { _r() }
        guard path(id: pathId) != nil else { return }
        update(map: map.with { $0.removeValue(forKey: pathId) })
    }

    private func update(path: Path) {
        let _r = subtracer.range("update"); defer { _r() }
        guard path.count > 1 else {
            remove(pathId: path.id)
            return
        }
        guard self.path(id: path.id) != nil else { return }
        update(map: map.with { $0[path.id] = path.cloned })
    }

    private func clear() {
        let _r = subtracer.range("clear"); defer { _r() }
        update(map: .init())
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

    private func loadEvent(_ event: CompoundEvent) {
        event.events.forEach {
            switch $0 {
            case let .pathEvent(pathEvent):
                loadEvent(pathEvent)
            }
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
        guard let path = path(id: pathId) else { return }
        path.update(move: event)
        update(path: path)
    }

    private func loadEvent(pathId: UUID, _ event: PathEvent.Update.Merge) {
        let mergedPathId = event.mergedPathId
        guard let path = path(id: pathId),
              let mergedPath = self.path(id: mergedPathId) else { return }
        if mergedPath != path {
            remove(pathId: mergedPathId)
        }
        path.update(merge: event, mergedPath: mergedPath)
        update(path: path)
    }

    private func loadEvent(pathId: UUID, _ event: PathEvent.Update.NodeCreate) {
        guard let path = path(id: pathId) else { return }
        path.update(nodeCreate: event)
        update(path: path)
    }

    private func loadEvent(pathId: UUID, _ event: PathEvent.Update.NodeDelete) {
        guard let path = path(id: pathId) else { return }
        path.update(nodeDelete: event)
        update(path: path)
    }

    private func loadEvent(pathId: UUID, _ event: PathEvent.Update.NodeUpdate) {
        guard let path = path(id: pathId) else { return }
        path.update(nodeUpdate: event)
        update(path: path)
    }

    private func loadEvent(pathId: UUID, _ event: PathEvent.Update.NodeBreak) {
        guard let path = path(id: pathId) else { return }
        let newPath = path.update(nodeBreak: event)
        update(path: path)
        if let newPath {
            add(path: newPath)
        }
    }

    private func loadEvent(pathId: UUID, _ event: PathEvent.Update.EdgeUpdate) {
        guard let path = path(id: pathId) else { return }
        path.update(edgeUpdate: event)
        update(path: path)
    }

    private func loadEvent(pathId: UUID, _ event: PathEvent.Update.EdgeBreak) {
        guard let path = path(id: pathId) else { return }
        let newPath = path.update(edgeBreak: event)
        update(path: path)
        if let newPath {
            add(path: newPath)
        }
    }
}
