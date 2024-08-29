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

// MARK: - modify path map

extension PathService {
    private func add(pathId: UUID, path: Path) {
        let _r = subtracer.range("add \(pathId)"); defer { _r() }
        var pathMap = pathMap
        guard !exists(id: pathId),
              path.count > 1 else { return }
        pathMap[pathId] = path
        activeStore.update(pathMap: pathMap)
    }

    private func update(pathId: UUID, path: Path) {
        let _r = subtracer.range("update \(pathId)"); defer { _r() }
        var pathMap = pathMap
        pathMap[pathId] = path
        activeStore.update(pathMap: pathMap, forced: true)
    }

    private func update(pathId: UUID, pathProperty: PathProperty) {
        let _r = subtracer.range("update property \(pathId)"); defer { _r() }
        guard exists(id: pathId) else { return }
        var pathPropertyMap = pathPropertyMap
        pathPropertyMap[pathId] = pathProperty
        activeStore.update(pathPropertyMap: pathPropertyMap)
    }

    private func remove(pathIds: [UUID]) {
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

    private func clear() {
        let _r = subtracer.range("clear"); defer { _r() }
        activeStore.update(pathMap: .init())
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
                pendingStore.update(pathMap: store.pathMap)
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
        case .symbol: break
        case .item: break
        }
    }

    // MARK: path event

    private func load(event: PathEvent) {
        let _r = subtracer.range("load event"); defer { _r() }
        let pathIds = event.pathIds,
            kinds = event.kinds
        for kind in kinds {
            switch kind {
            case let .create(event): load(pathIds: pathIds, event)
            case let .createNode(event): load(pathIds: pathIds, event)
            case let .updateNode(event): load(pathIds: pathIds, event)
            case let .deleteNode(event): load(pathIds: pathIds, event)
            case let .merge(event): load(pathIds: pathIds, event)
            case let .split(event): load(pathIds: pathIds, event)
            case let .delete(event): load(pathIds: pathIds, event)
            case let .move(event): load(pathIds: pathIds, event)
            case let .setName(event): load(pathIds: pathIds, event)
            case let .setNodeType(event): load(pathIds: pathIds, event)
            case let .setSegmentType(event): load(pathIds: pathIds, event)
            }
        }
    }

    private func load(pathIds: [UUID], _ event: PathEvent.Create) {
        guard let pathId = pathIds.first else { return }
        add(pathId: pathId, path: event.path)
    }

    private func load(pathIds: [UUID], _ event: PathEvent.CreateNode) {
        guard let pathId = pathIds.first,
              var path = get(id: pathId) else { return }
        path.update(event)
        update(pathId: pathId, path: path)
    }

    private func load(pathIds: [UUID], _ event: PathEvent.UpdateNode) {
        guard let pathId = pathIds.first,
              var path = get(id: pathId) else { return }
        path.update(event)
        update(pathId: pathId, path: path)
    }

    private func load(pathIds: [UUID], _ event: PathEvent.DeleteNode) {
        guard let pathId = pathIds.first,
              var path = get(id: pathId) else { return }
        path.update(event)
        update(pathId: pathId, path: path)
    }

    private func load(pathIds: [UUID], _ event: PathEvent.Merge) {
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

    private func load(pathIds: [UUID], _ event: PathEvent.Split) {
        guard let pathId = pathIds.first,
              var path = get(id: pathId) else { return }
        let newPath = path.update(event)
        update(pathId: pathId, path: path)
        if let newPath, let newPathId = event.newPathId {
            add(pathId: newPathId, path: newPath)
        }
    }

    private func load(pathIds: [UUID], _: PathEvent.Delete) {
        remove(pathIds: pathIds)
    }

    private func load(pathIds: [UUID], _ event: PathEvent.Move) {
        for pathId in pathIds {
            guard var path = get(id: pathId) else { continue }
            path.update(event)
            update(pathId: pathId, path: path)
        }
    }

    private func load(pathIds: [UUID], _ event: PathEvent.SetName) {
        guard let pathId = pathIds.first,
              var property = property(id: pathId) else { return }
        property.update(event)
        update(pathId: pathId, pathProperty: property)
    }

    private func load(pathIds: [UUID], _ event: PathEvent.SetNodeType) {
        guard let pathId = pathIds.first,
              var path = get(id: pathId),
              var property = property(id: pathId) else { return }
        path.update(event)
        update(pathId: pathId, path: path)
        property.update(event)
        update(pathId: pathId, pathProperty: property)
    }

    private func load(pathIds: [UUID], _ event: PathEvent.SetSegmentType) {
        guard let pathId = pathIds.first,
              var path = get(id: pathId),
              var property = property(id: pathId) else { return }
        path.update(event)
        update(pathId: pathId, path: path)
        property.update(event)
        update(pathId: pathId, pathProperty: property)
    }
}
