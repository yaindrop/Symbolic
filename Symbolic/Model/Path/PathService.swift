import Foundation

private let subtracer = tracer.tagged("PathService")

typealias PathMap = [UUID: Path]
typealias PathPropertyMap = [UUID: PathProperty]

// MARK: - PathStoreProtocol

protocol PathStoreProtocol {
    var pathMap: PathMap { get }
    var pathPropertyMap: PathPropertyMap { get }
}

extension PathStoreProtocol {
    func get(id: UUID) -> Path? {
        pathMap.get(id)
    }

    func property(id: UUID) -> PathProperty? {
        pathPropertyMap.get(id)
    }

    func exists(id: UUID) -> Bool {
        get(id: id) != nil
    }
}

// MARK: - PathStore

class PathStore: Store, PathStoreProtocol {
    @Trackable var pathMap = PathMap()
    @Trackable var pathPropertyMap = PathPropertyMap()
}

private extension PathStore {
    func update(pathMap: PathMap, forced: Bool = false) {
        update { $0(\._pathMap, pathMap, forced: forced) }
    }

    func update(pathPropertyMap: PathPropertyMap) {
        update { $0(\._pathPropertyMap, pathPropertyMap) }
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
}

// MARK: selectors

extension PathService {
    private var activeStore: PathStore { pendingStore.active ? pendingStore : store }

    var pathMap: PathMap { activeStore.pathMap }

    var pathPropertyMap: PathPropertyMap { activeStore.pathPropertyMap }
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
        if let pendingEvent {
            let _r = subtracer.range("load pending event \(pendingEvent.id)"); defer { _r() }
            withStoreUpdating {
                pendingStore.update(active: true)
                pendingStore.update(pathMap: store.pathMap)
                pendingStore.update(pathPropertyMap: store.pathPropertyMap)
                load(event: pendingEvent)
            }
        } else {
            let _r = subtracer.range("clear pending event"); defer { _r() }
            pendingStore.update(active: false)
        }
    }
}

// MARK: - modify

private extension PathService {
    func add(pathId: UUID, path: Path) {
        let _r = subtracer.range("add \(pathId)"); defer { _r() }
        var pathMap = pathMap
        var pathPropertyMap = pathPropertyMap
        guard !exists(id: pathId),
              path.count > 1 else { return }
        pathMap[pathId] = path
        pathPropertyMap[pathId] = .init(id: pathId)
        activeStore.update(pathMap: pathMap)
        activeStore.update(pathPropertyMap: pathPropertyMap)
    }

    func update(pathId: UUID, path: Path) {
        let _r = subtracer.range("update \(pathId)"); defer { _r() }
        var pathMap = pathMap
        pathMap[pathId] = path
        activeStore.update(pathMap: pathMap, forced: true)
    }

    func update(pathId: UUID, pathProperty: PathProperty) {
        let _r = subtracer.range("update property \(pathId)"); defer { _r() }
        guard exists(id: pathId) else { return }
        var pathPropertyMap = pathPropertyMap
        pathPropertyMap[pathId] = pathProperty
        activeStore.update(pathPropertyMap: pathPropertyMap)
    }

    func remove(pathIds: [UUID]) {
        let _r = subtracer.range("remove \(pathIds)"); defer { _r() }
        var pathMap = pathMap
        var pathPropertyMap = pathPropertyMap
        for pathId in pathIds {
            pathMap.removeValue(forKey: pathId)
            pathPropertyMap.removeValue(forKey: pathId)
        }
        activeStore.update(pathMap: pathMap)
        activeStore.update(pathPropertyMap: pathPropertyMap)
    }

    func clear() {
        let _r = subtracer.range("clear"); defer { _r() }
        activeStore.update(pathMap: .init())
    }
}

// MARK: - load event

private extension PathService {
    func load(event: DocumentEvent) {
        let _r = subtracer.range(type: .intent, "load document event \(event.id)"); defer { _r() }
        switch event.kind {
        case let .compound(event):
            event.events.forEach { load(event: $0) }
        case let .single(event):
            load(event: event)
        }
    }

    func load(event: DocumentEvent.Single) {
        switch event {
        case let .path(event): load(event: event)
        case .symbol: break
        case .item: break
        case .world: break
        }
    }

    // MARK: load path event

    func load(event: PathEvent) {
        let pathIds = event.pathIds,
            kinds = event.kinds
        for kind in kinds {
            switch kind {
            case let .create(event): load(event: event, of: pathIds)
            case let .createNode(event): load(event: event, of: pathIds)
            case let .updateNode(event): load(event: event, of: pathIds)
            case let .deleteNode(event): load(event: event, of: pathIds)
            case let .merge(event): load(event: event, of: pathIds)
            case let .split(event): load(event: event, of: pathIds)
            case let .delete(event): load(event: event, of: pathIds)
            case let .move(event): load(event: event, of: pathIds)
            case let .setNodeType(event): load(event: event, of: pathIds)
            case let .setSegmentType(event): load(event: event, of: pathIds)
            }
        }
    }

    func load(event: PathEvent.Create, of pathIds: [UUID]) {
        guard let pathId = pathIds.first else { return }
        add(pathId: pathId, path: event.path)
    }

    func load(event: PathEvent.CreateNode, of pathIds: [UUID]) {
        guard let pathId = pathIds.first,
              var path = get(id: pathId) else { return }
        path.update(event)
        update(pathId: pathId, path: path)
    }

    func load(event: PathEvent.UpdateNode, of pathIds: [UUID]) {
        guard let pathId = pathIds.first,
              var path = get(id: pathId) else { return }
        path.update(event)
        update(pathId: pathId, path: path)
    }

    func load(event: PathEvent.DeleteNode, of pathIds: [UUID]) {
        guard let pathId = pathIds.first,
              var path = get(id: pathId) else { return }
        path.update(event)
        update(pathId: pathId, path: path)
    }

    func load(event: PathEvent.Merge, of pathIds: [UUID]) {
        let mergedPathId = event.mergedPathId
        guard let pathId = pathIds.first,
              var path = get(id: pathId),
              let mergedPath = get(id: mergedPathId) else { return }
        if mergedPathId != pathId {
            remove(pathIds: [mergedPathId])
        }
        path.update(event, mergedPath: mergedPath)
        update(pathId: pathId, path: path)
    }

    func load(event: PathEvent.Split, of pathIds: [UUID]) {
        guard let pathId = pathIds.first,
              var path = get(id: pathId) else { return }
        let newPath = path.update(event)
        update(pathId: pathId, path: path)
        if let newPath, let newPathId = event.newPathId {
            add(pathId: newPathId, path: newPath)
        }
    }

    func load(event _: PathEvent.Delete, of pathIds: [UUID]) {
        remove(pathIds: pathIds)
    }

    func load(event: PathEvent.Move, of pathIds: [UUID]) {
        for pathId in pathIds {
            guard var path = get(id: pathId) else { continue }
            path.update(event)
            update(pathId: pathId, path: path)
        }
    }

    func load(event: PathEvent.SetNodeType, of pathIds: [UUID]) {
        guard let pathId = pathIds.first,
              var path = get(id: pathId),
              var property = property(id: pathId) else { return }
        path.update(event)
        update(pathId: pathId, path: path)
        property.update(event)
        update(pathId: pathId, pathProperty: property)
    }

    func load(event: PathEvent.SetSegmentType, of pathIds: [UUID]) {
        guard let pathId = pathIds.first,
              var path = get(id: pathId),
              var property = property(id: pathId) else { return }
        path.update(event)
        update(pathId: pathId, path: path)
        property.update(event)
        update(pathId: pathId, pathProperty: property)
    }
}
