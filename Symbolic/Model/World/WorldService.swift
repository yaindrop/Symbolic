import Foundation

private let subtracer = tracer.tagged("WorldService")

// MARK: - WorldStoreProtocol

protocol WorldStoreProtocol {
    var world: World { get }
}

extension WorldStoreProtocol {
    var grid: Grid? {
        world.grid
    }

    var symbolIds: [UUID] {
        world.symbolIds
    }
}

// MARK: - WorldStore

class WorldStore: Store, WorldStoreProtocol {
    @Trackable var world = World()
}

private extension WorldStore {
    func update(world: World, forced: Bool = false) {
        update { $0(\._world, world, forced: forced) }
    }
}

// MARK: - PendingWorldStore

class PendingWorldStore: WorldStore {
    @Trackable fileprivate var active: Bool = false
}

private extension PendingWorldStore {
    func update(active: Bool) {
        update { $0(\._active, active) }
    }
}

// MARK: - WorldService

struct WorldService {
    let store: WorldStore
    let pendingStore: PendingWorldStore
    let symbol: SymbolService
}

// MARK: selectors

extension WorldService: WorldStoreProtocol {
    private var activeStore: WorldStore { pendingStore.active ? pendingStore : store }

    var world: World { activeStore.world }
}

// MARK: load document

extension WorldService {
    func load(document: Document) {
        let _r = subtracer.range(type: .intent, "load document, size=\(document.events.count)"); defer { _r() }
        withStoreUpdating {
            store.update(world: World())
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
                pendingStore.update(world: store.world)
                load(event: pendingEvent)
            }
        } else {
            let _r = subtracer.range("clear pending event"); defer { _r() }
            pendingStore.update(active: false)
        }
    }
}

// MARK: - load event

private extension WorldService {
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
        case let .world(event): load(event: event)
        }
    }

    // MARK: load symbol event

    func load(event: SymbolEvent) {
        let symbolIds = event.symbolIds
        for kind in event.kinds {
            switch kind {
            case let .create(event): load(event: event, of: symbolIds)
            case .setBounds, .setGrid, .setMembers: break

            case let .delete(event): load(event: event, of: symbolIds)
            case .move: break
            }
        }
    }

    func load(event _: SymbolEvent.Create, of symbolIds: [UUID]) {
        guard let symbolId = symbolIds.first,
              symbol.exists(id: symbolId) else { return }
        var world = world
        world.symbolIds.append(symbolId)
        activeStore.update(world: world)
    }

    func load(event _: SymbolEvent.Delete, of symbolIds: [UUID]) {
        let symbolIdSet = Set(symbolIds)
        var world = world
        world.symbolIds.removeAll { symbolIdSet.contains($0) }
        activeStore.update(world: world)
    }

    // MARK: load world event

    func load(event: WorldEvent) {
        switch event {
        case let .setGrid(event): load(event: event)
        case let .setSymbolIds(event): load(event: event)
        }
    }

    func load(event: WorldEvent.SetGrid) {
        let grid = event.grid
        var world = world
        world.grid = grid
        activeStore.update(world: world)
    }

    func load(event: WorldEvent.SetSymbolIds) {
        let symbolIds = event.symbolIds
        var world = world
        world.symbolIds = symbolIds
        activeStore.update(world: world)
    }
}
