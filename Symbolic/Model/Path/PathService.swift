import Foundation

private let subtracer = tracer.tagged("PathService")

typealias PathMap = [UUID: Path]

// MARK: - PathStoreProtocol

protocol PathStoreProtocol {
    var map: PathMap { get }
}

extension PathStoreProtocol {
    func get(id: UUID) -> Path? {
        map.value(key: id)
    }

    func exists(id: UUID) -> Bool {
        get(id: id) != nil
    }
}

// MARK: - PathStore

class PathStore: Store, PathStoreProtocol {
    @Trackable var map = PathMap()
}

private extension PathStore {
    func update(map: PathMap, forced: Bool = false) {
        update { $0(\._map, map, forced: forced) }
    }
}

// MARK: - PendingPathStore

class PendingPathStore: PathStore {
    @Trackable fileprivate var active: Bool = false
}

private extension PendingPathStore {
    func update(active: Bool) {
        update { $0(\._active, active) }
    }
}

// MARK: - PathService

struct PathService: PathStoreProtocol {
    let store: PathStore
    let pendingStore: PendingPathStore
    let viewport: ViewportService
}

// MARK: selectors

extension PathService {
    var map: PathMap { pendingStore.active ? pendingStore.map : store.map }

    func hitTest(path: Path, position: Point2, threshold: Scalar = 24) -> Bool {
        let width = (threshold * Vector2.unitX).applying(viewport.toWorld).dx
        return path.hitPath(width: width).contains(position)
    }

    func hitTest(position: Point2, threshold: Scalar = 24) -> UUID? {
        let width = (threshold * Vector2.unitX).applying(viewport.toWorld).dx
        return map.first { _, path in path.hitPath(width: width).contains(position) }?.key
    }
}

// MARK: - modify path map

extension PathService {
    var targetStore: PathStore { pendingStore.active ? pendingStore : store }

    private func add(pathId: UUID, path: Path) {
        let _r = subtracer.range("add"); defer { _r() }
        var updated = map
        guard !exists(id: pathId) else { return }
        guard path.count > 1 else { return }
        updated[pathId] = path
        targetStore.update(map: updated)
    }

    private func remove(pathIds: [UUID]) {
        let _r = subtracer.range("remove"); defer { _r() }
        var updated = map
        for pathId in pathIds {
            updated.removeValue(forKey: pathId)
        }
        targetStore.update(map: updated)
    }

    private func update(pathId: UUID, path: Path) {
        let _r = subtracer.range("update"); defer { _r() }
        var updated = map
        if path.count <= 1 {
            updated.removeValue(forKey: pathId)
        } else {
            updated[pathId] = path
        }
        targetStore.update(map: updated, forced: true)
    }

    private func clear() {
        let _r = subtracer.range("clear"); defer { _r() }
        targetStore.update(map: .init())
    }
}

// MARK: load document

extension PathService {
    func load(document: Document) {
        let _r = subtracer.range(type: .intent, "load document, size=\(document.events.count)"); defer { _r() }
        withStoreUpdating {
            clear()
            for event in document.events {
                load(event: event)
            }
        }
    }

    func load(pendingEvent: DocumentEvent?) {
        let _r = subtracer.range("load pending event"); defer { _r() }
        withStoreUpdating {
            if let pendingEvent {
                pendingStore.update(active: true)
                pendingStore.update(map: store.map)
                load(event: pendingEvent)
            } else {
                pendingStore.update(active: false)
            }
        }
    }
}

// MARK: - event loaders

extension PathService {
    private func load(event: DocumentEvent) {
        let _r = subtracer.range(type: .intent, "load document event \(event.id)"); defer { _r() }
        switch event.kind {
        case let .compound(event):
            event.events.forEach { load(event: $0) }
        case let .single(event):
            load(event: event)
        }
    }

    private func load(event: DocumentEvent.Single) {
        switch event {
        case let .path(event): load(event: event)
        case let .pathProperty(event): load(event: event)
        case .item: break
        case .symbol: break
        }
    }

    // MARK: path event

    private func load(event: PathEvent) {
        let _r = subtracer.range("load event"); defer { _r() }
        switch event {
        case let .create(event): load(event: event)
        case let .delete(event): load(event: event)
        case let .update(event): load(event: event)
        case let .merge(event): load(event: event)
        case let .split(event): load(event: event)
        }
    }

    private func load(event: PathEvent.Create) {
        add(pathId: event.pathId, path: event.path)
    }

    private func load(event: PathEvent.Delete) {
        remove(pathIds: [event.pathId])
    }

    private func load(event: PathEvent.Update) {
        let pathId = event.pathId
        guard var path = get(id: pathId) else { return }
        for kind in event.kinds {
            switch kind {
            case let .move(event):
                path.update(move: event)
            case let .nodeCreate(event):
                path.update(nodeCreate: event)
            case let .nodeDelete(event):
                path.update(nodeDelete: event)
            case let .nodeUpdate(event):
                path.update(nodeUpdate: event)
            }
        }
        update(pathId: pathId, path: path)
    }

    // MARK: path multi update

    private func load(event: PathEvent.Merge) {
        let pathId = event.pathId, mergedPathId = event.mergedPathId
        guard var path = get(id: pathId),
              let mergedPath = get(id: mergedPathId) else { return }
        if mergedPath != path {
            remove(pathIds: [mergedPathId])
        }
        path.update(merge: event, mergedPath: mergedPath)
        update(pathId: pathId, path: path)
    }

    private func load(event: PathEvent.Split) {
        let pathId = event.pathId
        guard var path = get(id: pathId) else { return }
        let newPath = path.update(nodeBreak: event)
        update(pathId: pathId, path: path)
        if let newPath, let newPathId = event.newPathId {
            add(pathId: newPathId, path: newPath)
        }
    }

    // MARK: path property event

    private func load(event: PathPropertyEvent) {
        switch event {
        case let .update(event): load(event: event)
        }
    }

    private func load(event: PathPropertyEvent.Update) {
        let pathId = event.pathId
        guard var path = get(id: pathId) else { return }
        for kind in event.kinds {
            switch kind {
            case let .setName(event): break
            case let .setNodeType(event):
                path.update(setNodeType: event)
            case let .setSegmentType(event):
                path.update(setSegmentType: event)
            }
        }
        update(pathId: pathId, path: path)
    }
}
