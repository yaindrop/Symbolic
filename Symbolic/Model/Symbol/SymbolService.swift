import Foundation

private let subtracer = tracer.tagged("SymbolService")

typealias SymbolMap = OrderedMap<UUID, Symbol>

protocol SymbolStoreProtocol {
    var map: SymbolMap { get }
}

extension SymbolStoreProtocol {
    var symbolIds: [UUID] { map.keys }

    func get(id: UUID) -> Symbol? {
        map.value(key: id)
    }

    func exists(id: UUID) -> Bool {
        get(id: id) != nil
    }
}

// MARK: - PathPropertyStore

class SymbolStore: Store, SymbolStoreProtocol {
    @Trackable var map = SymbolMap()
}

private extension SymbolStore {
    func update(map: SymbolMap) {
        update { $0(\._map, map) }
    }
}

// MARK: - PendingPathPropertyStore

class PendingSymbolStore: SymbolStore {
    @Trackable fileprivate var active: Bool = false
}

private extension PendingSymbolStore {
    func update(active: Bool) {
        update { $0(\._active, active) }
    }
}

// MARK: - SymbolService

struct SymbolService {
    let store: SymbolStore
    let pendingStore: PendingSymbolStore
}

// MARK: selectors

extension SymbolService: SymbolStoreProtocol {
    var map: SymbolMap { pendingStore.active ? pendingStore.map : store.map }
}

// MARK: load document

extension SymbolService {
    var targetStore: SymbolStore { pendingStore.active ? pendingStore : store }

    private func add(symbol: Symbol) {
        let _r = subtracer.range("add"); defer { _r() }
        guard !exists(id: symbol.id) else { return }
        targetStore.update(map: map.cloned { $0[symbol.id] = symbol })
    }

    private func remove(symbolId: UUID) {
        let _r = subtracer.range("remove"); defer { _r() }
        guard exists(id: symbolId) else { return }
        targetStore.update(map: map.cloned { $0.removeValue(forKey: symbolId) })
    }

    private func update(symbol: Symbol) {
        let _r = subtracer.range("update"); defer { _r() }
        guard exists(id: symbol.id) else { remove(symbolId: symbol.id); return }
        targetStore.update(map: map.cloned { $0[symbol.id] = symbol })
    }

    private func clear() {
        let _r = subtracer.range("clear"); defer { _r() }
        targetStore.update(map: .init())
    }
}

// MARK: load document

extension SymbolService {
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

extension SymbolService {
    private func loadEvent(_ event: DocumentEvent) {
        let _r = subtracer.range(type: .intent, "load document event \(event.id)"); defer { _r() }
        switch event.kind {
        case let .compound(event):
            event.events.forEach { loadEvent($0) }
        case let .single(event):
            loadEvent(event)
        }
    }

    private func loadEvent(_ event: DocumentEvent.Single) {
        switch event {
        case .path: break
        case .pathProperty: break
        case .item: break
        case let .symbol(event): loadEvent(event)
        }
    }

    // MARK: path property event

    private func loadEvent(_ event: SymbolEvent) {
        switch event {
        case let .create(event): loadEvent(event)
        case let .delete(event): loadEvent(event)
        case let .resize(event): loadEvent(event)
        }
    }

    private func loadEvent(_ event: SymbolEvent.Create) {
        let symbolId = event.symbolId,
            origin = event.origin,
            size = event.size
        add(symbol: .init(id: symbolId, origin: origin, size: size))
    }

    private func loadEvent(_ event: SymbolEvent.Delete) {
        let symbolId = event.symbolId
        remove(symbolId: symbolId)
    }

    private func loadEvent(_ event: SymbolEvent.Resize) {
        let symbolId = event.symbolId
        guard var symbol = get(id: symbolId) else { return }
        symbol.origin = event.origin
        symbol.size = event.size
        update(symbol: symbol)
    }
}
