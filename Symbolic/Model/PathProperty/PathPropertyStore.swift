import Foundation

private let subtracer = tracer.tagged("PathPropertyService")

typealias PathPropertyMap = [UUID: PathProperty]

protocol PathPropertyStoreProtocol {
    var map: PathPropertyMap { get }
}

extension PathPropertyStoreProtocol {
    func property(id: UUID) -> PathProperty? {
        map.value(key: id)
    }

    func exists(id: UUID) -> Bool {
        property(id: id) != nil
    }
}

// MARK: - PathPropertyStore

class PathPropertyStore: Store, PathPropertyStoreProtocol {
    @Trackable var map = PathPropertyMap()

    fileprivate func update(map: PathPropertyMap) {
        update { $0(\._map, map) }
    }
}

// MARK: - PendingPathPropertyStore

class PendingPathPropertyStore: PathPropertyStore {
    @Trackable fileprivate var active: Bool = false

    fileprivate func update(active: Bool) {
        update { $0(\._active, active) }
    }
}

// MARK: - PathPropertyService

struct PathPropertyService {
    let path: PathService
    let store: PathPropertyStore
    let pendingStore: PendingPathPropertyStore
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
        guard !exists(id: property.id) else { return }
        guard path.exists(id: property.id) else { return }
        targetStore.update(map: map.with { $0[property.id] = property })
    }

    private func remove(pathId: UUID) {
        let _r = subtracer.range("remove"); defer { _r() }
        guard exists(id: pathId) else { return }
        guard !path.exists(id: pathId) else { return }
        targetStore.update(map: map.with { $0.removeValue(forKey: pathId) })
    }

    private func update(property: PathProperty) {
        let _r = subtracer.range("update"); defer { _r() }
        guard exists(id: property.id) else { return }
        guard path.exists(id: property.id) else { remove(pathId: property.id); return }
        targetStore.update(map: map.with { $0[property.id] = property })
    }

    private func clear() {
        let _r = subtracer.range("clear"); defer { _r() }
        targetStore.update(map: .init())
    }
}

// MARK: load document

extension PathPropertyService {
    func loadDocument(_ document: Document) {
        let _r = subtracer.range(type: .intent, "load document, size=\(document.events.count)"); defer { _r() }
        withStoreUpdating {
            clear()
            for event in document.events {
                loadEvent(event)
            }
        }
    }

    func loadPendingEvent(_ event: DocumentEvent?) {
        let _r = subtracer.range("load pending event"); defer { _r() }
        withStoreUpdating {
            if let event {
                pendingStore.update(active: true)
                pendingStore.update(map: store.map.cloned)
                loadEvent(event)
            } else {
                pendingStore.update(active: false)
            }
        }
    }
}

// MARK: - event loaders

extension PathPropertyService {
    private func loadEvent(_ event: DocumentEvent) {
        let _r = subtracer.range(type: .intent, "load document event \(event.id)"); defer { _r() }
        switch event.kind {
        case let .compound(event):
            event.events.forEach { loadEvent($0) }
        case let .single(event):
            loadEvent(event)
        }
    }

    private func loadEvent(_ event: SingleEvent) {
        switch event {
        case .item: break
        case let .path(event): loadEvent(event)
        case let .pathProperty(event): loadEvent(event)
        }
    }

    // MARK: path event

    private func loadEvent(_ event: PathEvent) {
        for pathId in event.affectedPathIds {
            let property = self.property(id: pathId)
            let path = path.path(id: pathId)
            if path == nil {
                remove(pathId: pathId)
            } else if property == nil {
                add(property: .init(id: pathId))
            }
        }
    }

    // MARK: path property event

    private func loadEvent(_ event: PathPropertyEvent) {
        switch event {
        case let .update(event):
            let pathId = event.pathId
            switch event.kind {
            case let .setName(event): loadEvent(pathId, event)
            case let .setNodeType(event): loadEvent(pathId, event)
            case let .setEdgeType(event): loadEvent(pathId, event)
            }
        }
    }

    private func loadEvent(_ pathId: UUID, _ event: PathPropertyEvent.Update.SetName) {
        guard var property = property(id: pathId) else { return }
        property.name = event.name
        update(property: property)
    }

    private func loadEvent(_ pathId: UUID, _ event: PathPropertyEvent.Update.SetNodeType) {
        guard var property = property(id: pathId) else { return }
        property.nodeTypeMap[event.nodeId] = event.nodeType
        update(property: property)
    }

    private func loadEvent(_ pathId: UUID, _ event: PathPropertyEvent.Update.SetEdgeType) {
        guard var property = property(id: pathId) else { return }
        property.edgeTypeMap[event.fromNodeId] = event.edgeType
        update(property: property)
    }
}
