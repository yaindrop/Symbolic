import Foundation

private let subtracer = tracer.tagged("SymbolService")

typealias SymbolMap = [UUID: Symbol]

// MARK: - SymbolStoreProtocol

protocol SymbolStoreProtocol {
    var symbolMap: SymbolMap { get }
}

extension SymbolStoreProtocol {
    func get(id: UUID) -> Symbol? {
        symbolMap.get(id)
    }

    func exists(id: UUID) -> Bool {
        get(id: id) != nil
    }
}

// MARK: - SymbolStore

class SymbolStore: Store, SymbolStoreProtocol {
    @Trackable var symbolMap = SymbolMap()
}

private extension SymbolStore {
    func update(symbolMap: SymbolMap, forced: Bool = false) {
        update { $0(\._symbolMap, symbolMap, forced: forced) }
    }
}

// MARK: - PendingSymbolStore

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
    private var activeStore: SymbolStore { pendingStore.active ? pendingStore : store }

    var symbolMap: SymbolMap { activeStore.symbolMap }

    var symbols: [Symbol] { .init(symbolMap.values) }

    var allSymbolsBounds: CGRect? {
        .init(union: symbols.map { $0.boundingRect })
    }

    func symbolHitTest(worldPosition: Point2) -> UUID? {
        symbolMap.values.first { $0.boundingRect.contains(worldPosition) }?.id
    }
}

// MARK: load document

extension SymbolService {
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
                pendingStore.update(symbolMap: store.symbolMap)
                load(event: pendingEvent)
            }
        } else {
            let _r = subtracer.range("clear pending event"); defer { _r() }
            pendingStore.update(active: false)
        }
    }
}

// MARK: - modify

private extension SymbolService {
    func add(symbolId: UUID, symbol: Symbol) {
        let _r = subtracer.range("add \(symbolId)"); defer { _r() }
        var symbolMap = symbolMap
        guard !exists(id: symbolId) else { return }
        guard symbol.size.width > 0, symbol.size.height > 0 else { return }
        symbolMap[symbolId] = symbol
        activeStore.update(symbolMap: symbolMap)
    }

    func update(symbolId: UUID, symbol: Symbol) {
        let _r = subtracer.range("update \(symbolId)"); defer { _r() }
        var symbolMap = symbolMap
        symbolMap[symbolId] = symbol
        activeStore.update(symbolMap: symbolMap)
    }

    func remove(symbolIds: [UUID]) {
        let _r = subtracer.range("remove \(symbolIds)"); defer { _r() }
        var symbolMap = symbolMap
        for symbolId in symbolIds {
            symbolMap.removeValue(forKey: symbolId)
        }
        activeStore.update(symbolMap: symbolMap)
    }

    func clear() {
        let _r = subtracer.range("clear"); defer { _r() }
        activeStore.update(symbolMap: .init())
    }
}

// MARK: - load event

private extension SymbolService {
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
        case .path: break
        case let .symbol(event): load(event: event)
        case .item: break
        case .world: break
        }
    }

    // MARK: load symbol event

    func load(event: SymbolEvent) {
        let symbolIds = event.symbolIds,
            kinds = event.kinds
        for kind in kinds {
            switch kind {
            case let .create(event): load(event: event, of: symbolIds)
            case let .setBounds(event): load(event: event, of: symbolIds)
            case let .setGrid(event): load(event: event, of: symbolIds)
            case .setMembers: break

            case let .delete(event): load(event: event, of: symbolIds)
            case let .move(event): load(event: event, of: symbolIds)
            }
        }
    }

    func load(event: SymbolEvent.Create, of symbolIds: [UUID]) {
        guard let symbolId = symbolIds.first else { return }
        add(symbolId: symbolId, symbol: .init(id: symbolId, origin: event.origin, size: event.size, grids: event.grids))
    }

    func load(event: SymbolEvent.SetBounds, of symbolIds: [UUID]) {
        guard let symbolId = symbolIds.first,
              var symbol = get(id: symbolId) else { return }
        symbol.update(event)
        update(symbolId: symbolId, symbol: symbol)
    }

    func load(event: SymbolEvent.SetGrid, of symbolIds: [UUID]) {
        guard let symbolId = symbolIds.first,
              var symbol = get(id: symbolId) else { return }
        symbol.update(event)
        update(symbolId: symbolId, symbol: symbol)
    }

    func load(event _: SymbolEvent.Delete, of symbolIds: [UUID]) {
        remove(symbolIds: symbolIds)
    }

    func load(event: SymbolEvent.Move, of symbolIds: [UUID]) {
        for symbolId in symbolIds {
            guard var symbol = get(id: symbolId) else { continue }
            symbol.update(event)
            update(symbolId: symbolId, symbol: symbol)
        }
    }
}
