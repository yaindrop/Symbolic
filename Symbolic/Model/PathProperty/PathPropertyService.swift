import Foundation

private let subtracer = tracer.tagged("PathPropertyService")

typealias PathPropertyMap = [UUID: PathProperty]

protocol PathPropertyStoreProtocol {
    var map: PathPropertyMap { get }
}

extension PathPropertyStoreProtocol {
    func get(id: UUID) -> PathProperty? {
        map.value(key: id)
    }

    func exists(id: UUID) -> Bool {
        get(id: id) != nil
    }
}

// MARK: - PathPropertyStore

class PathPropertyStore: Store, PathPropertyStoreProtocol {
    @Trackable var map = PathPropertyMap()
}

private extension PathPropertyStore {
    func update(map: PathPropertyMap) {
        update { $0(\._map, map) }
    }
}

// MARK: - PendingPathPropertyStore

class PendingPathPropertyStore: PathPropertyStore {
    @Trackable fileprivate var active: Bool = false
}

private extension PendingPathPropertyStore {
    func update(active: Bool) {
        update { $0(\._active, active) }
    }
}

// MARK: - PathPropertyService

struct PathPropertyService {
    let store: PathPropertyStore
    let pendingStore: PendingPathPropertyStore
    let path: PathService
}

// MARK: selectors

extension PathPropertyService: PathPropertyStoreProtocol {
    var map: PathPropertyMap { pendingStore.active ? pendingStore.map : store.map }
}

// MARK: load document

extension PathPropertyService {
    var targetStore: PathPropertyStore { pendingStore.active ? pendingStore : store }

    private func add(property: PathProperty) {
        let _r = subtracer.range("add"); defer { _r() }
        guard !exists(id: property.id),
              path.exists(id: property.id) else { return }
        targetStore.update(map: map.cloned { $0[property.id] = property })
    }

    private func remove(pathId: UUID) {
        let _r = subtracer.range("remove"); defer { _r() }
        guard exists(id: pathId),
              !path.exists(id: pathId) else { return }
        targetStore.update(map: map.cloned { $0.removeValue(forKey: pathId) })
    }

    private func update(property: PathProperty) {
        let _r = subtracer.range("update"); defer { _r() }
        guard exists(id: property.id),
              path.exists(id: property.id) else { remove(pathId: property.id); return }
        targetStore.update(map: map.cloned { $0[property.id] = property })
    }

    private func clear() {
        let _r = subtracer.range("clear"); defer { _r() }
        targetStore.update(map: .init())
    }
}

// MARK: load document

extension PathPropertyService {
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
                pendingStore.update(map: store.map.cloned)
                load(event: pendingEvent)
            } else {
                pendingStore.update(active: false)
            }
        }
    }
}

// MARK: - event loaders

extension PathPropertyService {
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
        for pathId in event.affectedPathIds {
            let property = get(id: pathId)
            let path = path.get(id: pathId)
            if path == nil {
                remove(pathId: pathId)
            } else if property == nil {
                add(property: .init(id: pathId))
            }
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
        guard var property = get(id: pathId) else { return }
        for kind in event.kinds {
            switch kind {
            case let .setName(event): break
            case let .setNodeType(event):
                for nodeId in event.nodeIds {
                    property.nodeTypeMap[nodeId] = event.nodeType
                }
            case let .setSegmentType(event):
                for fromNodeId in event.fromNodeIds {
                    property.segmentTypeMap[fromNodeId] = event.segmentType
                }
            }
        }
        update(property: property)
    }
}
